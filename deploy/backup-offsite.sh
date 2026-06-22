#!/usr/bin/env bash
# Offsite backup: zip today's dumps → send to Telegram admin chat
# Runs after backup-supabase.sh and backup-vps.sh (cron 04:00)
set -euo pipefail
umask 077

set -a; source /opt/kote/.env; set +a

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:?}"
CHAT_ID="${TELEGRAM_ADMIN_CHAT_ID:?}"
TODAY=$(date +%F)
TMP="/tmp/kote-backup-$TODAY"
mkdir -p "$TMP"

# 1. Pack Supabase JSON dump
SUPA_DIR="/root/backups/supabase/$TODAY"
if [ -d "$SUPA_DIR" ]; then
  tar czf "$TMP/supabase-$TODAY.tar.gz" -C /root/backups/supabase "$TODAY"
  curl -sf -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F chat_id="$CHAT_ID" \
    -F document=@"$TMP/supabase-$TODAY.tar.gz" \
    -F caption="🗄 Supabase backup $TODAY ($(du -sh $TMP/supabase-$TODAY.tar.gz | cut -f1))" \
    > /dev/null
  echo "[$TODAY] supabase backup sent"
else
  echo "[$TODAY] WARNING: supabase dir not found, skipping"
fi

# 2. Send VPS config backup (latest file)
VPS_FILE=$(ls -t /root/backups/vps/config-*.tar.gz 2>/dev/null | head -1)
if [ -n "$VPS_FILE" ]; then
  curl -sf -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F chat_id="$CHAT_ID" \
    -F document=@"$VPS_FILE" \
    -F caption="⚙️ VPS config backup $TODAY ($(du -sh $VPS_FILE | cut -f1))" \
    > /dev/null
  echo "[$TODAY] vps backup sent"
fi

rm -rf "$TMP"
