#!/usr/bin/env bash
# ============================================================
# enable-kote-secret.sh — активирует KOTE_SECRET в n8n и backend
# Запускать на VPS: bash /opt/nestandart/scripts/enable-kote-secret.sh
# ============================================================
set -euo pipefail

DIR="/opt/nestandart"
ENV_FILE="$DIR/.env"

cd "$DIR"

# ── 1. Загрузить текущие переменные ─────────────────────────
source "$ENV_FILE"

# ── 2. Проверить: секрет уже задан? ─────────────────────────
EXISTING=$(grep -E '^KOTE_RPC_SECRET=.+' "$ENV_FILE" | cut -d= -f2 | tr -d '"' || true)
if [ -n "$EXISTING" ]; then
  echo "⚠️  KOTE_RPC_SECRET уже задан в .env: ${EXISTING:0:8}..."
  echo "    Используем существующий."
  SECRET="$EXISTING"
else
  # ── 3. Сгенерировать новый секрет ───────────────────────
  SECRET=$(openssl rand -hex 32)
  echo "🔑 Сгенерирован секрет: ${SECRET:0:8}..."

  # Добавить KOTE_SECRET для n8n и KOTE_RPC_SECRET для backend
  echo "" >> "$ENV_FILE"
  echo "KOTE_SECRET=$SECRET" >> "$ENV_FILE"
  echo "KOTE_RPC_SECRET=$SECRET" >> "$ENV_FILE"
  echo "✅ Секрет добавлен в .env"
fi

# ── 4. Обновить ноды в n8n через REST API ───────────────────
N8N_URL="http://localhost:5678"
N8N_USER="${N8N_USER:-admin}"
N8N_PASS="${N8N_PASSWORD:-}"

if [ -z "$N8N_PASS" ]; then
  echo "❌ N8N_PASSWORD не задан в .env — обновление workflow пропущено"
  echo "   Добавь заголовок вручную в n8n UI (инструкция ниже)"
else
  echo ""
  echo "📡 Подключаюсь к n8n API..."

  # Найти workflow КотЭ по ID или по имени
  WF_RESPONSE=$(curl -s -u "$N8N_USER:$N8N_PASS" "$N8N_URL/api/v1/workflows?limit=100")
  WF_ID=$(echo "$WF_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
wfs = data.get('data', data) if isinstance(data, dict) else data
for wf in wfs:
    name = wf.get('name','')
    if 'кот' in name.lower() or 'bot' in name.lower() or 'telegram' in name.lower():
        print(wf['id'])
        break
" 2>/dev/null || true)

  if [ -z "$WF_ID" ]; then
    echo "⚠️  Workflow КотЭ не найден автоматически."
    echo "   Workflows в n8n:"
    echo "$WF_RESPONSE" | python3 -c "
import json,sys
data = json.load(sys.stdin)
wfs = data.get('data', data) if isinstance(data, dict) else data
for wf in wfs: print(f\"  {wf['id']}  {wf['name']}\")
" 2>/dev/null || true
    echo ""
    read -p "   Введи ID workflow КотЭ вручную: " WF_ID
  fi

  if [ -n "$WF_ID" ]; then
    echo "   Workflow ID: $WF_ID"

    # Получить полный workflow
    WF_JSON=$(curl -s -u "$N8N_USER:$N8N_PASS" "$N8N_URL/api/v1/workflows/$WF_ID")

    # Добавить X-Kote-Secret в нужные ноды через Python
    UPDATED=$(echo "$WF_JSON" | python3 - <<'PYEOF'
import json, sys
wf = json.load(sys.stdin)
SECRET_HEADER = {"name": "X-Kote-Secret", "value": "={{ $env.KOTE_SECRET }}"}
TARGET_NODES = {"🤖 Gemini", "💳 Создать оплату"}
patched = []
for node in wf.get('nodes', []):
    if node.get('name') in TARGET_NODES:
        params = node.setdefault('parameters', {})
        hp = params.setdefault('headerParameters', {})
        existing = hp.setdefault('parameters', [])
        if not any(p.get('name') == 'X-Kote-Secret' for p in existing):
            existing.append(SECRET_HEADER)
            patched.append(node['name'])
print(json.dumps(wf), file=sys.stdout)
import sys; print(f"Patched: {patched}", file=sys.stderr)
PYEOF
)

    # Сохранить через PUT
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      -X PUT "$N8N_URL/api/v1/workflows/$WF_ID" \
      -u "$N8N_USER:$N8N_PASS" \
      -H "Content-Type: application/json" \
      -d "$UPDATED")

    if [ "$HTTP_STATUS" = "200" ]; then
      echo "✅ Workflow обновлён — X-Kote-Secret добавлен в ноды"
    else
      echo "⚠️  Ответ n8n API: $HTTP_STATUS"
      echo "   Попробуй обновить workflow вручную (инструкция ниже)"
    fi
  fi
fi

# ── 5. Перезапустить оба сервиса ────────────────────────────
echo ""
echo "🔄 Перезапускаю backend..."
docker compose up -d --force-recreate kote-backend

echo "🔄 Перезапускаю n8n..."
docker compose up -d --force-recreate kote-n8n

echo ""
echo "⏳ Жду backend..."
for i in $(seq 1 15); do
  if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ Backend OK"
    break
  fi
  sleep 2
done

echo ""
echo "══════════════════════════════════════════════"
echo "✅ ГОТОВО. KOTE_SECRET активирован."
echo ""
echo "Если workflow не обновился автоматически — добавь вручную:"
echo "  n8n.nestandart.online → workflow КотЭ"
echo "  Нода «🤖 Gemini»      → Headers → добавить:"
echo "    Name:  X-Kote-Secret"
echo "    Value: {{ \$env.KOTE_SECRET }}"
echo "  Нода «💳 Создать оплату» — то же самое"
echo "══════════════════════════════════════════════"
