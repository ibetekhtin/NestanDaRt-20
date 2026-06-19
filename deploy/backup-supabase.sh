#!/bin/bash
# ============================================================================
# Backup Supabase — KOTЭ SYSTEM (Improved)
# ============================================================================
# Usage: bash deploy/backup-supabase.sh
# Requires: SUPABASE_DB_URL env var (connection string)
#
# Creates:  SQL dump + optional S3 upload
# Schedule: Add to crontab:
#   0 3 * * * /opt/kote/deploy/backup-supabase.sh
# ============================================================================

set -euo pipefail
umask 077   # backups contain secrets — owner-only (rw-------)

BACKUP_DIR="/opt/kote/backups"
KEEP_DAYS=30
KEEP_WEEKLY=12
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/kote_backup_${DATE}.sql"
BACKUP_GZ="${BACKUP_FILE}.gz"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# ─── Prerequisites ─────────────────────────────────────────────
if [ -z "${SUPABASE_DB_URL:-}" ]; then
    error "SUPABASE_DB_URL not set"
    error "Usage: SUPABASE_DB_URL=postgresql://... bash $0"
    exit 1
fi

if ! command -v pg_dump &> /dev/null; then
    error "pg_dump not available. Install postgresql-client."
    exit 1
fi

log "📦 Starting Supabase backup..."
log "   Output: $BACKUP_GZ"

# ─── Database backup ───────────────────────────────────────────
log "   Running pg_dump..."
if pg_dump \
    --no-owner \
    --no-acl \
    --clean \
    --if-exists \
    --format=custom \
    "$SUPABASE_DB_URL" > "${BACKUP_DIR}/kote_backup_${DATE}.dump" 2>> "$LOG_FILE"; then
    log "   ✅ Database dump created successfully"
    
    # Compress
    gzip -f "${BACKUP_DIR}/kote_backup_${DATE}.dump" 2>> "$LOG_FILE"
    log "   ✅ Compressed: kote_backup_${DATE}.dump.gz"
else
    error "pg_dump failed. Check $LOG_FILE"
    # Fallback: try plain SQL format
    log "   Retrying with plain SQL format..."
    pg_dump \
        --no-owner \
        --no-acl \
        --clean \
        --if-exists \
        "$SUPABASE_DB_URL" > "$BACKUP_FILE" 2>> "$LOG_FILE" && \
    gzip -f "$BACKUP_FILE" 2>> "$LOG_FILE" && \
    log "   ✅ Plain SQL backup created"
fi

# ─── Config backup ─────────────────────────────────────────────
log "   Backing up configurations..."
CONFIG_BACKUP="${BACKUP_DIR}/config_backup_${DATE}.tar.gz"
tar czf "$CONFIG_BACKUP" \
    -C /opt/kote .env \
    -C /opt/kote/deploy nginx.conf \
    -C /opt/kote docker-compose.yml 2>/dev/null && \
    log "   ✅ Config backup: config_backup_${DATE}.tar.gz" || \
    log "   ⚠️ Config backup skipped (some files may not exist)"

# ─── File size report ─────────────────────────────────────────
log ""
log "   📊 Backup file sizes:"
ls -lh "${BACKUP_DIR}"/*"${DATE}"* 2>/dev/null | awk '{print "      "$5" "$NF}' | while read line; do log "$line"; done

# ─── Cleanup old backups ──────────────────────────────────────
log ""
log "🧹 Cleaning up old backups..."

# Remove daily backups older than KEEP_DAYS
find "$BACKUP_DIR" -name "kote_backup_*.sql.gz" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "kote_backup_*.dump.gz" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "config_backup_*.tar.gz" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true

# Keep weekly backups (Monday) for KEEP_WEEKLY weeks
find "$BACKUP_DIR" -name "kote_backup_*.sql.gz" ! -name "*_Mon_*" -mtime +7 -delete 2>/dev/null || true

# Remove empty backup files
find "$BACKUP_DIR" -name "kote_backup_*.sql" -size 0 -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "kote_backup_*.dump" -size 0 -delete 2>/dev/null || true

log "   ✅ Cleanup complete"

# ─── Optional: Upload to S3/Cloud ─────────────────────────────
if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ] && [ -n "${S3_BUCKET:-}" ]; then
    log "☁️  Uploading to S3..."
    if command -v aws &> /dev/null; then
        LATEST_DUMP=$(ls -t "${BACKUP_DIR}"/kote_backup_*.dump.gz 2>/dev/null | head -1)
        if [ -n "$LATEST_DUMP" ]; then
            aws s3 cp "$LATEST_DUMP" "s3://${S3_BUCKET}/supabase/$(basename "$LATEST_DUMP")" 2>> "$LOG_FILE" && \
                log "   ✅ Uploaded to S3" || \
                error "   S3 upload failed"
        fi
    else
        warn "   aws CLI not available. Install: pip install awscli"
    fi
fi

# ─── Final report ─────────────────────────────────────────────
log ""
log "═══════════════════════════════════════════════════════════════"
log "  ✅ Backup complete!"
log "  📅 $DATE"
log "  📁 $BACKUP_DIR"
log "  ⏳ Retention: $KEEP_DAYS days daily + $KEEP_WEEKLY weeks weekly"
log "═══════════════════════════════════════════════════════════════"