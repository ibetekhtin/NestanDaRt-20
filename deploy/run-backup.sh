#!/bin/bash
# Обёртка: загружает .env и запускает pg_dump backup
set -a
source /opt/kote/.env
set +a
exec /opt/kote/deploy/backup-supabase.sh
