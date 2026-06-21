# CLAUDE.md — МАСТЕР-ФАЙЛ ПРОЕКТА
# Нестандартный Отдых® / КотЭ System
> Последнее обновление: 2026-06-21 · v3 — VPS↔GitHub сведены (прод под git), AI-каскад groq-first, структура репо почищена
> Этот файл — единственный источник истины для Claude Code и любого AI-агента.
> Читать полностью перед любой работой с проектом.

---

## 🗺️ ЧТО ЭТО ЗА ПРОЕКТ

**Нестандартный Отдых®** — туристическая платформа в Таиланде (Пхукет, Паттайя).  
Продаём авторские экскурсии. Главный инструмент продаж — **Telegram-бот КотЭ** на базе AI.

**Бизнес-модель:** клиент пишет в Telegram → КотЭ помогает выбрать тур → менеджер закрывает сделку → клиент едет на экскурсию.

---

## 🏗️ АРХИТЕКТУРА СИСТЕМЫ

```
┌─────────────────────────────────────────────────────────────────┐
│                    КЛИЕНТ                                       │
│  Telegram  /  Сайт nestandart.online  /  app.nestandart.online  │
└────────────────────┬────────────────────────────────────────────┘
                     │
         ┌───────────▼──────────┐
         │    nginx (reverse    │  VPS 77.42.93.187
         │    proxy + SSL)      │  Ubuntu 22.04
         └──┬──────────┬────────┘
            │          │
   ┌────────▼──┐  ┌────▼──────────────────┐
   │  FastAPI  │  │  n8n (self-hosted)     │
   │ kote-back │  │  n8n.nestandart.online │
   │ port 8000 │  │  port 5678             │
   └────────┬──┘  └────────┬───────────────┘
            │               │
            └───────┬───────┘
                    │
         ┌──────────▼──────────┐
         │  Supabase (Cloud)   │
         │  PostgreSQL + Auth  │
         │  + RLS + Functions  │
         │  cmmdrhususjuadqzyssc│
         └─────────────────────┘
```

### Сервисы на VPS

| Сервис | Тип | Порт (хост) | URL |
|--------|-----|-------------|-----|
| nginx | systemd | 80, 443 | — |
| kote-backend | Docker | 127.0.0.1:8000 | nestandart.online/api/v1/ |
| kote-n8n | Docker | 127.0.0.1:5678 | n8n.nestandart.online |
| nestandart-api | PM2 (Node.js) | 127.0.0.1:3055 | nestandart.online/api/leads |
| fail2ban | systemd | — | защита SSH |

### Дополнительные процессы (не трогать)
- `node /opt/nestandart-api/server.js` — старый Node.js API лидов, управляется PM2, работает
- `next-server` — VS Code Remote Extensions, не production-компонент

---

## 📁 СТРУКТУРА МОНОРЕПО (/opt/kote/)

