#!/bin/bash
# Обёртка: загружает .env и запускает pg_dump backup
set -a
source /opt/NestanDaRt-20/.env
set +a
exec /opt/NestanDaRt-20/deploy/backup-supabase.sh
