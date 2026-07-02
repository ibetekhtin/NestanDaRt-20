# RUNBOOK — операционка «симптом → действие»

> Единственный канон эксплуатации. Обновлён 2026-07-02. Все команды — рабочие, проверенные.

## Как устроен деплой (факт)

```
git push origin main
   ├─ GitHub CI: secret-scan → flake8 → docker build → ghcr.io (валидация)
   ├─ /var/www/nestandart: cron */5 git pull --ff-only  → статика (сайт, PWA, БАЗА)
   └─ backend вручную: cd /opt/nestandart && git pull && docker compose build kote-backend && docker compose up -d
```
Три чекаута одного репо: `/opt/nestandart` (рабочий) = `/var/www/nestandart` (статика) = origin/main.

## Cron-расписание (боевое)

| Время (UTC) | Бангкок | Что |
|---|---|---|
| `*/5` | — | healthcheck.sh: /health бэкенда и n8n, авторестарт контейнера при падении |
| `*/5` | — | git pull в /var/www (автодеплой статики) |
| 03:00 | 10:00 | backup-supabase.sh — REST-JSON выгрузка всех таблиц |
| 03:15 | 10:15 | run-backup.sh — **pg_dump** полной БД → /opt/nestandart/backups (30 дней daily + 12 недель weekly) |
| 03:30 | 10:30 | backup-vps.sh — конфиги (nginx, cron, .env) |
| 04:00 | **11:00** | backup-offsite.sh — **КотЭ шлёт все бэкапы в Telegram** (JSON + конфиги + pg_dump) |

## Симптом → действие

### 🤖 Бот молчит
```bash
curl -s http://127.0.0.1:5678/healthz                     # n8n жив?
docker logs kote-n8n --tail 30                             # ошибки?
TOKEN=$(grep TELEGRAM_BOT_TOKEN /opt/nestandart/.env | cut -d= -f2)
curl -s "https://api.telegram.org/bot$TOKEN/getWebhookInfo"  # last_error? pending?
docker restart kote-n8n                                    # перезапуск (воркфлоу активны в volume)
```
Помни: n8n исполняет ВЕРСИОНИРОВАННЫЙ снимок — после правки воркфлоу нужен publish + 2 рестарта (docs/N8N.md).

### 💳 Платёж завис / оплата без брони
Сверка гоняется n8n каждый час (pay-reconcile) и шлёт алерт менеджеру. Вручную:
```bash
SECRET=$(grep KOTE_RPC_SECRET /opt/nestandart/.env | cut -d= -f2)
curl -s -X POST http://127.0.0.1:8000/api/v1/pay/reconcile -H "X-Kote-Secret: $SECRET"
```
Ответ: `stale_pending` (зависшие >2ч) и `paid_without_booking` — если >0, смотреть таблицу payments в БАЗЕ/Supabase.

### 🌐 Сайт/PWA отдаёт 4xx/5xx
```bash
nginx -t && systemctl reload nginx        # конфиг живой?
ls /var/www/nestandart/platform/app.html  # файлы на месте? (cron pull мог не пройти)
cd /var/www/nestandart && git status && git log --oneline -1
```
ВАЖНО: live-конфиги nginx = /etc/nginx/sites-enabled/ (для главного сайта это КОПИИ файлов, не симлинки!).

### ⚙️ Backend 5xx / не отвечает
```bash
docker ps | grep kote-backend              # healthy?
docker logs kote-backend --tail 30
cd /opt/nestandart && docker compose up -d kote-backend
```
Healthcheck-cron сам рестартует упавший контейнер в течение 5 минут.

### 🔴 Плохой релиз — откат
```bash
cd /opt/nestandart && git revert HEAD && git push origin main
docker compose build kote-backend && docker compose up -d   # если менялся backend
# /var/www подтянет revert cron'ом в течение 5 минут
```

### 🔑 Утёк ключ
См. docs/SECURITY.md §«Если утёк ключ» (ротация в Supabase Dashboard → .env → compose up -d).

### 🧨 CI красный
https://github.com/ibetekhtin/NestanDaRt-20/actions — смотреть job: lint (flake8, ignore E501,W503,E241) или docker build. Токен на VPS имеет workflow-scope — правки ci-cd.yml пушатся.

## Restore из бэкапа

**pg_dump (полный)**:
```bash
set -a; source /opt/nestandart/.env; set +a
gunzip -c /opt/nestandart/backups/nestandart_backup_ДАТА.dump.gz | pg_restore -d "$SUPABASE_DB_URL" --clean --if-exists
```
⚠️ `--clean` перезаписывает таблицы. На живом проде — сначала восстановить в ветку Supabase и проверить.

**REST-JSON** (/root/backups/supabase/ДАТА/): точечное восстановление отдельных строк руками/скриптом.

**n8n**: воркфлоу живут в Docker-volume `kote-n8n-data` + актуальные экспорты в git (n8n/live/). Восстановление: import + publish (docs/N8N.md).

**Из Telegram**: все три бэкапа приходят КотЭ ежедневно в 11:00 Бангкока — можно скачать из чата.

## Проверка здоровья (одной командой)

```bash
/opt/nestandart/health-check.sh   # или вручную:
curl -s http://127.0.0.1:8000/health && curl -s -o /dev/null -w '%{http_code}\n' https://nestandart.online/ https://app.nestandart.online/ https://baza.nestandart.online/
```
