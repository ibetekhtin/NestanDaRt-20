#!/bin/bash
# Обёртка: загружает .env и запускает pg_dump backup
set -a
source /opt/nestandart/.env
set +a
exec /opt/nestandart/deploy/backup-supabase.sh
