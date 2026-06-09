# 📊 Supabase Database — KOTЭ SYSTEM

## Tables

### Core

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `markets` | Пути направлений | id (TEXT PK), name, currency, timezone, active |
| `clients` | Клиенты (telegram) | id (UUID), market_id, telegram_id (UNIQUE), name, phone |
| `services` | Услуги (туры/трансферы/аренда) | id (UUID), market_id, type (tour/transfer/rental), title, price, currency, available |
| `bookings` | Бронирования | id (UUID), market_id, client_id, service_id, date, status (draft/pending/confirmed/completed/cancelled), total |
| `messages` | Лог сообщений (AI + user) | id (UUID), market_id, client_id, session_id, role (user/assistant/system), content |
| `payments` | Платежи по броням | id (UUID), booking_id, amount, currency, method (cash/card/transfer/crypto), status (pending/completed/failed/refunded) |

### Extended (migration 002)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `leads` | Лиды до бронирования | id (UUID), market_id, telegram_id, name, phone, email, source (telegram/website/mobile/manual/partner), status (new/contacted/qualified/converted/lost) |
| `ai_interactions` | Полный лог AI | id (UUID), market_id, session_id, user_message, ai_response, model, tokens_used, latency_ms, intent, error |
| `client_memory` | Память клиента | id (UUID), client_id, market_id, key, value, importance (1-10), expires_at. Substitute: (client_id, market_id, key) |
| `reviews` | Отзывы | id (UUID), market_id, client_id, booking_id, service_id, rating (1-5), comment, status (pending/published/hidden) |
| `partners` | Поставщики | id (UUID), market_id, name, type (hotel/transfer/guide/rental/restaurant/other), contact_name, phone, commission_pct, active |
| `action_history` | Audit log | id (UUID), market_id, actor_type (user/manager/bot/system/n8n), action, entity_type, entity_id, payload (JSONB) |
| `tours` | Расшенренные туры | id (UUID), market_id, service_id, duration_hours, difficulty (easy/medium/hard), languages[], highlights[], includes[] |

## Views

| View | Description |
|------|-------------|
| `booking_details` | JOIN: bookings + clients + services (original) |
| `v_booking_full` | JOIN: bookings + markets + clients + services (extended) |
| `v_lead_stats` | Аналитика лидов (new/contacted/converted, conversion_pct) |

## RPC Functions

| Function | Description |
|----------|-------------|
| `app_upsert_lead(market_id, telegram_id, name, ...)` | Создать/обновить лид |
| `app_create_booking(market_id, telegram_id, name, service_id, date, total)` | Создать бронь + клиента + лид |
| `app_update_memory(client_id, market_id, key, value, importance)` | Upsert в client_memory |
| `app_get_client_context(client_id, market_id)` | Активная память клиента для AI |
| `app_get_market_stats(market_id, since)` | Статистика рынка за период |
| `app_log_action(market_id, actor_type, actor_id, action, ...)` | Ручной аудит |

## RLS Policies

- `anon`: read-only markets, services, reviews (published)
- `authenticated`: full access (backend API)
- `service_role`: full access (bot, n8n, ignores RLS)

## Triggers

- `log_action()`: После INSERT/UPDATE/DELETE на bookings, leads, payments → запись в action_history
- `touch_updated_at()`: Автообновление updated_at на leads, client_memory, partners, tours

## Migration Instructions

```
1. Зайди в Supabase SQL Editor
2. Выполни supabase/schema.sql (основная схема)
3. Выполни supabase/migrations/002_full_schema.sql (расширение)
4. (Опционально) supabase/seed/seed_demo.sql (demo-данные)