```
/opt/kote/
├── CLAUDE.md                  ← ЭТОТ ФАЙЛ (мастер-документ)
├── docker-compose.yml         ← базовый compose
├── docker-compose.override.yml← порты + env overrides
├── .env                       ← СЕКРЕТЫ (не коммитить!)
├── .env.example               ← шаблон без секретов
│
├── app/backend/               ← FastAPI REST API
│   ├── main.py                ← app setup + CORS + include_router (v2)
│   ├── config.py              ← pydantic-settings
│   ├── Dockerfile
│   ├── requirements.txt
│   └── routers/               ← ВСЕ ПОДКЛЮЧЕНЫ через include_router в main.py
│       ├── ai.py              ← POST /api/v1/ai/ask + /ai/chat (passthrough для n8n-бота)
│       ├── bookings.py        ← POST/GET/PATCH /api/v1/bookings
│       ├── clients.py         ← GET /api/v1/clients/{tg_chat_id}
│       ├── leads.py           ← POST/GET /api/v1/leads
│       ├── markets.py         ← GET /api/v1/markets[/{id}]
│       ├── memory.py          ← GET/POST /api/v1/clients/{id}/memory
│       ├── sos.py             ← POST /api/v1/sos
│       ├── tours.py           ← GET /api/v1/tours[/{id|slug}]
│       ├── webhooks.py        ← POST /api/v1/webhook/{lead,booking}
│       └── __init__.py
│
├── providers/                 ← AI fallback chain (groq→aitunnel→openrouter→gemini)
│   ├── __init__.py
│   ├── ai.py                  ← роутер: AI_PROVIDER_ORDER + авто-пропуск без ключа
│   ├── groq.py                ← основной (ultra-fast)
│   ├── aitunnel.py            ← 2-й
│   ├── openrouter.py          ← 3-й
│   └── gemini.py              ← финальный резерв (gemini-2.5-flash)
│
├── platform/
│   ├── app.html               ← PWA (Telegram Mini App), 230 KB self-contained
│   ├── kote/
│   │   ├── prompt.txt         ← ЛИЧНОСТЬ КотЭ (редактировать здесь)
│   │   └── workflow.json      ← n8n workflow export (документация)
│   ├── supabase/
│   │   └── schema.sql         ← СПРАВОЧНИК схемы (не источник истины!)
│   ├── bot/                   ← Python-бот (выключен, живёт в n8n Cloud)
│   └── docs/
│       ├── STACK.md
│       ├── SUPABASE.md
│       ├── MULTI_MARKET.md
│       ├── KOTE_SYSTEM.md
│       └── ROADMAP.md
│
├── hq/                        ← React Vite (внутренняя CRM-панель)
│   └── src/components/
│       ├── DashboardView.jsx
│       ├── CRMView.jsx
│       ├── KanbanView.jsx
│       ├── ContentFactoryView.jsx
│       ├── FinanceView.jsx
│       └── WikiView.jsx
│
├── n8n/
│   └── flows/                 ← экспорты n8n workflows (документация)
│       ├── booking-flow.json
│       ├── booking-confirm.json
│       ├── daily-report.json
│       ├── lead-intake.json
│       ├── market-sync.json
│       ├── memory-update.json
│       ├── reminder.json
│       └── sos.json
│
├── nestandart-phuket/         ← HTML-сайт (публичный)
├── shared/                    ← константы рынков и бренда
├── deploy/
│   ├── backup-supabase.sh     ← SQL бэкап (нужен SUPABASE_DB_URL)
│   └── healthcheck.sh         ← авто-рестарт при падении (cron */5 мин)
└── backups/                   ← локальные бэкапы
```

---

## 🔑 ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ (/opt/kote/.env)

```bash
# Supabase
SUPABASE_URL=https://cmmdrhususjuadqzyssc.supabase.co
SUPABASE_ANON_KEY=eyJ...          # публичный ключ (anon role)
SUPABASE_SERVICE_KEY=eyJ...       # ✅ УСТАНОВЛЕН (service_role) — не светить!

# Telegram
TELEGRAM_BOT_TOKEN=...            # @phuket_nestandart_bot от @BotFather
TELEGRAM_ADMIN_CHAT_ID=8943048058
MANAGER_CHAT_ID=8943048058

# AI Providers (каскад, порядок: groq→aitunnel→openrouter→gemini)
AI_PROVIDER_ORDER=groq,aitunnel,openrouter,gemini   # опционально; дефолт такой же
GROQ_API_KEY=...                  # основной (ultra-fast)
AITUNNEL_API_KEY=...              # 2-й
OPENROUTER_API_KEY=...            # 3-й (⏳ требует оплаты)
GEMINI_API_KEY=...                # финальный резерв
GEMINI_MODEL=gemini-2.5-flash     # 2.0-flash упирался в 429-квоту

# n8n
N8N_USER=admin
N8N_PASSWORD=...
KOTE_RPC_SECRET=...               # для webhook авторизации

# Webhooks
WEBHOOK_URL=https://nestandart.online
```

