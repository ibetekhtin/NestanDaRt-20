# Нестандартный Отдых®

> Ваш маршрут. Ваш темп. Ваши правила.

**Монорепо.** Один бренд. Один код. Одна база. Много рынков.

## Карта системы

```
Nestandart/                         ← github.com/ibetekhtin/NestanDaRt-20
├── nestandart-phuket/   САЙТ        HTML/CSS/JS → VPS (nginx + SSL)
├── baza/                  ШТАБ        React + Vite → baza.nestandart.online
├── app/backend/         BACKEND     FastAPI (ai/bookings/clients/leads/payments/…)
├── providers/           AI-КАСКАД   groq → aitunnel → openrouter → gemini
├── deploy/              VPS-скрипты + nginx-конфиги + healthcheck
├── docs/                ENV.md, API.md, VPS_SETUP.md
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
| 🏝️ Пхукет | ✅ Активен | 68 |
| 🌅 Паттайя | 🟡 Туры готовы, сайт «coming soon» | 53 |
| 🌿 Вьетнам | 🟡 Туры готовы, сайт «coming soon» | 12 |
| 🏖️ Бали | 📋 Planned | — |
| 🏙️ Дубай | 📋 Planned | — |

## Быстрый старт

```bash
# Сайт локально
cd nestandart-phuket && npx serve . -p 3000

# ШТАБ (baza.nestandart.online)
cd hq && npm install && npm run dev

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

- **RLS**: anon читает туры/знания, пишет через `app_upsert_lead`. Клиент — только свои данные.
- **X-Kote-Secret**: защищает `/ai/chat`, `/pay/create`, `/bookings PATCH` — только n8n может вызывать.
- **UFW**: открыты 22, 80, 443. Порты 5678 и 8000 — только через nginx.
- **Секреты**: только в `.env` (gitignore) и n8n credentials.

## Документация

- [Переменные окружения](docs/ENV.md)
- [Настройка VPS](docs/VPS_SETUP.md)
- [API](docs/API.md)
- [MASTER PROMPT](MASTER_PROMPT.md) — стартовый контекст для AI-сессий
