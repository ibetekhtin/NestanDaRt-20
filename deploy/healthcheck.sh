#!/bin/bash
# Healthcheck script for KOTЭ system
# Runs every 5 minutes via cron (*/5 * * * *)

LOG_FILE="/var/log/kote-health.log"
BACKEND_URL="http://127.0.0.1:8000/health"
API_URL="https://nestandart.online"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }

check_nginx() {
    if ! systemctl is-active --quiet nginx; then
        log "❌ nginx DOWN — restarting"
        systemctl restart nginx && log "✅ nginx restarted" || log "❌ nginx restart failed"
    fi
}

check_backend() {
    if ! curl -sf --max-time 5 "$BACKEND_URL" > /dev/null 2>&1; then
        log "❌ kote-backend DOWN — restarting"
        cd /opt/kote && docker compose restart kote-backend 2>/dev/null
        sleep 8
        if curl -sf --max-time 5 "$BACKEND_URL" > /dev/null 2>&1; then
            log "✅ kote-backend recovered"
        else
            log "❌ kote-backend still down after restart"
        fi
    fi
}

check_n8n() {
    if ! curl -sf --max-time 5 "http://127.0.0.1:5678/healthz" > /dev/null 2>&1; then
        log "❌ kote-n8n DOWN — restarting"
        cd /opt/kote && docker compose restart kote-n8n 2>/dev/null && log "✅ kote-n8n restarted"
    fi
}

check_nginx
check_backend
check_n8n
