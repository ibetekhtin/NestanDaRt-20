# CLAUDE.md — Нестандартный Отдых + AI КотЭ

## Архитектура

```
User → Bot / Web → AI (КотЭ) → Supabase → n8n → Provider → User
```

## Принципы
- Один код
- Одна база данных (Supabase)
- Один AI (КотЭ)
- Много рынков = данные (market_id)
- Минимум логики в сервисах
- Максимум автоматизации
- Никакой локальной бизнес-логики вне Supabase

## Структура

```
/
├── supabase/
│   └── schema.sql          — 6 таблиц + VIEW booking_details
├── bot/
│   ├── index.js            — Telegram бот (Telegraf)
│   ├── supabase.js         — Supabase клиент (все запросы к БД)
│   └── ai.js               — Gemini AI модуль (КотЭ)
├── ai/
│   └── kote_prompt.txt     — System prompt КотЭ
├── n8n/
│   └── flows/              — 4 workflow JSON
│       ├── lead-intake.json     — Приём лида → уведомление
│       ├── booking-confirm.json — Подтверждение / оплата (единый поток)
│       ├── reminder.json        — Напоминание за 24ч
│       └── sos.json             — Экстренный вызов
├── website/
│   └── index.html          — Фронтенд (Supabase JS)
├── .env.example
├── package.json
├── CLAUDE.md
└── PLAN.md
```

## Supabase (6 таблиц + 1 VIEW)
- `markets` — рынки (масштабирование через market_id)
- `clients` — клиенты (market_id, telegram_id, name, phone)
- `services` — услуги (tour, transfer, rental)
- `bookings` — бронирования (draft → pending → confirmed → completed/cancelled)
- `messages` — лог чата КотЭ
- `payments` — платежи
- `booking_details` — VIEW (bookings + clients + services: telegram_id, service_title)

## n8n flows (4, не 5)
- `lead-intake` — Webhook → Create Client → Notify Manager
- `booking-confirm` — **единый поток**: Webhook → Get Booking → Build Payload → (Save Payment ∥ Update Booking) → Notify Client + Manager
- `reminder` — Cron (18:00) → Code (tomorrow) → Get Upcoming Bookings → Loop → Send Reminder
- `sos` — Webhook → Get Client → Alert Manager + Reply to Client

## Запрещено
- Дополнительные базы данных
- Лишние сервисы
- Усложнение архитектуры
- Бизнес-логика вне Supabase
- Хардкод market_id (включая emoji — теперь берётся из name)
- Мусорные записи в БД (например, `market_id = 'unknown'`)

## Bot
- Использует Telegraf + dotenv
- Не хранит состояние → всё через Supabase
- Команды: /start, /services, /bookings, /help
- AI (КотЭ) через Gemini API
- Без выбранного рынка — просит `/start`, не пишет в БД

## КотЭ
- Модуль `bot/ai.js` (Gemini 1.5 Flash)
- Работает только через Supabase (история чата из `messages`)
- Не выдумывает данные
- Краткие ответы (макс 3 предложения)
- Превращает запрос в booking

## Запуск
```bash
npm install
cp .env.example .env
# Заполни .env (SUPABASE, TELEGRAM, GEMINI)
npm run bot
open website/index.html
```

## Новые рынки
Добавь запись в `markets` + данные в `services`. Никакого кода.
Все flows n8n работают через market_id.

## Переменные окружения (.env)
- `SUPABASE_URL` — URL проекта Supabase
- `SUPABASE_ANON_KEY` — публичный ключ (для website)
- `SUPABASE_SERVICE_KEY` — сервисный ключ (для бота)
- `TELEGRAM_BOT_TOKEN` — токен бота от @BotFather
- `GEMINI_API_KEY` — ключ Gemini от aistudio.google.com
- `MANAGER_CHAT_ID` — Telegram chat ID менеджера для n8n

## Website
- Один статический HTML
- Конфиг через `window.SITE_SUPABASE_URL` / `window.SITE_SUPABASE_ANON_KEY` (можно в `<head>`)
- Fallback: `localStorage` → `prompt` (один раз)
