# Нестандартный Отдых®

> Ваш маршрут. Ваш темп. Ваши правила.

**Монорепо.** Один бренд. Один код. Одна база. Много рынков.

## Карта системы

```
Nestandart/                         ← github.com/ibetekhtin/NestanDaRt-20
├── nestandart-phuket/   САЙТ        HTML/CSS/JS → nestandart.online
├── platform/            PWA         «Нестандарт» → app.nestandart.online
├── baza/                ШТАБ        React + Vite → baza.nestandart.online
├── app/backend/         BACKEND     FastAPI (ai/bookings/clients/leads/payments/…)
├── providers/           AI-КАСКАД   groq → aitunnel → openrouter → gemini
├── n8n/live/            БОТ КотЭ    актуальные экспорты живых воркфлоу (без секретов)
├── deploy/              VPS-скрипты + nginx-конфиги + healthcheck
├── docs/                VISION, ENV, API, VPS_SETUP, ROADMAP, …
└── docker-compose.yml · CLAUDE.md · MASTER_PROMPT.md
```

## Где что живёт (источники истины)

| Что | Где | Как менять |
|-----|-----|-----------|
| Туры, цены, сезоны | Supabase → `tours` | SQL / HQ-панель. КотЭ подхватит сам |
| База знаний (84+ записи) | Supabase → `knowledge` | SQL. КотЭ ищет по вопросу клиента |
| Клиенты, заявки, платежи | Supabase → `clients`, `bookings`, `payments` | через HQ или бота |
| Контент сайта | `nestandart-phuket/*.html` | правка + git push |
| Конфиг сайта | `nestandart-phuket/js/config.js` | правка + push |

**Supabase проект:** `cmmdrhususjuadqzyssc`

## Архитектура КотЭ

```
Telegram → n8n (workflow doCUKEZQpLQjDmxP) → get_kote_context(chat_id, вопрос) → Supabase
                       ↓ один запрос отдаёт всё:
              память клиента + живой каталог туров + знания под вопрос
                       ↓
        backend /api/v1/ai/chat → AI-каскад (groq → aitunnel → openrouter → gemini)
                     ответ клиенту
```

Новый тур или факт = insert в базу. Воркфлоу не трогается.

## Рынки

| Рынок | Статус | Туры |
|-------|--------|------|
| 🏝️ Пхукет | ✅ Активен (единственный фокус сейчас) | 68 |
| 🌅 Паттайя | 📦 Архив (туры в БД, лендинг в archive/) | 53 |
| 🌿 Вьетнам | 📦 Архив (туры в БД, лендинг в archive/) | 12 |
| 🌍 Весь мир | 🎯 Цель платформы (см. docs/VISION.md) | — |

## Быстрый старт

```bash
# Сайт локально
cd nestandart-phuket && npx serve . -p 3000

# ШТАБ (baza.nestandart.online)
cd baza && npm install && npm run dev

# Backend
cd app/backend && pip install -r requirements.txt && uvicorn main:app --reload

# n8n: ssh -L 5678:localhost:5678 root@77.42.93.187 → http://localhost:5678
```

## Деплой

```bash
# Синхронизировать VPS:
ssh root@77.42.93.187 "cd /opt/nestandart && git pull && \
  docker compose build kote-backend && docker compose up -d"

# Проверить:
curl -s https://nestandart.online/api/v1/markets
```

## Безопасность

- **RLS**: anon только читает витрину (туры/наборы/знания). Запись — исключительно через сервер.
- **RPC**: все 21+ бизнес-функции (`app_upsert_lead`, `app_mark_paid`, `get_kote_context`, …) закрыты от `anon`/`authenticated` — исполняет только `service_role` (backend и n8n). Внутри каждой — второй рубеж: sha256-гейт `KOTE_SECRET`.
- **X-Kote-Secret**: защищает приватные эндпоинты бэкенда (`/ai/chat`, `/pay/create`, `/bookings PATCH`, …).
- **Ключи**: backend и n8n ходят в Supabase под `SUPABASE_SERVICE_KEY`; в JSON воркфлоу ключа нет — ноды ссылаются на `{{ $env.SUPABASE_SERVICE_KEY }}`.
- **UFW**: открыты 22, 80, 443. Порты 5678 и 8000 — только через nginx (127.0.0.1).
- **Секреты**: только в `.env` (gitignore) и n8n credentials.

## Документация

- [Карта видения](docs/VISION.md) — миссия, продукт, этапы
- [Переменные окружения](docs/ENV.md)
- [Настройка VPS](docs/VPS_SETUP.md)
- [API](docs/API.md)
- [MASTER PROMPT](MASTER_PROMPT.md) — стартовый контекст для AI-сессий