> ⚠️ ANTHROPIC_API_KEY пустой — Claude API не используется в production

---

## 🗄️ БАЗА ДАННЫХ SUPABASE

**Проект:** `cmmdrhususjuadqzyssc` (NON-STANDART)  
**Dashboard:** https://supabase.com/dashboard/project/cmmdrhususjuadqzyssc

### Таблицы

| Таблица | Назначение | Записей (прим.) |
|---------|-----------|-----------------|
| `markets` | Рынки (Пхукет, Паттайя...) | 2 активных |
| `tours` | Каталог туров | 33 (18 Пхукет + 15 Паттайя) |
| `clients` | База клиентов | растёт |
| `bookings` | Брони | растёт |
| `payments` | Платежи (YooKassa) | — |
| `reviews` | Отзывы | — |
| `knowledge` | База знаний КотЭ | 84+ записи |
| `conversations` | История диалогов | растёт |
| `client_memory` | Память о клиентах | растёт |
| `content_plan` | Контент-план | — |
| `action_history` | Лог действий | растёт |
| `partners` | Поставщики | — |

### Ключевые RPC-функции

```sql
-- Создать/обновить клиента и бронь (главная функция)
app_upsert_lead(
  p_external_id, p_source, p_name, p_phone, p_email,
  p_telegram, p_tg_chat_id, p_whatsapp, p_instagram, p_vk,
  p_tour_name, p_tour_slug, p_date_start, p_people,
  p_budget, p_total, p_comment, p_status
) → {client_id, booking_id, is_new_client, is_new_booking}

-- Получить контекст для КотЭ (туры + знания + память клиента)
get_kote_context(p_tg_chat_id, p_query) → context JSON

-- Брони клиента по телефону
get_bookings_by_phone(p_phone) → bookings[]

-- Контекст клиента для AI
app_get_client_context(p_client_id, p_market_id) → memory[]
```

### Архитектура безопасности (RLS)

- **anon** (сайт, бот): читает туры, знания, отзывы. Пишет лиды через `app_upsert_lead`.
- **authenticated** (HQ): полный доступ только через `is_admin()` — email должен совпасть.
- **КотЭ (n8n)**: работает через `SECURITY DEFINER` RPC (не нужен service_key).
- **kote-backend**: использует `service_role` key — полный доступ к данным.

> ⚠️ ВАЖНО: В таблице `markets` нет колонки `slug`! Только `id` (text: 'phuket', 'pattaya').

---

## 🌐 NGINX КОНФИГУРАЦИЯ

### Домены и маршруты

| Домен | SSL | Назначение |
|-------|-----|-----------|
| `nestandart.online` | ✅ Let's Encrypt | Главный сайт + API |
| `www.nestandart.online` | ✅ | → redirect на без www |
| `n8n.nestandart.online` | ✅ Let's Encrypt | n8n редактор |
| `app.nestandart.online` | ✅ (использует cert nestandart.online) | PWA / Mini App |
| `nestandart-phuket.ru` | ✅ | → redirect на nestandart.online/phuket |

### Проксирование

```nginx
/api/leads    → localhost:3055  (Node.js PM2, rate limit: 5r/m)
/api/v1/      → localhost:8000  (FastAPI Docker, rate limit: 20r/m)
/app/         → /var/www/nestandart/platform/app.html
/             → /var/www/nestandart/nestandart-phuket/
```

### Security headers (применены 2026-06-19)
- `Strict-Transport-Security` (HSTS, 1 год)
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: geolocation=(), microphone=(), camera=()`
- Rate limiting: leads 5r/min, API 20r/min
- Блокировка `.env`, `.git`, `.sql`, `.bak` файлов по URI

---

## 🐳 DOCKER

### Команды управления

```bash
cd /opt/kote

# Статус
docker compose ps
docker stats --no-stream

