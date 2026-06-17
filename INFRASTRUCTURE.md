# INFRASTRUCTURE.md — Карта инфраструктуры
# Статус: АУДИТ 17-18 июня 2026

---

## СЕРВЕР VPS (77.42.93.187, Hetzner)

### Nginx
- Конфиг: `/etc/nginx/sites-enabled/nestandart`
- Root сайта: `/var/www/nestandart/nestandart-phuket/`
- SSL: Certbot, Let's Encrypt

**Маршруты:**
```
/                  → nestandart-phuket/index.html
/app               → platform/app.html  (mobile app)
/app/              → platform/ alias
/baza/             → nestandart-phuket/baza/index.html
/tours/*.html      → ❌ 404 (файлы в неправильной папке!)
/api/leads         → proxy 127.0.0.1:3055 (pm2)
/n8n/webhook       → proxy 127.0.0.1:5678 (docker n8n)
```

### pm2
- `nestandart-api` → `/opt/nestandart-api/server.js` (Node.js, порт 3055)
- Принимает лиды с сайта/приложения, пишет в Supabase через `app_upsert_lead`

### Docker (запускается из /opt/kote/docker-compose.yml)
- `kote-backend` → `/opt/kote/app/backend/` (FastAPI, uvicorn, порт 8000)
- `kote-n8n` → n8n (порт 5678, используется nginx для webhook)

---

## ДВЕ КОДОВЫЕ БАЗЫ НА СЕРВЕРЕ (ГЛАВНАЯ ПРОБЛЕМА)

### /var/www/nestandart/ — GIT РЕПО (ТЕКУЩИЙ)
Git clone из ibetekhtin/nestandart-20. Сюда идут все git push.
```
nestandart/
├── nestandart-phuket/    ← сайт (nginx обслуживает отсюда)
│   ├── index.html
│   ├── blog/ (10 статей)
│   ├── css/
│   ├── js/app.js
│   ├── baza/ (собранный HQ)
│   └── tours/mototour.html  ← ТОЛЬКО ОДИН ТУР!
├── tours/ (26 файлов)        ← НЕ ОБСЛУЖИВАЕТСЯ NGINX!
├── platform/
│   ├── app.html              ← mobile app (nginx /app)
│   ├── app.html.bak_v9       ← мусор, удалить
│   ├── app/index.html        ← дубль app, не обслуживается
│   ├── bot/ (Python, неполный)
│   ├── kote/prompt.txt + workflow.json
│   └── supabase/schema.sql
├── hq/ (исходники React)
├── shared/ (brand.js, markets.js)
├── app/backend/ (СТАБ! Нет роутеров)
└── docker-compose.yml (НЕ используется для запуска Docker!)
```

### /opt/kote/ — СТАРАЯ БАЗА (ДО МИГРАЦИИ)
Старый клон проекта. Docker контейнеры запускаются ОТСЮДА.
```
kote/
├── index.html              ← дубль сайта (не обслуживается)
├── website/index.html      ← ещё один дубль (не обслуживается)
├── blog/ (10 статей)       ← дубль (не обслуживается)
├── css/                    ← дубль (не обслуживается)
├── js/app.js               ← дубль (не обслуживается)
├── tours/mototour.html     ← дубль (не обслуживается)
├── ai/kote_prompt.txt      ← дубль prompt.txt
├── bot/                    ← ПОЛНЫЙ бот (JS + Python), не запущен
│   ├── index.js (Node.js)
│   ├── ai.js
│   ├── supabase.js
│   ├── memory.js
│   ├── error_handler.js
│   ├── logger.js
│   ├── main.py (Python)
│   ├── tools_knowledge.py
│   └── admin_notify.py
├── app/backend/            ← ПОЛНЫЙ бэкенд с роутерами! (Docker)
│   ├── main.py
│   ├── config.py
│   └── routers/ (ai, bookings, clients, leads, markets, memory, sos, webhooks)
├── n8n/flows/ (8 workflow JSON)
├── deploy/ (скрипты деплоя, nginx.conf, systemd)
├── supabase/ (schema.sql + migrations/)
├── docker-compose.yml      ← ЭТОТ запускает Docker контейнеры
└── docs/ (7 документов)
```

