#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Нестандартный Отдых® — проверка здоровья системы
# Запуск:  ./health-check.sh
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SITE="https://nestandart-phuket.ru"
VPS="root@77.42.93.187"
SUPA="https://cmmdrhususjuadqzyssc.supabase.co"

# Ключ читается из .env (НИКОГДА не хранить в коде)
# Укажи путь к файлу или экспортируй переменную: export SUPABASE_ANON_KEY=...
ANON="${SUPABASE_ANON_KEY:-$(grep -s '^SUPABASE_ANON_KEY=' /opt/kote/.env | cut -d= -f2)}"
if [ -z "$ANON" ]; then
  echo "⚠️  SUPABASE_ANON_KEY не задан. Экспортируй переменную или проверь /opt/kote/.env"
  exit 1
fi

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass=0; fail=0

ok()   { echo -e "  ${GREEN}✅${NC} $1"; pass=$((pass+1)); }
bad()  { echo -e "  ${RED}❌ $1${NC}"; fail=$((fail+1)); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }

# code <url> → HTTP-код, или 000 при таймауте
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 12 "$1" 2>/dev/null; }

echo "═══════════════════════════════════════"
echo "  НЕСТАНДАРТНЫЙ ОТДЫХ — здоровье системы"
echo "  $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════"

echo ""
echo "▸ САЙТ"
[ "$(code $SITE/)" = "200" ] && ok "главная 200" || bad "главная недоступна"
[ "$(code $SITE/baza/)" = "200" ] && ok "БАЗА (/baza) 200" || bad "БАЗА недоступна"
[ "$(code $SITE/favicon.svg)" = "200" ] && ok "favicon" || warn "favicon не отдаётся"
# HTTP → HTTPS редирект
rc=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://nestandart-phuket.ru/ 2>/dev/null)
[ "$rc" = "301" ] || [ "$rc" = "308" ] && ok "HTTP→HTTPS редирект ($rc)" || warn "редирект на HTTPS: $rc"
# SSL: дней до истечения
days=$(echo | openssl s_client -connect nestandart-phuket.ru:443 -servername nestandart-phuket.ru 2>/dev/null \
  | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$days" ]; then
  exp=$(date -j -f "%b %d %T %Y %Z" "$days" +%s 2>/dev/null || date -d "$days" +%s 2>/dev/null)
  now=$(date +%s); left=$(( (exp - now) / 86400 ))
  [ "$left" -gt 14 ] && ok "SSL ещё $left дн." || warn "SSL истекает через $left дн.!"
fi
# Заголовки безопасности (ждём 4)
h=$(curl -sI --max-time 10 $SITE/ | grep -icE 'strict-transport|x-frame|x-content|referrer-policy')
[ "$h" -ge 4 ] && ok "security-заголовки ($h/4)" || warn "security-заголовков только $h/4"

echo ""
echo "▸ БАЗА ДАННЫХ (Supabase RLS)"
cl=$(curl -s --max-time 12 "$SUPA/rest/v1/clients?limit=1" -H "apikey: $ANON" -H "Authorization: Bearer $ANON")
[ "$cl" = "[]" ] && ok "anon НЕ видит клиентов (приватность)" || bad "anon читает clients: $cl"
tr=$(curl -s --max-time 12 "$SUPA/rest/v1/tours?limit=1&select=title" -H "apikey: $ANON" -H "Authorization: Bearer $ANON")
echo "$tr" | grep -q '"title"' && ok "anon видит туры (каталог жив)" || bad "туры не читаются"
# Память КотЭ закрыта без секрета
mem=$(curl -s --max-time 12 -X POST "$SUPA/rest/v1/rpc/get_kote_context" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
  -d '{"p_tg_chat_id":"probe","p_query":"туры"}')
name=$(echo "$mem" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["client_name"])' 2>/dev/null)
tours=$(echo "$mem" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)[0]["tours_catalog"]))' 2>/dev/null)
if [ "$name" = "None" ] && [ "${tours:-0}" -gt 0 ]; then
  ok "память КотЭ закрыта без секрета, каталог отдаётся ($tours туров)"
else
  bad "защита памяти КотЭ: name=$name tours=$tours"
fi

echo ""
echo "▸ VPS + КотЭ"
if ssh -o BatchMode=yes -o ConnectTimeout=10 "$VPS" 'true' 2>/dev/null; then
  ok "SSH доступен"
  remote=$(ssh -o BatchMode=yes "$VPS" '
    for c in kote-n8n kote-backend; do
      s=$(docker inspect -f "{{.State.Status}}" $c 2>/dev/null)
      [ "$s" = "running" ] && echo "  ✅ $c: running" || echo "  ❌ $c: ${s:-нет}"
    done
    disk=$(df / | awk "NR==2{print \$5}" | tr -d %)
    [ "$disk" -lt 85 ] && echo "  ✅ диск ${disk}%" || echo "  ⚠️  диск ${disk}% — чистить"
    cd /var/www/nestandart && echo "  ✅ сайт на коммите $(git rev-parse --short HEAD)"
    # Telegram webhook
    T=$(grep "^TELEGRAM_BOT_TOKEN=" /opt/kote/.env | cut -d= -f2)
    err=$(curl -s "https://api.telegram.org/bot$T/getWebhookInfo" | python3 -c "import json,sys; r=json.load(sys.stdin)[\"result\"]; print(r.get(\"last_error_message\") or \"ok\")" 2>/dev/null)
    q=$(curl -s "https://api.telegram.org/bot$T/getWebhookInfo" | python3 -c "import json,sys; print(json.load(sys.stdin)[\"result\"][\"pending_update_count\"])" 2>/dev/null)
    [ "$err" = "ok" ] && echo "  ✅ Telegram webhook чист (очередь: $q)" || echo "  ❌ webhook ошибка: $err"
    # Мозг КотЭ: валиден ли Gemini-ключ (без него бот не отвечает)
    GK=$(grep "^GEMINI_API_KEY=" /opt/kote/.env | cut -d= -f2-)
    gc=$(curl -s -o /dev/null -w "%{http_code}" --max-time 12 "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GK" -H "Content-Type: application/json" -d "{\"contents\":[{\"parts\":[{\"text\":\"hi\"}]}]}")
    [ "$gc" = "200" ] && echo "  ✅ мозг КотЭ: Gemini отвечает (бот думает)" || echo "  ❌ мозг КотЭ молчит: Gemini вернул $gc — нужен валидный ключ в /opt/kote/.env"
  ')
  echo "$remote"
  # Считаем ❌ из удалённого блока в общий счётчик
  rfail=$(printf '%s\n' "$remote" | grep -c '❌')
  fail=$((fail + rfail)); pass=$((pass + $(printf '%s\n' "$remote" | grep -c '✅')))
else
  bad "SSH к VPS недоступен"
fi

echo ""
echo "═══════════════════════════════════════"
if [ "$fail" -eq 0 ]; then
  echo -e "  ${GREEN}ВСЁ ЗДОРОВО — $pass проверок пройдено${NC}"
else
  echo -e "  ${RED}ПРОБЛЕМ: $fail${NC} | ${GREEN}OK: $pass${NC} — смотри ❌ выше"
fi
echo "═══════════════════════════════════════"
exit $fail