# Логи
docker compose logs -f kote-backend
docker compose logs -f kote-n8n

# Рестарт
docker compose restart kote-backend
docker compose restart kote-n8n

# Полный ребилд бэкенда (после изменений кода!)
docker compose build kote-backend && docker compose up -d --force-recreate kote-backend

# Ребилд без кэша
docker compose build --no-cache kote-backend
```

> ⚠️ ВАЖНО: `--force-recreate` без `build` применит только env-изменения.
> Изменения Python-кода требуют `build` + `--force-recreate`.

### Ресурсы

| Контейнер | RAM limit | RAM факт | CPU |
|-----------|-----------|----------|-----|
| kote-backend | 512 MB | ~43 MB | ~0.2% |
| kote-n8n | 1.5 GB | ~255 MB | ~0.1% |

---

## 🔌 FASTAPI BACKEND (kote-backend)

**Файл:** `app/backend/main.py`  
**URL:** `https://nestandart.online/api/v1/`  
**Docs:** `https://nestandart.online/api/docs`

### Активные эндпоинты

```
GET  /health              → {"status": "ok"}
GET  /api/v1/tours        → список туров [?market_id=phuket&active=true]
GET  /api/v1/markets      → активные рынки
POST /api/v1/lead         → создать/обновить клиента и бронь
GET  /api/v1/bookings     → брони по телефону [?phone=+7...]
```

### Пример запроса лида

```bash
curl -X POST https://nestandart.online/api/v1/lead \
  -H "Content-Type: application/json" \
  -d '{"name":"Иван","phone":"+79001234567","source":"site","tg_chat_id":"123"}'
# → {"ok":true,"data":{"client_id":"...","booking_id":"...","is_new_client":true}}
```

### Роутеры (все подключены в main.py, v2.0.0)

Все 9 роутеров (`ai`, `bookings`, `clients`, `leads`, `markets`, `memory`, `sos`, `tours`, `webhooks`)
импортируются через `include_router`. `routers/ai.py` отдаёт два эндпоинта:
- `POST /api/v1/ai/ask` — backend сам строит system prompt (для PWA/приложения).
- `POST /api/v1/ai/chat` — passthrough в OpenAI-формате (`messages[]` → `choices[0].message.content`),
  его зовёт n8n-бот; промпт собирает n8n, fallback обеспечивает backend.

### AI Fallback Chain (providers/) — порядок через `AI_PROVIDER_ORDER`

```
Запрос → groq (основной, ultra-fast)
         ↓ если упал / нет ключа
         aitunnel
         ↓
         openrouter
         ↓
         gemini (gemini-2.5-flash, финальный резерв)
         ↓ если все упали
         "🐾 Секунду, я немного перегружен..."
```
> Провайдер без своего ключа в env автоматически пропускается. Ключи AI — только в backend, не в kote-n8n.

---

## 🤖 N8N АВТОМАТИЗАЦИИ

**URL:** https://n8n.nestandart.online  
**Данные:** Docker volume `kote-n8n-data`  
**Версия:** 2.25.7

### Активные workflows (4 штуки)

| Workflow | Триггер | Действие |
|----------|---------|----------|
| **КотЭ — AI Агент с памятью** (`doCUKEZQpLQjDmxP`) | Telegram message | 17 нод: извлечь → upsert клиент → контекст → собрать промпт → **backend `/api/v1/ai/chat`** (каскад) → ответ → сохранить |
| **КотЭ — Новые заявки: уведомление** | Webhook | Уведомить менеджера в Telegram |
| **📅 Напоминание о туре за день** | Schedule | Напомнить клиенту о туре |
| **⭐ Запрос отзыва после тура** | Schedule | Попросить оставить отзыв |

### Flows в /opt/kote/n8n/flows/ (документация, не активны)

`booking-flow.json`, `booking-confirm.json`, `daily-report.json`, `lead-intake.json`,
`market-sync.json`, `memory-update.json`, `reminder.json`, `sos.json`

