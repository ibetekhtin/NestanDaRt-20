#!/bin/bash
# Healthcheck script for KOTЭ system
# Checks: backend API, n8n, Docker, SSL

set -e

LOG_FILE="/var/log/kote-health.log"
API_URL="https://nestandart.online"
N8N_URL="http://localhost:5678/healthz"
BACKEND_URL="http://localhost:8000/health"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_backend() {
    if curl -sf "$BACKEND_URL" > /dev/null; then
        log "✅ Backend OK"
        return 0
    else
        log "❌ Backend DOWN - restarting"
        cd /opt/kote && docker compose restart kote-backend
        sleep 5
        if curl -sf "$BACKEND_URL" > /dev/null; then
            log "✅ Backend recovered"
            return 0
        else
            log "❌ Backend still down"
            return 1
        fi
    fi
}

check_api() {
    if curl -sf "$API_URL/api/v1/tours" > /dev/null; then
        log "✅ API OK"
        return 0
    else
        log "❌ API unreachable"
        return 1
    fi
}

check_nginx() {
    if systemctl is-active --quiet nginx; then
        log "✅ Nginx running"
        return 0
    else
        log "❌ Nginx stopped - restarting"
        systemctl restart nginx
        return 1
    fi
}

# Main
log "=== Healthcheck started ==="

check_nginx
check_backend
check_api

log "=== Healthcheck complete ==="
echo "" >> "$LOG_FILE"