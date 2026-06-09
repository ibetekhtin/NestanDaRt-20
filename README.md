# 🐾 Нестандартный Отдых / KOTЭ SYSTEM

> **Telegram-бот КотЭ + AI + Supabase + n8n** — единая платформа для управления отдыхом на нескольких рынках (Пхукет, Паттайя, Бали, Дубай).

---

## 🏗️ Архитектура

```
┌──────────┐   ┌──────────┐   ┌──────────┐
│ Telegram │   │ Website  │   │  Mobile  │  ← Клиенты
│   Bot    │   │   (Web)  │   │  (App)   │
└────┬─────┘   └────┬─────┘   └────┬─────┘
     │              │              │
     └──────────────┼──────────────┘
                    ▼
            ┌──────────────┐
            │   AI КотЭ    │  ← Gemini 2.0 Flash
            │ (Gemini API) │
            └──────┬───────┘
                   ▼
            ┌──────────────┐
            │   Supabase   │  ← Single Source of Truth
            │  (Postgres)  │
            └──────┬───────┘
                   ▼
            ┌──────────────┐
            │     n8n      │  ← Автоматизация
            │  Workflows   │
            └──────┬───────┘
                   ▼
         ┌─────────┴─────────┐
         ▼                   ▼
   ┌──────────┐        ┌──────────┐
   │ Provider │        │ Telegram │
   │  (Отель) │        │ Manager  │
   └──────────┘        └──────────┘
```

**Принципы:**
- 🎯 **Один код, одна БД, один AI** — никаких дублирований
- 🌍 **Много рынков = данные (market_id)** — новый рынок = новая строка в `markets`
- 🚫 **Минимум логики в сервисах** — максимум автоматизации
- 💾 **Бот не хранит состояние** — всё через Supabase

---

## 🚀 Quickstart (5 минут)

### 1. Клонируй и настрой окружение

```bash
git clone <repo>
cd "папка с проектом"
npm install
cp .env.example .env
```

Заполни `.env`:
```env
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=eyJ...              # service_role key
SUPABASE_ANON_KEY=eyJ...                # anon key
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...    # от @BotFather
GEMINI_API_KEY=AIza...                  # от aistudio.google.com
MANAGER_CHAT_ID=123456789               # твой Telegram ID
```

### 2. Создай Supabase проект и примени схему

1. Зайди на [supabase.com](https://supabase.com) → New Project
2. SQL Editor → New Query
3. Скопируй `supabase/schema.sql` → Run
4. Скопируй `supabase/migrations/002_full_schema.sql` → Run
5. Скопируй `supabase/seed/seed_demo.sql` → Run (опционально, demo-данные)

### 3. Запусти бота

```bash
npm run bot
```

Открой Telegram → найди бота → `/start` → выбери рынок → пользуйся!

### 4. (Опционально) Запусти backend API

```bash
cd app/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Открой [http://localhost:8000/docs](http://localhost:8000/docs) — Swagger UI.

### 5. (Опционально) Импортируй n8n flows

1. Запусти n8n (self-hosted или cloud)
2. Workflows → Import from File → выбери JSON из `n8n/flows/`
3. Настрой credentials (Supabase, Telegram)
4. Активируй

---

## 📁 Структура проекта

```
.
├── bot/                    # Telegram bot (Node.js + Telegraf)
├── bot_py/                 # Telegram bot (Python + aiogram 3.x) — альтернатива
├── app/backend/            # FastAPI backend API
├── mobile/                 # Mobile app skeleton (Expo + TypeScript)
├── supabase/               # SQL: schema, migrations, seed
├── n8n/flows/              # 8 workflow JSON
├── ai/                     # AI prompts (КотЭ)
├── website/                # Static HTML + Supabase JS
├── deploy/                 # VPS deployment scripts
├── docs/                   # Полная документация
├── docker-compose.yml      # Bot + Backend + n8n
└── Makefile                # Команды для dev/deploy
```

Подробности: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

---

## 🛠️ Команды

| Команда | Описание |
|---|---|
| `npm run bot` | Запустить Telegram бота (Node.js) |
| `npm run dev` | Открыть website в браузере |
| `npm run backend` | Запустить FastAPI (Python) |
| `make up` | Запустить все сервисы (Docker) |
| `make logs` | Логи всех контейнеров |
| `make deploy` | Деплой на VPS |
| `make validate` | Валидация всего кода |

---

## 🌍 Новый рынок за 2 минуты

```sql
INSERT INTO markets (id, name, currency, timezone, active) VALUES
  ('phuket', '🏖 Пхукет', 'THB', 'Asia/Bangkok', true);
```

Добавь `services` с `market_id='phuket'` — **всё, никакого кода**.

---

## 📚 Документация

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — полная архитектура
- [SUPABASE.md](docs/SUPABASE.md) — схема, миграции, RPC, RLS
- [N8N.md](docs/N8N.md) — все 8 workflows
- [API.md](docs/API.md) — FastAPI endpoints
- [DEPLOY.md](docs/DEPLOY.md) — VPS, Docker, Hetzner
- [AUDIT.md](docs/AUDIT.md) — отчёт аудита
- [AUTONOMY_TEST.md](docs/AUTONOMY_TEST.md) — симуляция сценариев
- [ENV.md](docs/ENV.md) — все переменные окружения

---

## 🤝 Contributing

Pull requests приветствуются. Для крупных изменений — сначала открой issue.

---

## 📄 License

MIT — см. [LICENSE](LICENSE)
