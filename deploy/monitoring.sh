#!/bin/bash
# ============================================================================
# Monitoring Script — KOTЭ SYSTEM
# ============================================================================
# Usage: bash deploy/monitoring.sh (or add to crontab)
#
# Suggested crontab:
#   * * * * * /opt/kote/deploy/monitoring.sh >/dev/null 2>&1
# ============================================================================

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_ADMIN_CHAT_ID="${TELEGRAM_ADMIN_CHAT_ID:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

# Thresholds
CPU_THRESHOLD=90
RAM_THRESHOLD=90
DISK_THRESHOLD=85
BACKUP_AGE_MAX_HOURS=28

# Paths
DEPLOY_DIR="/opt/kote"
BACKUP_DIR="${DEPLOY_DIR}/backups"
LOG_FILE="${DEPLOY_DIR}/logs/monitoring.log"
STATE_FILE="${DEPLOY_DIR}/logs/.monitor_state"

mkdir -p "$(dirname "$LOG_FILE")"

# ─── Helpers ────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    local level="$1"
    local message="$2"
    log "[${level}] ${message}"
    
    # Save alert state to avoid duplicate notifications
    local alert_hash=$(echo "${message}" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "${message}" | md5 2>/dev/null)
    local state_dir="$(dirname "$STATE_FILE")"
    mkdir -p "$state_dir"
    
    # Only send if not already notified in the last hour
    if [ -f "$STATE_FILE" ]; then
        if grep -q "${alert_hash}" "$STATE_FILE" 2>/dev/null; then
            local last_seen=$(grep "${alert_hash}" "$STATE_FILE" | cut -d'|' -f2)
            local now=$(date +%s)
            if [ $((now - last_seen)) -lt 3600 ]; then
                return  # Already notified within the hour
            fi
        fi
    fi
    
    echo "${alert_hash}|$(date +%s)" >> "$STATE_FILE"
    
    # Send Telegram alert
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_ADMIN_CHAT_ID" ]; then
        curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_ADMIN_CHAT_ID}" \
            -d "text=🚨 [${level}] KOTЭ Monitor: ${message}" \
            -d "parse_mode=HTML" >/dev/null 2>&1 || true
    fi
    
    # Send Slack alert
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -sf -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"🚨 [${level}] KOTЭ Monitor: ${message}\"}" >/dev/null 2>&1 || true
    fi
}

# ─── 1. System Resources ────────────────────────────────────────
check_system() {
    log "📊 Checking system resources..."
    
    # CPU
    local cpu_usage=$(top -l 1 | grep -E "^CPU" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo 0)
    if [ "${cpu_usage%.*}" -gt "$CPU_THRESHOLD" ] 2>/dev/null; then
        alert "WARN" "CPU usage at ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
    fi
    
    # RAM
    local ram_usage=$(vm_stat 2>/dev/null | awk '/Pages active/ {print $3}' | sed 's/\.//' || echo 0)
    # Simple check: use `top` instead
    local ram_pct=$(top -l 1 | grep -E "^Phys" | awk '{print $10}' | sed 's/%//' 2>/dev/null || echo 0)
    if [ "${ram_pct%.*}" -gt "$RAM_THRESHOLD" ] 2>/dev/null; then
        alert "WARN" "RAM usage at ${ram_pct}% (threshold: ${RAM_THRESHOLD}%)"
    fi
    
    # Disk
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        alert "CRIT" "Disk usage at ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)"
    fi
}

# ─── 2. Docker Containers ───────────────────────────────────────
check_docker() {
    log "🐳 Checking Docker containers..."
    
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        alert "CRIT" "Docker is not available"
        return
    fi
    
    # Check each container
    for container in kote-backend kote-n8n; do
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not-found")
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
        
        if [ "$status" != "running" ]; then
            alert "CRIT" "Container ${container} is ${status}"
        elif [ "$health" = "unhealthy" ]; then
            alert "WARN" "Container ${container} is unhealthy"
        fi
    done
}

# ─── 3. API Health ──────────────────────────────────────────────
check_api() {
    log "🔌 Checking API endpoints..."
    
    # Backend health
    if ! curl -sf "http://localhost:8000/health" >/dev/null 2>&1; then
        alert "CRIT" "Backend API is not responding on port 8000"
    fi
    
    # n8n health
    if ! curl -sf "http://localhost:5678/healthz" >/dev/null 2>&1; then
        alert "WARN" "n8n is not responding on port 5678"
    fi
    
    # Website health
    if ! curl -sf "https://nestandart-phuket.ru/" >/dev/null 2>&1; then
        if ! curl -sf "http://77.42.93.187/" >/dev/null 2>&1; then
            alert "CRIT" "Website is not accessible"
        fi
    fi
}

# ─── 4. Backup Freshness ────────────────────────────────────────
check_backups() {
    log "💾 Checking backup freshness..."
    
    if [ -d "$BACKUP_DIR" ]; then
        local latest_backup=$(find "$BACKUP_DIR" -name "kote_backup_*" -type f 2>/dev/null | sort | tail -1)
        if [ -n "$latest_backup" ]; then
            local backup_age=$(($(date +%s) - $(stat -f "%m" "$latest_backup" 2>/dev/null || stat -c "%Y" "$latest_backup" 2>/dev/null || echo 0)))
            local backup_age_hours=$((backup_age / 3600))
            
            if [ "$backup_age_hours" -gt "$BACKUP_AGE_MAX_HOURS" ]; then
                alert "WARN" "Latest backup is ${backup_age_hours}h old (threshold: ${BACKUP_AGE_MAX_HOURS}h)"
            fi
        else
            alert "WARN" "No backups found in ${BACKUP_DIR}"
        fi
    fi
}

# ─── 5. SSL Certificate Expiry ──────────────────────────────────
check_ssl() {
    log "🔒 Checking SSL certificate..."
    
    if command -v openssl &> /dev/null; then
        local expiry=$(echo | openssl s_client -servername nestandart-phuket.ru -connect nestandart-phuket.ru:443 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ -n "$expiry" ]; then
            local expiry_epoch=$(date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null || date -d "$expiry" +%s 2>/dev/null)
            local now=$(date +%s)
            local days_left=$(( (expiry_epoch - now) / 86400 ))
            
            if [ "$days_left" -lt 7 ]; then
                alert "CRIT" "SSL certificate expires in ${days_left} days"
            elif [ "$days_left" -lt 30 ]; then
                alert "WARN" "SSL certificate expires in ${days_left} days"
            fi
        fi
    fi
}

# ─── Main ───────────────────────────────────────────────────────
log "═══════════════════════════════════════════════════════════════"
log "  KOTЭ Monitoring Check — $(date '+%Y-%m-%d %H:%M:%S')"
log "═══════════════════════════════════════════════════════════════"

check_system
check_docker
check_api
check_backups
check_ssl

log ""
log "✅ Monitoring check complete"
log ""

# Cleanup old state entries (older than 24h)
if [ -f "$STATE_FILE" ]; then
    local cutoff=$(date -v-24H +%s 2>/dev/null || date -d '24 hours ago' +%s 2>/dev/null)
    if [ -n "$cutoff" ]; then
        while IFS= read -r line; do
            local timestamp=$(echo "$line" | cut -d'|' -f2)
            if [ "$timestamp" -lt "$cutoff" ] 2>/dev/null; then
                sed -i '' "/${line}/d" "$STATE_FILE" 2>/dev/null || true
            fi
        done < "$STATE_FILE"
    fi
fi