> ⚠️ `daily-report.json` содержит невалидный `$supabase` expression — не импортировать.

### n8n переменные окружения (из .env через override)

```
KOTE_SECRET, N8N_USER, N8N_PASSWORD
N8N_HOST=n8n.nestandart.online, N8N_PROTOCOL=https, N8N_PROXY_HOPS=1
N8N_BLOCK_ENV_ACCESS_IN_NODE=false
```
> С 21.06 AI-ключи (GROQ/GEMINI/…) в kote-n8n больше не нужны — модель-нода зовёт backend `/ai/chat`, ключи держит только backend.

---

## 🐾 КотЭ — ЛИЧНОСТЬ И ЛОГИКА

**Личность:** `platform/kote/prompt.txt`  
**Принцип:** Сначала забота, потом продажа.

### Путь клиента в боте

```
Telegram → n8n trigger
  → извлечь chat_id + текст
  → app_upsert_lead() — зарегистрировать/обновить клиента
  → get_kote_context(chat_id, вопрос) — получить из Supabase:
      • живой каталог туров (отфильтрован под вопрос)
      • знания о Пхукете (84+ записи)
      • память клиента (бюджет, стиль, прошлые туры)
  → backend POST /api/v1/ai/chat → каскад (groq→aitunnel→openrouter→gemini), личность из prompt.txt
  → отправить ответ в Telegram
  → сохранить диалог + обновить память
```

### Что обновить при изменении личности КотЭ

1. Отредактировать `platform/kote/prompt.txt`
2. Обновить workflow в n8n (узел "Собрать промпт" или системный промпт Gemini)
3. **Не трогать** `platform/kote/workflow.json` — это документация, не live-файл

---

## 🔒 БЕЗОПАСНОСТЬ (состояние на 2026-06-19)

### Исправлено сегодня

| Что | Было | Стало |
|-----|------|-------|
| SSH PermitRootLogin | `yes` (пароль) | `prohibit-password` (только ключи) |
| SSH PasswordAuthentication | не задано (разрешён пароль) | `no` (полностью выключен) |
| SSH X11Forwarding | `yes` | `no` |
| SSH MaxAuthTries | 6 | 3 |
| TLS версии (nginx global) | TLS 1.0, 1.1, 1.2, 1.3 | только TLS 1.2, 1.3 |
| server_tokens | on (версия утекала) | `off` |
| Security headers | частичные | полный набор (HSTS, CSP, etc.) |
| Rate limiting | отсутствовал | leads: 5r/m, api: 20r/m |
| .env через HTTP | не заблокировано | 404 по URI-маске |
| app.nestandart.online SSL | сертификат не включал домен | ✅ certbot expand (действует до 2026-09-17) |
| CORS nestandart-api | `Access-Control-Allow-Origin: *` | whitelist 3 домена |
| fail2ban | только sshd | + nginx-scan, nginx-flood, nginx-limit-req |
| fail2ban nginx backend | `systemd` (debian default) — **файлы не мониторились, 0 банов** | `backend = polling` в каждом nginx-jail → реально читает access.log |
| n8n nginx | без security headers, HTTP→404 | headers + 301 redirect |
| API роутеры | мёртвый код (не подключены) | ✅ все 9 роутеров подключены |
| nginx proxy_pass | `localhost` → IPv6 `[::1]` → intermittent 502 | `127.0.0.1` во всех vhost |
| WordPress-сканы (/wp-login, /xmlrpc.php) | отдавались 404 (тратили ресурс) | `return 444` (обрыв соединения) |
| Бэкапы с секретами | dir 755 + файлы 644 (**.env читался всеми**) | dir 700 + файлы 600 + `umask 077` в скриптах |
| `.env.bak`, `*.override.yml.bak`, `.DS_Store` | старые секреты на диске | удалены (shred для .env.bak) |
| Мёртвый код Python | 8 неиспользуемых импортов/переменных | вычищено (pyflakes clean) |