### /opt/nestandart-api/ — LEADS API (ОТДЕЛЬНО)
```
nestandart-api/
├── server.js   ← pm2 запускает это
└── .env
```

---

## ЛОКАЛЬНЫЙ ПРОЕКТ (Desktop/папка с проектом)

Это ТОЖЕ git репо, который пушит в /var/www/nestandart/ через GitHub.
Имеет ТУ ЖЕ проблему — смешаны старая и новая структура:

```
папка с проектом/
├── index.html          ← СТАРЫЙ сайт (не в nestandart-phuket/)
├── css/, js/, blog/    ← СТАРАЯ структура (дубли)
├── ai/kote_prompt.txt  ← дубль
├── bot/                ← СМЕШАННЫЙ (JS + Python)
├── nestandart-phuket/  ← НОВАЯ структура сайта
├── platform/           ← НОВАЯ структура платформы
├── hq/                 ← HQ панель
├── shared/             ← бренд и рынки
├── app/backend/        ← СТАБ бэкенда
├── supabase/           ← ещё одна копия схемы
├── n8n/flows/          ← 8 flows (старые?)
├── tours/              ← 1 файл (mototour.html)
├── website/            ← ещё одна копия index.html
└── generate_tours.py   ← генератор туров (122KB!)
```

---

## КАРТА ДУБЛЕЙ

| Файл/Директория | Актив? | Дубли на сервере | Дубли локально |
|-----------------|--------|------------------|----------------|
| index.html (сайт) | /var/www/.../nestandart-phuket/ | /opt/kote/index.html, /opt/kote/website/ | корневой + nestandart-phuket/ + website/ |
| blog/*.html | /var/www/.../nestandart-phuket/blog/ | /opt/kote/blog/ | корневой + nestandart-phuket/ |
| css/style.css | /var/www/.../nestandart-phuket/css/ | /opt/kote/css/ | корневой + nestandart-phuket/ |
| js/app.js | /var/www/.../nestandart-phuket/js/ | /opt/kote/js/ | корневой + nestandart-phuket/ |
| tours/*.html | ❌ НЕТ | /var/www/nestandart/tours/ (не сервится!), /opt/kote/tours/ | корневой |
| bot/main.py | Нигде | /var/www/.../platform/bot/ + /opt/kote/bot/ | корневой bot/ + platform/bot/ |
| kote/prompt.txt | /var/www/.../platform/kote/ | /opt/kote/ai/kote_prompt.txt | ai/ + platform/kote/ |
| supabase/schema.sql | Supabase (prod) | /var/www/.../platform/supabase/ + /opt/kote/supabase/ + migrations | корневой + platform/ |
| app/backend/ | /opt/kote/app/backend/ (Docker) | /var/www/nestandart/app/backend/ (стаб) | app/backend/ (стаб) |
| docker-compose.yml | /opt/kote/ | /var/www/nestandart/ (не используется) | корневой |
| n8n flows | n8n Cloud | /opt/kote/n8n/flows/ | n8n/flows/ |
| platform/app.html | /var/www/.../platform/ | app.html.bak_v9 + app/index.html | platform/ |

---

## КРИТИЧЕСКИЙ БАГ — ТУРЫ 404

**Проблема:** `generate_tours.py` создаёт 26 HTML файлов туров. Они попадают в:
- `/var/www/nestandart/tours/` (корень git репо)

Но nginx обслуживает из:
- `/var/www/nestandart/nestandart-phuket/` (корень сайта)

Поэтому `https://nestandart-phuket.ru/tours/phiphi_bamboo.html` → **404**

Только `/tours/mototour.html` работает потому что он есть в `nestandart-phuket/tours/`.

**Решение:** generate_tours.py должен генерировать в `nestandart-phuket/tours/`, не в корень.
