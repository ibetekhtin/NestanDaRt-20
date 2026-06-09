# 🐾 KOTЭ SYSTEM — Полная информация по проекту

## 🔗 Ссылки

| Ресурс | URL |
|--------|-----|
| **Repository** | `github.com/<YOUR_GITHUB>/kote-system` *(настроить remote)* |
| **Supabase Dashboard** | `supabase.com/dashboard` → проект asurrubnbvetkvnskcdu |
| **n8n (self-hosted)** | `http://<VPS_IP>:5678` |
| **Backend API** | `http://<VPS_IP>:8000/docs` (Swagger) |
| **Bot** | `@phuket_nestandart_bot` в Telegram |
| **Website** | `website/index.html` |

---

## 🎯 Миссия

**Автоматизировать и масштабировать отдых на несколько рынков с помощью AI-помощника КотЭ.**

Не продавать туры — а **сопровождать человека** от первого вопроса до бронирования и отзыва. Один бот, один AI, одна база данных, бесконечные рынки.

---

## 💡 Философия

```
1. Один код — одна кодовая база, никаких форков
2. Одна БД — Supabase как Single Source of Truth
3. Один AI — КотЭ на Gemini 2.0 Flash
4. Много рынков — данные через market_id, не код
5. Минимум логики в сервисах — максимум в Supabase (RPC, триггеры)
6. Безопасность — RLS, service_role ключ, .env в .gitignore
```

**Запрещено:**
- Дополнительные базы данных
- Хардкод market_id
- Бизнес-логика вне Supabase
- Усложнение архитектуры

---

## 🏗️ Архитектура

```
┌──────────┐   ┌──────────┐   ┌──────────┐
│ Telegram │   │ Website  │   │  Mobile  │
│   Bot    │   │   (Web)  │   │  (App)   │
└────┬─────┘   └────┬─────┘   └────┬─────┘
     └──────────────┼──────────────┘
                    ▼
            ┌──────────────┐
            │   AI КотЭ    │
            │ (Gemini API) │
            └──────┬───────┘
                   ▼
            ┌──────────────┐
            │   Supabase   │
            │  (Postgres)  │
            └──────┬───────┘
                   ▼
            ┌──────────────┐
            │     n8n      │
            └──────┬───────┘
                   │
              ┌────┴────┐
              ▼         ▼
        ┌────────┐ ┌────────┐
        │Provider│ │Manager │
        └────────┘ └────────┘
```

---

## 📊 Стек технологий

| Слой | Технология | Версия |
|------|-----------|--------|
| Bot | Node.js + Telegraf | 20.x / 4.16 |
| Backend | Python + FastAPI | 3.12 / 0.115 |
| AI | Google Gemini | 2.0 Flash |
| Database | Supabase (PostgreSQL) | 15+ |
| Automation | n8n | latest |
| Mobile | Expo + TypeScript | SDK 52 |
| Deploy | Docker Compose | 2.x |
| VPS | Hetzner | CPX21 |

---

## 📁 Структура проекта

```
kote-system/
├── bot/                    # Telegram bot (Node.js + Telegraf)
│   ├── index.js            # Main bot logic
│   ├── ai.js               # Gemini AI integration
│   ├── supabase.js         # Supabase client
│   ├── logger.js           # JSON logger
│   ├── error_handler.js    # Global error handler
│   ├── memory.js           # Client memory system
│   └── Dockerfile
├── app/backend/            # FastAPI Backend API
│   ├── main.py             # FastAPI app
│   ├── config.py           # Pydantic settings
│   ├── routers/            # 8 routers (markets, leads, bookings, clients, ai, sos, memory, webhooks)
│   ├── requirements.txt
│   └── Dockerfile
├── supabase/               # SQL
│   ├── schema.sql          # Base schema (6 tables)
│   └── migrations/002_full_schema.sql  # Extended (7 tables + RLS + RPC)
├── n8n/flows/              # 8 automation workflows
├── ai/                     # AI prompts
├── website/                # Static HTML catalog
├── mobile/                 # Expo skeleton
├── deploy/                 # VPS deployment scripts
├── docs/                   # Full documentation (9 files)
├── docker-compose.yml      # 3 services
├── Makefile                # Dev commands
└── README.md
```

