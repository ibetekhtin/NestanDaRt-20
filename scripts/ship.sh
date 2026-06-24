#!/usr/bin/env bash
# NestanDaRt-20 — деплой одной командой: запушить main → подтянуть на VPS → пересобрать backend.
# Спрашивает подтверждение (деплой = прод). Запуск: make ship  (или bash scripts/ship.sh)
set -euo pipefail
VPS="${NESTANDART_VPS:-root@77.42.93.187}"

echo "Деплой: локальный main → GitHub → VPS ($VPS) → пересборка nestandart-backend."
read -rp "Продолжить? [y/N] " ok
[ "$ok" = "y" ] || { echo "отмена"; exit 0; }

git push origin HEAD:main
ssh "$VPS" 'cd /opt/NestanDaRt-20 \
  && git pull --ff-only origin main \
  && docker compose up -d --build nestandart-backend \
  && docker compose ps --format "{{.Name}} {{.Status}}"'
echo "✅ задеплоено"
