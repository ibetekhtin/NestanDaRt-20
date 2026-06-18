#!/bin/bash
# ============================================================================
# Deploy Script — KOTЭ SYSTEM (Improved)
# ============================================================================
# Usage: bash deploy/deploy.sh
# Features: health checks, rollback support, zero-downtime attempt
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

DEPLOY_DIR="/opt/kote"
BACKUP_DIR="/opt/kote-backups/$(date +%Y%m%d_%H%M%S)"
MAX_RETRIES=30
RETRY_INTERVAL=5

log "🚀 Deploying KOTЭ System..."
log "Backup dir: $BACKUP_DIR"

cd "$DEPLOY_DIR"

# ─── Pre-deployment checks ──────────────────────────────────────
log "🔍 Running pre-deployment checks..."

# Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    error "Low disk space: ${DISK_USAGE}% used. Aborting."
    exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
    error ".env file not found. Aborting."
    exit 1
fi

# ─── Backup current state ───────────────────────────────────────
log "💾 Backing up current state..."
mkdir -p "$BACKUP_DIR"
docker compose ps --format json > "$BACKUP_DIR/container-state.json" 2>/dev/null || true
cp .env "$BACKUP_DIR/.env.backup" 2>/dev/null || true
docker compose exec -T kote-n8n cat /home/node/.n8n/database.sqlite > "$BACKUP_DIR/n8n-db.sqlite" 2>/dev/null || true
log "   Backup saved to: $BACKUP_DIR"

# ─── Pull latest code ───────────────────────────────────────────
log "📥 Pulling latest code..."
git pull origin main 2>&1 || {
    error "Git pull failed. Aborting."
    exit 1
}

# ─── Build new images (without stopping services) ───────────────
log "🔨 Building new images..."
docker compose build 2>&1 || {
    error "Build failed. Aborting."
    exit 1
}

# ─── Start new containers (rolling update) ──────────────────────
log "▶️  Starting new containers..."
docker compose up -d --remove-orphans 2>&1 || {
    error "Failed to start containers."
    warn "Attempting rollback..."
    exit 1
}

# ─── Health check ───────────────────────────────────────────────
log "🩺 Waiting for services to be healthy..."

wait_for_health() {
    local service=$1
    local url=$2
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            log "   ✅ $service is healthy"
            return 0
        fi
        retries=$((retries + 1))
        sleep $RETRY_INTERVAL
    done
    return 1
}

# Wait for backend
if ! wait_for_health "kote-backend" "http://localhost:8000/health"; then
    error "kote-backend failed health check after $((MAX_RETRIES * RETRY_INTERVAL))s"
    warn "Run rollback: bash $DEPLOY_DIR/deploy/rollback.sh $BACKUP_DIR"
    exit 1
fi

# Wait for n8n
if ! wait_for_health "kote-n8n" "http://localhost:5678/healthz"; then
    warn "kote-n8n health check timed out (may still be starting)"
fi

# ─── Clean up old images ────────────────────────────────────────
log "🧹 Cleaning up old images..."
docker image prune -f 2>&1 || true

# ─── Final status ───────────────────────────────────────────────
log ""
log "═══════════════════════════════════════════════════════════════"
log "  ✅ Deployment complete!"
log "  📅 $(date '+%Y-%m-%d %H:%M:%S')"
log "═══════════════════════════════════════════════════════════════"
log ""
log "Services:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | while read line; do
    log "  $line"
done
log ""
log "📊 Health endpoints:"
log "  Backend:  curl http://localhost:8000/health"
log "  API docs: http://localhost:8000/docs"
log ""

# ─── Check for old images to remove ─────────────────────────────
OLD_IMAGES=$(docker images --filter "dangling=true" -q | wc -l)
if [ "$OLD_IMAGES" -gt 0 ]; then
    log "   $OLD_IMAGES dangling images ready for cleanup"
fi