---

## 📊 База данных (Supabase)

### Таблицы (13)

| Таблица | Назначение |
|---------|-----------|
| `markets` | Рынки (phuket, pattaya, bali, dubai) |
| `clients` | Клиенты (telegram_id, name, phone) |
| `services` | Услуги (tour, transfer, rental) |
| `bookings` | Бронирования (draft→pending→confirmed→completed/cancelled) |
| `messages` | Лог чата с КотЭ |
| `payments` | Платежи |
| `leads` | Лиды (new→contacted→qualified→converted/lost) |
| `ai_interactions` | Полный лог AI (intent, latency, tokens) |
| `client_memory` | Память клиента (key-value, importance 1-10) |
| `reviews` | Отзывы (1-5 звёзд) |
| `partners` | Поставщики (отели, гиды, трансфер) |
| `action_history` | Audit log (авто-триггеры) |
| `tours` | Расширенная информация о турах |

### Views (3)
- `booking_details` — JOIN bookings + clients + services
- `v_booking_full` — расширенный JOIN с markets
- `v_lead_stats` — аналитика лидов

### RPC Functions (6)
- `app_upsert_lead` — upsert лида
- `app_create_booking` — создание брони + клиента + лида
- `app_update_memory` — upsert памяти
- `app_get_client_context` — контекст для AI
- `app_get_market_stats` — статистика рынка
- `app_log_action` — ручной audit log

### Triggers (3)
- `log_action()` — авто-лог в action_history (bookings, leads, payments)
- `touch_updated_at()` — авто-обновление updated_at

---

## 🔄 n8n Workflows (8)

| # | Flow | Trigger | Назначение |
|---|------|---------|-----------|
| 1 | lead-intake | Webhook | Создание лида → уведомление |
| 2 | booking-confirm | Webhook | Подтверждение + платёж + уведомления |
| 3 | booking-flow | Webhook | Полный lifecycle (confirm/cancel/complete) |
| 4 | reminder | Cron 18:00 | Напоминание за 24ч |
| 5 | sos | Webhook | Экстренный вызов |
| 6 | memory-update | Webhook | Обновление памяти |
| 7 | daily-report | Cron 09:00 | Ежедневная статистика |
| 8 | market-sync | Webhook | Активация/деактивация рынков |

---

## 🌍 Мультирыночная архитектура

**Новый рынок за 2 минуты:**

```sql
INSERT INTO markets (id, name, currency, timezone) VALUES
  ('phuket', '🏖 Пхукет', 'THB', 'Asia/Bangkok');

INSERT INTO services (market_id, type, title, price, currency) VALUES
  ('phuket', 'tour', 'Тур на Пхи-Пхи', 2500, 'THB');
```

Никакого кода. Никаких изменений в конфигах.

**Текущие рынки:** Пхукет 🏖, Паттайя 🏖, Бали 🌴, Дубай 🏙

---

## 🚀 Roadmap (2026-2030)

### 2026 H2 (июнь-декабрь) — BASE 🚀
- [x] Telegram bot v2.0 (Telegraf + Gemini)
- [x] Supabase schema v2.0 (13 таблиц + RLS + RPC)
- [x] FastAPI backend (14 endpoints)
- [x] n8n workflows (8 flow)
- [x] Docker Compose + Dockerfiles
- [x] VPS deployment scripts (Hetzner)
- [x] Полная документация (9 файлов)
- [x] Аудит + автономный тест
- [x] **Запуск Hetzner VPS (9 июня 2026!)** 🚀
- [ ] Настройка n8n credentials + webhook URLs (июнь)
- [ ] Первые 50 клиентов (июль)
- [ ] Онлайн-оплата — Stripe / 2C2P (октябрь)
- [ ] AI-рекомендации на основе client_memory (ноябрь)
- [ ] Аналитический дашборд — Metabase (декабрь)
- **Цель:** $500 MRR, 50 клиентов/мес, 4 рынка