> ⚠️ **fail2ban nginx-jail ВАЖНО**: на Debian/Ubuntu `defaults-debian.conf` ставит
> `backend = systemd` глобально. nginx пишет логи в ФАЙЛЫ, не в journald —
> поэтому без явного `backend = polling` в jail-конфиге fail2ban говорит
> "No file is currently monitored" и **не банит вообще**. Проверка:
> `fail2ban-client get nginx-scan logpath` должен показать access.log.

### Остаток P1 — требует внимания

1. **Порты 54112 и 54114** могут быть открыты при активной VS Code Remote сессии — не production, закрываются сами при выходе.

2. **UptimeRobot** — внешний мониторинг не настроен. `/health` отдаётся только внутри контейнера (nginx наружу не проксирует); для внешнего мониторинга использовать `https://nestandart.online/api/v1/markets` (лёгкий 200-ответ).

### Firewall (UFW)

```
22/tcp   ALLOW  (SSH)
80/tcp   ALLOW  (HTTP → redirect to HTTPS)
443/tcp  ALLOW  (HTTPS)
Всё остальное — DENY
```

---

## 💾 БЭКАПЫ

### Что работает сейчас (cron)

```bash
0  3  * * *  /root/backup-supabase.sh   # JSON-дамп 12 таблиц через REST API
30 3  * * *  /root/backup-vps.sh        # tar.gz конфигов nginx + /opt/kote
*/5 * * * *  /opt/kote/deploy/healthcheck.sh  # мониторинг + авто-рестарт
```

**Хранение:** `/root/backups/supabase/` (14 дней), `/root/backups/vps/` (7 дней)

### Что НЕ работает (нужно настроить)

- `pg_dump` (полный SQL-дамп) — нет `SUPABASE_DB_URL` в env
- Offsite backup — всё на том же VPS (single point of failure)

### Рекомендация

```bash
# Добавить S3/Cloudflare R2 bucket и в .env:
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
S3_BUCKET=nestandart-backups
# deploy/backup-supabase.sh уже поддерживает S3 upload
```

---

## 📊 РЕСУРСЫ VPS (состояние 2026-06-19)

| Метрика | Значение | Норма |
|---------|----------|-------|
| CPU | 8-9% idle, avg 0.22 | ✅ |
| RAM | 2.7 GB / 3.7 GB (73%) | ⚠️ VS Code ест ~1.3 GB |
| Swap | 804 MB / 2 GB (39%) | ⚠️ |
| Disk | 12 GB / 38 GB (33%) | ✅ (-2 GB после аудита) |
| Uptime | 9 дней | ✅ |

> После закрытия VS Code Remote — RAM упадёт до ~1.0 GB (норма).

---

## 🔄 ДЕПЛОЙ

### Изменение Python кода бэкенда

```bash
cd /opt/kote
# 1. Внести изменения в app/backend/
git add . && git commit -m "fix: ..."
# 2. Ребилд образа (обязательно!)
docker compose build kote-backend
# 3. Перезапуск контейнера
docker compose up -d --force-recreate kote-backend
# 4. Проверка
docker logs kote-backend --tail 20
curl https://nestandart.online/api/v1/markets
```

### Изменение env переменных

```bash
nano /opt/kote/.env
docker compose up -d --force-recreate kote-backend
# Для n8n:
docker compose up -d --force-recreate kote-n8n
```

### Изменение nginx

```bash
nano /etc/nginx/sites-available/nestandart.online
nginx -t && systemctl reload nginx
```

### Обновление n8n

```bash
# СНАЧАЛА зафиксировать версию в docker-compose.yml!
# image: n8nio/n8n:НОВАЯ_ВЕРСИЯ
cd /opt/kote
docker compose pull kote-n8n
docker compose up -d --force-recreate kote-n8n
```

---

## 🚀 СЛЕДУЮЩИЕ ШАГИ (приоритет по ROI)

