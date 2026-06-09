# 🔄 n8n Workflows — KOTЭ SYSTEM

## Overview

8 workflows for event-driven automation.

| # | Workflow | Trigger | Purpose |
|---|----------|---------|---------|
| 1 | `lead-intake` | Webhook POST | Создание лида → уведомление менеджера |
| 2 | `booking-confirm` | Webhook POST | Подтверждение брони + платёж + уведомления |
| 3 | `booking-flow` | Webhook POST | Полный жизненный цикл брони (draft→pending→confirmed) |
| 4 | `reminder` | Cron 18:00 | Напоминание клиенту за 24ч до брони |
| 5 | `sos` | Webhook POST | Экстренный вызов: менеджер + клиент |
| 6 | `memory-update` | Webhook POST | Обновление памяти клиента |
| 7 | `daily-report` | Cron 09:00 | Ежедневная статистика по рынкам |
| 8 | `market-sync` | Webhook POST | Синхронизация рынков между сервисами |

---

## 1. Lead Intake

**Webhook:** `POST /webhook/lead-intake`
**Payload:**
```json
{ "market_id": "phuket", "telegram_id": "123", "name": "Иван", "phone": "+66...", "email": "...", "source": "telegram" }
```

**Flow:** Webhook → Create Client (Supabase) → Notify Manager (Telegram)

**Error handling:** Supabase upsert на случай дубликатов. Retry на Notify Manager (1 попытка через 5 сек).

---

## 2. Booking Confirm

**Webhook:** `POST /webhook/booking-confirm`
**Payload:**
```json
{ "booking_id": "uuid", "method": "card", "amount": 1500 }
```

**Flow:**
```
Webhook → Get Booking (booking_details) → Build Payload
  ├─→ Save Payment (status=completed) ──→ Notify Client
  └─→ Update Booking (status=confirmed) → Notify Manager
```

**Error handling:** Parallel save — если один поток падает, другой продолжает. Retry на Notify (2 попытки).

---

## 3. Booking Flow (Lifecycle)

**Webhook:** `POST /webhook/booking-flow`
**Payload:** `{ "booking_id": "uuid", "action": "confirm" | "cancel" | "complete" }`

**Flow:**
```
Webhook → Get Booking → Switch (action)
  confirm: Update status=confirmed → Notify Client + Manager
  cancel: Update status=cancelled → Notify Client
  complete: Update status=completed → Request Review
```

---

## 4. Reminder

**Trigger:** Cron, 18:00 UTC daily

**Flow:**
```
Cron → Get Tomorrow (Code node, UTC+1) → Get Upcoming Bookings
  → Filter (status=confirmed, date=tomorrow)
  → Loop (batch 1) → Send Reminder (Telegram)
```

**Error handling:** Skip if no bookings. Individual send — if one fails, continue loop.

---

## 5. SOS

**Webhook:** `POST /webhook/sos`
**Payload:** `{ "telegram_id": "123" }`

**Flow:**
```
Webhook → Get Client (Supabase) → Normalize
  ├─→ Alert Manager (Telegram) — priority message
  └─→ Reply to Client — emergency numbers
```

**Emergency numbers by market:**
- Thailand: Police 191, Ambulance 1669, Fire 199
- Bali: Police 110, Ambulance 118
- Dubai: Police 999, Ambulance 998

---

## 6. Memory Update

**Webhook:** `POST /webhook/memory-update`
**Payload:**
```json
{ "client_id": "uuid", "market_id": "phuket", "key": "prefers_pool", "value": "true", "importance": 7 }
```

**Flow:** Webhook → Upsert Memory (RPC app_update_memory) → Log Action

---

## 7. Daily Report

**Trigger:** Cron, 09:00 UTC daily

**Flow:**
```
Cron → Get All Active Markets → Loop
  → Get Market Stats (RPC app_get_market_stats) → Format Report
  → Send to Manager (Telegram)
```

**Report format:**
```
📊 Отчёт за [дата] — [рынок]
🎯 Новых лидов: X
📋 Бронирований: X
✅ Подтверждено: X
💰 Выручка: X [currency]
🤖 AI-диалогов: X
⭐ Средний рейтинг: X
🚨 SOS: X
```

---

## 8. Market Sync

**Webhook:** `POST /webhook/market-sync`
**Payload:** `{ "action": "activate" | "deactivate", "market_id": "phuket" }`

**Flow:**
```
Webhook → Update Market (active) → Notify All Partners (loop) → Log
```

---

## Setup Instructions

1. Import JSON из `n8n/flows/`
2. Создай Credentials:
   - **Supabase:** URL + service_role key
   - **Telegram Bot:** Bot token
3. Настрой `MANAGER_CHAT_ID` в Variables
4. Активируй workflows
5. Протестируй через Supabase SQL:
   ```sql
   SELECT net.http_post('https://your-n8n.com/webhook/lead-intake', '{"market_id":"phuket","name":"Test","telegram_id":"999999"}'::jsonb);