### 2027 H1 (январь-июнь) — GROWTH 📈
- [ ] Мобильное приложение — React Native / Expo (январь)
- [ ] Расширение на 3 рынка — Ко Чанг, Краби, Хо Ши Minh (февраль)
- [ ] Партнёрская программа — commission 10-15% (март)
- [ ] Автоматические invoice/receipt PDF (март)
- [ ] Multi-language — EN, RU, TH (апрель)
- [ ] WhatsApp Business интеграция (май)
- [ ] AI-звонки — Vapi / Bland AI (июнь)
- [ ] CRM-дашборд для менеджеров (июнь)
- **Цель:** $3K MRR, 300 клиентов/мес, 7 рынков, 15 партнёров

### 2027 H2 (июль-декабрь) — SCALE 🏗️
- [ ] White-label решение для партнёров (июль)
- [ ] A/B тестирование AI промптов (август)
- [ ] Automated content — Instagram Reels + Telegram канал (сентябрь)
- [ ] Open API для партнёров (октябрь)
- [ ] AI-аналитика — предиктивный анализ спроса (ноябрь)
- [ ] Loyalty программа — баллы за бронирования (декабрь)
- [ ] Мультирыночная аналитика — сравнение рынков (декабрь)
- **Цель:** $10K MRR, 1000 клиентов/мес, 10 рынков, 50 партнёров

### 2028 H1 (январь-июнь) — EMPIRE 🌏
- [ ] Экспансия в Европу — Хорватия, Греция, Турция (январь)
- [ ] AI-консьерж 24/7 — голосовые звонки на 3 языках (февраль)
- [ ] B2B портал для отелей — Self-service (март)
- [ ] Dynamic pricing — AI оптимизация цен в реальном времени (апрель)
- [ ] Blockchain-верификация отзывов (май)
- [ ] Партнёрская сеть 100+ отелей (июнь)
- **Цель:** $30K MRR, 3000 клиентов/мес, 20 рынков, 200 партнёров

### 2028 H2 (июль-декабрь) — DOMINATION 💎
- [ ] Франшиза КотЭ — лицензирование (июль)
- [ ] AI-генерация маршрутов — персональные планы (август)
- [ ] VR-туры — предпросмотр отелей (сентябрь)
- [ ] Корпоративный сегмент — B2B бронирования (октябрь)
- [ ] Insurance integration — страховки для путешественников (ноябрь)
- [ ] Консьерж-сервис для VIP-клиентов (декабрь)
- **Цель:** $80K MRR, 8000 клиентов/мес, 30 рынков, 500 партнёров

### 2029 H1 (январь-июнь) — WORLD TOUR 🌍
- [ ] Экспансия в Азию — Япония, Южная Корея, Вьетнам (январь)
- [ ] Экспансия в Америку — Мексика, Коста-Рика, Доминикана (февраль)
- [ ] AI-планировщик отпусков — автоматический подбор (март)
- [ ] Subscription model — $9.99/мес за премиум (апрель)
- [ ] Marketplace — агрегатор услуг (май)
- [ ] Выход на IPO-ready stage (июнь)
- **Цель:** $200K MRR, 20000 клиентов/мес, 50 рынков

### 2029 H2 (июль-декабрь) — KING 👑
- [ ] КотЭ Global — единая платформа для всех рынков (июль)
- [ ] AI-переводчик — реал-тайм перевод на 20+ языков (август)
- [ ] Smart contracts для партнёров (сентябрь)
- [ ] Predictive analytics — предсказание спроса на квартал вперёд (октябрь)
- [ ] Autonomous travel — полная автоматизация бронирования (ноябрь)
- [ ] КотЭ Premium — VIP-сервис с персональным AI (декабрь)
- **Цель:** $500K MRR, 50000 клиентов/мес, 80 рынков