### Критические (делать первыми)

- [ ] **Настроить SUPABASE_DB_URL** → полноценные SQL-бэкапы
- [ ] **Добавить fail2ban nginx jail** → защита от сканирования
- [ ] **Зафиксировать версию n8n** → `2.25.7` вместо `latest`
- [ ] **Offsite backup** (S3/Cloudflare R2) → не хранить бэкапы на том же VPS

### Продуктовые (высокий ROI)

- [ ] **Подключить AI-роутер** (`routers/ai.py` → `main.py`) → КотЭ через API
- [ ] **SOS endpoint** → живая кнопка экстренной помощи в приложении
- [ ] **Webhooks для n8n** → полная автоматизация воронки
- [ ] **Повторные продажи** → n8n flow: напоминание за 2 недели до следующего сезона
- [ ] **Реферальная система** → таблица `referrals` + промокоды
- [ ] **Аналитика** → дашборд в HQ: конверсия по источникам, avg чек по рынку
- [ ] **Паттайя полный запуск** → туры готовы, нужна страница сайта

### Инфраструктурные

- [ ] **Certbot для app.nestandart.online** → сейчас использует wildcard nestandart.online, но нет отдельного сертификата для `app.`
- [ ] **Docker healthcheck для n8n** в override с правильными лимитами
- [ ] **Внешний мониторинг** (UptimeRobot, бесплатно) → знать о падениях раньше клиентов
- [ ] **Rate limit для n8n webhooks** → сейчас нет ограничений

---

## 🩺 БЫСТРАЯ ДИАГНОСТИКА

```bash
# Всё ли живо?
docker ps && curl -s https://nestandart.online/api/v1/markets

# Логи бэкенда
docker logs kote-backend --tail 50 | grep -v "GET /health"

# Логи n8n
docker logs kote-n8n --tail 30

# nginx ошибки
tail -20 /var/log/nginx/error.log

# Ресурсы
docker stats --no-stream && free -h && df -h /

# fail2ban статус
fail2ban-client status sshd

# Бэкапы сегодня
ls /root/backups/supabase/$(date +%F)/
```

---

## ⛔ ЧЕГО НЕ ДЕЛАТЬ

1. **НЕ запускать kote-bot через Docker** (есть в compose с `profiles: [bot]`) — бот живёт в n8n. Два экземпляра конфликтуют.
2. **НЕ менять** `markets.id` — это text ('phuket', 'pattaya'), не UUID. Всё привязано к нему.
3. **НЕ передавать `p_market_id`** в `app_upsert_lead` — такого параметра нет, PostgREST вернёт 404.
4. **НЕ использовать `n8nio/n8n:latest`** при обновлении — только конкретная версия.
5. **НЕ коммитить `.env`** — `.gitignore` защищает, но перепроверяй `git status`.
6. **НЕ делать `docker compose down`** без `up -d` сразу — uptime упадёт.
7. **НЕ импортировать `daily-report.json`** в n8n — невалидный синтаксис.
8. **НЕ включать PermitRootLogin yes** — уже настроен `prohibit-password`, только ключи.

---

## 📞 КОНТАКТЫ И ДОСТУПЫ

| Ресурс | URL / Данные |
|--------|-------------|
| VPS SSH | `ssh root@77.42.93.187` (ключ) |
| Supabase Dashboard | https://supabase.com/dashboard/project/cmmdrhususjuadqzyssc |
| n8n Editor | https://n8n.nestandart.online (admin / из .env) |
| Telegram Bot | @phuket_nestandart_bot |
| Telegram Manager | chat_id: 8943048058 |
| GitHub | github.com/ibetekhtin/kote-system (прод под git; деплой = `git pull` на VPS) |
| Домены | nestandart.online, nestandart-phuket.ru |

---

*CLAUDE.md создан 2026-06-19 в ходе полного аудита системы.*
*Следующий аудит рекомендован через 30 дней или после крупных изменений.*
