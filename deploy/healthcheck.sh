#!/bin/bash
# Healthcheck + Telegram alerts for КОТЭ system
# Runs every 5 minutes via cron (*/5 * * * *)

LOG_FILE="/var/log/kote-health.log"
BACKEND_URL="http://127.0.0.1:8000/health"

set -a; source /opt/kote/.env 2>/dev/null; set +a

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }

alert() {
  local msg="$1"
  log "ALERT: $msg"
  curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_ADMIN_CHAT_ID}" \
    -d text="$msg" \
    -d parse_mode="HTML" > /dev/null 2>&1 || true
}

check_nginx() {
  if ! systemctl is-active --quiet nginx; then
    systemctl restart nginx 2>/dev/null
    sleep 3
    if systemctl is-active --quiet nginx; then
      alert "⚠️ <b>nginx</b> упал и перезапущен — проверь логи"
    else
      alert "🚨 <b>nginx DOWN</b> — перезапуск не помог! VPS: 77.42.93.187"
    fi
  fi
}

check_backend() {
  if ! curl -sf --max-time 5 "$BACKEND_URL" > /dev/null 2>&1; then
    cd /opt/kote && docker compose restart kote-backend > /dev/null 2>&1
    sleep 10
    if curl -sf --max-time 5 "$BACKEND_URL" > /dev/null 2>&1; then
      alert "⚠️ <b>kote-backend</b> упал и перезапущен"
    else
      alert "🚨 <b>kote-backend DOWN</b> — перезапуск не помог! VPS: 77.42.93.187"
    fi
  fi
}

check_n8n() {
  if ! curl -sf --max-time 5 "http://127.0.0.1:5678/healthz" > /dev/null 2>&1; then
    cd /opt/kote && docker compose restart kote-n8n > /dev/null 2>&1
    sleep 10
    if curl -sf --max-time 5 "http://127.0.0.1:5678/healthz" > /dev/null 2>&1; then
      alert "⚠️ <b>kote-n8n</b> (бот) упал и перезапущен"
    else
      alert "🚨 <b>kote-n8n DOWN</b> — перезапуск не помог! Бот не отвечает. VPS: 77.42.93.187"
    fi
  fi
}

check_disk() {
  local usage=$(df / --output=pcent | tail -1 | tr -d ' %')
  if [ "$usage" -ge 85 ]; then
    alert "🚨 <b>Диск ${usage}% заполнен</b> — срочно освободи место! VPS: 77.42.93.187"
  fi
}

check_nginx
check_backend
check_n8n
check_disk
