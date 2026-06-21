#!/usr/bin/env bash
# Деплой HQ (админка) на nestandart.online/hq/ — статический Vite-билд за nginx.
# Перед запуском заполни hq/.env: VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY (anon — публичный).
# Запуск из корня репо:  bash deploy/deploy-hq.sh
set -euo pipefail
VPS="${KOTE_VPS:-root@77.42.93.187}"
DEST="/var/www/nestandart/hq"

cd "$(dirname "$0")/../hq"
echo "→ npm install + build (base=/hq/)"
npm install --no-audit --no-fund --loglevel=error
VITE_BASE=/hq/ npm run build

echo "→ upload dist → $VPS:$DEST"
ssh "$VPS" "mkdir -p $DEST"
rsync -az --delete dist/ "$VPS:$DEST/"

echo "→ nginx: добавь блок из deploy/nginx-hq.conf в server nestandart.online, затем:"
echo "   ssh $VPS 'nginx -t && systemctl reload nginx'"
echo "✅ HQ собран и загружен. Открой https://nestandart.online/hq/ после reload nginx."
