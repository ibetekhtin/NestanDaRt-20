# CLAUDE.md — Нестандартный Отдых + AI КотЭ
# Репозиторий: github.com/ibetekhtin/kote-system | Обновлено: 18.06.2026

## Архитектура

```
Трафик (Telegram, соцсети, сайт)
         │
    ┌────┴─────────────────────────────┐
    ▼                                  ▼
  САЙТ nestandart.online           БОТ @phuket_nestandart_bot
  nginx → /var/www/nestandart       n8n Cloud workflow
  PWA → nestandart.online/app/      (ibetekhtin.app.n8n.cloud)
         │                                    │
    ┌────┴────────────────────────────────────┘
    ▼
 /api/leads (VPS 77.42.93.187, Node.js, pm2, порт 3055)
 → RPC app_upsert_lead (антидубль, идемпотентность)
    │
    ▼
SUPABASE cmmdrhususjuadqzyssc — единственный источник данных
    │
    ├── 13 таблиц (schema.sql + migrations 002–005)
    ├── Ключевые RPC: app_upsert_lead · get_kote_context · search_knowledge
    │   bot_upsert_client · upsert_client_memory · update_client_stage
    │   get_new_leads · get_tour_reminders · get_review_requests
    └── Воронка: new → interest → thinking → booking → done
    │
    └── n8n Cloud → уведомления, память, стадии воронки
```

## Принципы
- Один код · Одна база данных · Один AI (КотЭ) · Много рынков = данные (market_id)
- Новый рынок = запись в `markets`, никакого нового кода
- Вся бизнес-логика в Supabase (RPC, триггеры, RLS)
- Секреты только в `.env`, никогда в коде или git

## Структура репозитория

```
/
├── platform/
│   ├── app.html              — PWA (nestandart.online/app/); заказы через app_upsert_lead RPC
│   ├── bot/                  — Python бот (aiogram 3 + Gemini 2.0 Flash)
│   │   ├── index.py          — точка входа, aiogram handlers
│   │   ├── supabase_client.py — все RPC-вызовы к Supabase
│   │   ├── tools_knowledge.py — поиск по базе знаний
│   │   ├── admin_notify.py   — уведомления менеджеру
│   │   └── .env.example      — шаблон переменных (без значений)
│   └── CLAUDE.md             — ценности и принципы продукта
├── app/
│   └── backend/              — FastAPI REST API (kote-backend Docker, порт 8000)
│       ├── main.py
│       ├── requirements.txt
│       └── Dockerfile
├── supabase/
│   ├── schema.sql            — базовая схема (markets, clients, bookings, payments, conversations)
│   └── migrations/
│       ├── 002_full_schema.sql   — leads, ai_interactions, client_memory, reviews, partners, action_history, tours
│       ├── 003_knowledge_table.sql — knowledge
│       ├── 004_automation_rpc_functions.sql — RPC для n8n (get_new_leads, get_tour_reminders, get_review_requests)
│       └── 005_performance_and_security.sql — индексы (14 шт., валидные)
├── hq/                       — React admin panel (внутренний дашборд)
│   └── src/
├── deploy/
│   └── monitoring.sh         — uptime/SSL проверки nestandart.online
├── .github/
│   └── workflows/ci-cd.yml   — lint + secret scan + docker build + VPS deploy
├── docker-compose.yml        — kote-backend + kote-n8n контейнеры
└── CLAUDE.md                 — этот файл
```

## Supabase (13 таблиц)

| Таблица | Описание |
|---------|----------|
| `markets` | Рынки (Phuket, Pattaya, Bali, Dubai…) |
| `clients` | Клиенты (tg_chat_id, name, phone, stage) |
| `bookings` | Брони (client_id → tour_name, date_start, status) |
| `payments` | Платежи (ЮKassa; триггер: succeeded → booking «Оплачено») |
| `conversations` | Лог чата КотЭ (client_id, message, response, source) |
| `tours` | Каталог туров (45 активных: 18 Phuket + 15 Pattaya + …) |
| `knowledge` | База знаний КотЭ (110+ активных статей) |
| `leads` | Лиды (до создания клиента) |
| `ai_interactions` | Полный лог AI-запросов (аналитика) |
| `client_memory` | Долгосрочная память клиента (предпочтения) |
| `reviews` | Отзывы (пока пусто; триггер готов) |
| `partners` | Партнёры и поставщики |
| `action_history` | Аудит-лог всех событий системы |

