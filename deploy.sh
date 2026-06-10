#!/bin/bash
# ============================================================================
# KOTЭ SYSTEM — универсальный деплой на VPS
# ============================================================================
# Запуск: bash deploy.sh ТВОЙ_ПАРОЛЬ
#   или: bash deploy.sh (пароль будет запрошен)
# ============================================================================

set -e

VPS_IP="178.105.195.178"
VPS_USER="root"
PASSWORD="${1:-}"

if [ -z "$PASSWORD" ]; then
  read -s -p "Введите пароль от VPS ($VPS_USER@$VPS_IP): " PASSWORD
  echo ""
fi

echo "🚀 KOTЭ DEPLOY — $(date)"

# Архив
echo "📦 Создаю архив..."
cd "$(dirname "$0")"
tar --exclude=node_modules --exclude=__pycache__ --exclude=.git --exclude=logs \
    -czf /tmp/kote-deploy.tar.gz \
    bot/ app/ deploy/ docs/ n8n/ supabase/ website/ ai/ \
    .gitignore .dockerignore .env.example docker-compose.yml \
    Makefile README.md CHANGELOG.md LICENSE PROJECT.md CLAUDE.md PLAN.md 2>/dev/null

ARCHIVE_SIZE=$(ls -lh /tmp/kote-deploy.tar.gz | awk '{print $5}')
echo "   Архив готов: $ARCHIVE_SIZE"

# SCP на VPS
echo "📤 Копирую на VPS..."
export SSHPASS="$PASSWORD"
sshpass -e scp -o StrictHostKeyChecking=no /tmp/kote-deploy.tar.gz "$VPS_USER@$VPS_IP:/tmp/" 2>&1

# SSH + разворачиваем
echo "🔧 Разворачиваю на VPS..."
sshpass -e ssh -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" \
  "mkdir -p /opt/kote && cd /opt/kote && tar -xzf /tmp/kote-deploy.tar.gz && cp -n .env.example .env && echo '✅ Файлы развёрнуты в /opt/kote/'" 2>&1

echo ""
echo "═════════════════════════════════════"
echo "  ✅ DEPLOY COMPLETE!"
echo "═════════════════════════════════════"
echo ""
echo "  ➡️  Подключись и настрой .env:"
echo "      ssh root@$VPS_IP"
echo "      cd /opt/kote"
echo "      nano .env"
echo ""
echo "  ➡️  Запусти:"
echo "      docker compose up -d"
echo ""