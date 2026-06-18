#!/bin/bash
# ============================================================================
# Rollback Script — KOTЭ SYSTEM
# ============================================================================
# Usage: bash deploy/rollback.sh [backup_dir]
# Example: bash deploy/rollback.sh /opt/kote-backups/20260618_120000
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $1"; }
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

DEPLOY_DIR="/opt/kote"

if [ $# -lt 1 ]; then
    echo "Usage: $0 [backup_dir]"
    echo "Available backups:"
    ls -d /opt/kote-backups/*/ 2>/dev/null | head -10 || echo "  No backups found"
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    error "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

log "🔄 Starting rollback from: $BACKUP_DIR"
log ""

# ─── Restore .env ──────────────────────────────────────────────
if [ -f "$BACKUP_DIR/.env.backup" ]; then
    log "📄 Restoring .env..."
    cp "$BACKUP_DIR/.env.backup" "$DEPLOY_DIR/.env"
    log "   ✅ .env restored"
fi

# ─── Restore n8n data ──────────────────────────────────────────
if [ -f "$BACKUP_DIR/n8n-db.sqlite" ]; then
    log "🗄️  Restoring n8n database..."
    docker compose cp "$BACKUP_DIR/n8n-db.sqlite" kote-n8n:/home/node/.n8n/database.sqlite 2>/dev/null || \
        warn "   ⚠️ Could not restore n8n DB (container may not be running)"
    log "   ✅ n8n data restored"
fi

# ─── Restore git state ─────────────────────────────────────────
log "📥 Restoring git state..."
cd "$DEPLOY_DIR"
git log --oneline -1 2>/dev/null
warn "   Manual git revert may be needed: git revert HEAD"

# ─── Rebuild and restart ──────────────────────────────────────
log "🔨 Rebuilding and restarting services..."
docker compose build 2>&1 || warn "   ⚠️ Build may have issues"
docker compose up -d 2>&1 || error "   ❌ Failed to start services"

# ─── Health check ──────────────────────────────────────────────
log "🩺 Running health check..."
sleep 10
if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    log "   ✅ Backend is healthy"
else
    warn "   ⚠️ Backend health check failed"
fi

log ""
log "═══════════════════════════════════════════════════════════════"
log "  ✅ Rollback complete from: $(basename $BACKUP_DIR)"
log "  📅 $(date '+%Y-%m-%d %H:%M:%S')"
log "═══════════════════════════════════════════════════════════════"
log ""
log "Next steps if issues persist:"
log "  1. Check logs: docker compose logs kote-backend"
log "  2. Check n8n logs: docker compose logs kote-n8n"
log "  3. Revert code: git revert HEAD~1 && git push"
log "  4. Full redeploy: bash deploy/deploy.sh"