**Ключевые RPC:**
- `app_upsert_lead(p_source, p_name, p_phone, p_tg_chat_id, p_tour_name, p_total, …)` — единая точка записи лида (сайт + бот); доступна anon
- `get_kote_context(p_tg_chat_id, p_query, p_secret)` — полный AI-контекст; только service_role
- `bot_upsert_client(p_tg_chat_id, p_name, p_source, p_secret)` — создание/обновление клиента ботом; secret-gate SHA256
- `search_knowledge(p_query)` — полнотекстовый поиск по базе знаний
- `get_new_leads`, `get_tour_reminders`, `get_review_requests` — для n8n автоматизаций; secret-gate SHA256

**Безопасность:**
- RLS включён на всех таблицах
- Серверные функции (get_kote_context, bot_upsert_client и др.) проверяют SHA256(KOTE_SECRET)
- app_upsert_lead доступна anon (публичная точка входа)
- anon НЕ может читать bookings/clients/payments/conversations

## n8n Автоматизации (n8n Cloud: ibetekhtin.app.n8n.cloud)

| Workflow | ID | Описание |
|---------|----|----------|
| КотЭ — AI Агент с памятью | doCUKEZQpLQjDmxP | Мозг бота: Telegram → Supabase → Gemini → ответ |
| Новые заявки | XECLexozFgkUIAhK | Новый лид → уведомление менеджеру |
| Напоминание о туре | bNug746DsWnNjPTB | За день до тура → сообщение клиенту |
| Запрос отзыва | YYYT5rNUL9SP3w2V | На следующий день после тура → просьба отзыва |

**Важно:** все workflows используют `$vars.GEMINI_API_KEY` (не `$env.*` — заблокировано n8n Cloud).
Supabase-вызовы используют hardcoded public anon key в заголовках + `p_secret` в теле для PII-функций.

## Переменные окружения

### platform/bot/.env
```
TELEGRAM_BOT_TOKEN=    # токен бота
GEMINI_API_KEY=        # AIza… от aistudio.google.com
SUPABASE_URL=https://cmmdrhususjuadqzyssc.supabase.co
SUPABASE_SERVICE_KEY=  # service_role ключ
KOTE_SECRET=           # секрет для SHA256 gate
TELEGRAM_ADMIN_CHAT_ID= # для уведомлений менеджеру
```

### n8n Cloud Variables
```
GEMINI_API_KEY=    # AIza… (не OAuth токен!)
```

## Инфраструктура VPS (77.42.93.187)

- **nginx** — nestandart.online (HTTPS), /app/ → PWA, /api/* → pm2
- **pm2: nestandart-api** — `/opt/nestandart-api/server.js` (порт 3055) — `/api/leads`
- **Docker: kote-backend** — `/opt/kote/app/backend/` (FastAPI, порт 8000) — `/api/v1/`
- **Docker: kote-n8n** — локальный n8n (порт 5678; бот НЕ использует его — бот в n8n Cloud)
- **git checkout** — `/var/www/nestandart` (origin = kote-system; VPS пуллит оттуда)
- **Бэкапы** — cron 3:00 (Supabase JSON) + 3:30 (nginx/configs tarball), 7–14 дней

## Запрещено

- Создавать вторую базу данных или второй каталог туров
- Писать напрямую в `clients`/`bookings` минуя `app_upsert_lead`
- Хранить токены и ключи в коде или git
- Делать рынок-специфичный код (только `market_id` в данных)
- Использовать anon ключ для серверных операций (только service_role)
- Запускать несколько экземпляров бота одновременно (webhook конфликт)
- Notion как CRM (мигрировали в Supabase)

## Новые рынки

Добавь запись в `markets` + данные в `tours`. Никакого нового кода.
Все n8n workflows работают через `market_id`.
