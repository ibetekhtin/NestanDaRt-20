# 🚀 Deployment Guide — KOTЭ SYSTEM

## Quick Deploy (Docker Compose)

```bash
# На VPS (Hetzner CPX21 recommended)
git clone <repo> /opt/kote
cd /opt/kote
cp .env.example .env
nano .env  # Заполни ключи
docker compose up -d
```

## VPS Setup (Hetzner)

1. Создай сервер CPX21 (4 vCPU, 8GB RAM) Ubuntu 24.04
2. Запусти `deploy/setup-vps.sh`
3. Склонируй репозиторий
4. Настрой `.env`
5. Запусти `docker compose up -d`

## Nginx

`deploy/nginx.conf` reverse proxy:
- `/` → static website
- `/api` → backend:8000
- `/n8n` → n8n:5678
- SSL через Let's Encrypt (certbot)

## Backups

```bash
deploy/backup-supabase.sh
# pg_dump с retention 7 дней
# опционально: загрузка в S3
```

## Monitoring

```bash
deploy/healthcheck.sh
# Проверяет backend, n8n, bot
```

## Service Management

```bash
docker compose logs -f          # Логи
docker compose restart bot      # Перезапуск бота
docker compose pull && docker compose up -d  # Обновление
make validate                   # Проверка кода
```

## Systemd (fallback)

Без Docker: `deploy/systemd/kote-bot.service`