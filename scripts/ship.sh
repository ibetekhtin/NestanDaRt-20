#!/usr/bin/env bash
# KOTЭ — деплой одной командой: запушить main → подтянуть на VPS → пересобрать backend.
# Спрашивает подтверждение (деплой = прод). Запуск: make ship  (или bash scripts/ship.sh)
set -euo pipefail
VPS="${KOTE_VPS:-root@77.42.93.187}"

echo "Деплой: локальный main → GitHub → VPS ($VPS) → пересборка kote-backend."
read -rp "Продолжить? [y/N] " ok
[ "$ok" = "y" ] || { echo "отмена"; exit 0; }

git push origin HEAD:main
ssh "$VPS" 'cd /opt/kote \
  && git pull --ff-only origin main \
  && docker compose up -d --build kote-backend \
  && docker compose ps --format "{{.Name}} {{.Status}}"'
echo "✅ задеплоено"
