#!/bin/bash
# ============================================================================
# Backup Supabase — KOTЭ SYSTEM
# ============================================================================
# Usage: bash deploy/backup-supabase.sh
# Requires: SUPABASE_DB_URL env var (connection string)
# ============================================================================

BACKUP_DIR="/opt/kote/backups"
KEEP_DAYS=7

mkdir -p "$BACKUP_DIR"

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/kote_backup_${DATE}.sql"

if [ -z "$SUPABASE_DB_URL" ]; then
  echo "❌ SUPABASE_DB_URL not set"
  exit 1
fi

echo "📦 Backing up Supabase..."

# Using pg_dump if available
if command -v pg_dump &> /dev/null; then
  pg_dump "$SUPABASE_DB_URL" > "$BACKUP_FILE"
  echo "✅ Backup saved: $BACKUP_FILE"
else
  echo "⚠️  pg_dump not available. Use Supabase Dashboard → SQL Editor → Download backup."
  exit 1
fi

# Cleanup old backups
find "$BACKUP_DIR" -name "kote_backup_*.sql" -mtime +$KEEP_DAYS -delete
echo "🧹 Cleaned backups older than $KEEP_DAYS days"