### 2030 H1 (январь-июнь) — WORLD DOMINANCE 🏆
- [ ] IPO / Strategic Partnership (январь)
- [ ] КотЭ Ventures — инвестиции в стартапы (февраль)
- [ ] AI Research Lab — собственные модели для туризма (март)
- [ ] КотЭ Academy — обучение партнёров (апрель)
- [ ] Sustainability Program — экотуризм (май)
- [ ] Глобальное покрытие — 100+ стран (июнь)
- **Цель:** $1M MRR, 100000 клиентов/мес, 100+ рынков

### 2030 H2 (июль-октябрь) — THE KING 👑🌍
- [ ] КотЭ — #1 AI travel platform в мире (июль)
- [ ] Полная автоматизация — от запроса до возвращения домой (август)
- [ ] КотЭ Metaverse — виртуальные путешествия (сентябрь)
- [ ] **30 октября 2030 — ТЫ КОРОЛЬ МИРА в туристическом бизнесе** 🏆
- **Финальная цель:** $2M MRR, 200000 клиентов/мес, 150+ стран, 5000+ партнёров

---

## 👤 Команда

| Роль | Ответственность |
|------|----------------|
| Founder / CEO | Стратегия, рынки, партнёры |
| AI Engineer (КотЭ) | Бот, AI, автоматизация |
| DevOps | VPS, Docker, мониторинг |

---

## 📈 Ключевые метрики

| Метрика | Сейчас | Конец 2026 | Конец 2027 | Конец 2028 | Конец 2029 | Конец 2030 |
|---------|--------|-----------|-----------|-----------|-----------|-----------|
| Клиенты/мес | 0 | 50 | 2000 | 8000 | 50000 | 200000 |
| Бронирования/мес | 0 | 20 | 500 | 3000 | 20000 | 80000 |
| Рынки | 4 | 4 | 10 | 30 | 80 | 150+ |
| Партнёры | 0 | 5 | 50 | 500 | 2000 | 5000+ |
| MRR | $0 | $500 | $10K | $80K | $500K | **$2M** |
| AI-диалогов/мес | 0 | 1K | 20K | 100K | 500K | 2M+ |
| Команда | 1 | 3 | 8 | 25 | 80 | 200+ |
| Страны | 2 | 4 | 10 | 30 | 60 | 100+ |

### 💰 Revenue Trajectory

```
2026: $500/мес  →  $6K/год
2027: $10K/мес  →  $120K/год
2028: $80K/мес  →  $960K/год
2029: $500K/мес →  $6M/год
2030: $2M/мес   →  $24M/год  🏆
```

### 🏆 Milestones

| Дата | Событие |
|------|---------|
| **9 июня 2026** | **VPS ЗАПУЩЕН** 🚀 |
| Дек 2026 | Первые 50 клиентов |
| Июн 2027 | Мобильное приложение |
| Дек 2027 | $10K MRR |
| Июн 2028 | 100+ партнёров |
| Дек 2028 | Франшиза КотЭ |
| Июн 2029 | 50 рынков |
| Дек 2029 | $500K MRR |
| Июн 2030 | IPO-ready |
| **30 окт 2030** | **КОРОЛЬ МИРА** 🏆👑🌍 |

---

## 💰 Стоимость инфры

| Сервис | Стоимость/мес |
|--------|--------------|
| Hetzner CPX21 | ~€8 |
| Supabase Pro | $25 |
| Gemini API | ~$5 |
| n8n (self-hosted) | $0 |
| Telegram Bot API | $0 |
| Домен | ~$1 |
| **Итого** | **~$40/мес** |

---

## 🛠️ Быстрый старт

```bash
# 1. Клонировать
git clone github.com/<YOUR_GITHUB>/kote-system
cd kote-system

# 2. Настроить
npm install
cp .env.example .env
# Заполнить .env ключами

# 3. Supabase
# SQL Editor → schema.sql → Run
# SQL Editor → migrations/002_full_schema.sql → Run

# 4. Запустить
npm run bot

# 5. Telegram → @phuket_nestandart_bot → /start
```

---

## 📄 Лицензия

MIT License

---

*KOTЭ SYSTEM — Автономный отдых, автоматизированный.*
*Последнее обновление: июнь 2026*
