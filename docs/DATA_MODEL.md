# 🗃️ DATA_MODEL — единая модель данных (канон)

**Единственный источник истины — Supabase** (проект `cmmdrhususjuadqzyssc`).
Все поверхности (сайт, приложение/PWA, Telegram-бот через n8n, backend, HQ) работают
с ОДНИМИ И ТЕМИ ЖЕ таблицами и полями. Прямые INSERT в `clients`/`bookings` запрещены —
только через RPC `app_upsert_lead`.

Обновлено: 2026-06-22.

---

## Единый путь записи лида/брони

```
Сайт / Приложение / Бот / Backend  ──►  app_upsert_lead(...)  ──►  clients + bookings
```

`app_upsert_lead` (SECURITY DEFINER, anon): антидубль клиента (phone → tg_chat_id → email),
антидубль брони (по `external_id`), пишет историю в `action_history`. Возвращает
`{client_id, booking_id, is_new_client, is_new_booking}`.

**Параметры (передавать одинаково со всех поверхностей):**
`p_external_id`(ключ), `p_source`, `p_name`, `p_phone`, `p_email`, `p_telegram`, `p_tg_chat_id`,
`p_whatsapp`, `p_instagram`, `p_vk`, `p_tour_name`, `p_tour_slug`, `p_date_start`(date/ISO),
`p_people`(всего), `p_adults`, `p_children`, `p_budget`, `p_total`(₽), `p_comment`, `p_status`.

> С миграции 011 `p_adults`/`p_children` заполняют колонки `bookings.adults/children`.
> Младенцы до 4 лет — бесплатно, отдельной колонки нет: `infants = people_count − adults − children`.

---

## Ядро таблиц (ключевые поля)

| Таблица | Ключевые поля | Кто пишет / читает |
|---|---|---|
| `clients` | id, name, phone, email, telegram, **tg_chat_id**, source, status, **stage**, market, country, language | пишет `app_upsert_lead`; читают HQ, бот (`get_kote_context`) |
| `bookings` | id, **external_id**, client_id, tour_id, tour_name, **date_start**, **people_count**, **adults**, **children**, total(₽), comment, source, **status**, notified_status, nudged_at | пишет `app_upsert_lead`; читают HQ (CRM/Воронка), планировщики |
| `payments` | id, booking_id, provider, payment_id, amount(₽), currency, status, confirmation_url, paid_at | пишет backend `/pay/*`; читает HQ (Воронка/Финансы) |
| `tours` | id, **slug**, title, city, **price_adult**, **price_child**, market_id, active, season_note | справочник; читают бот, сайт, backend `/pay/create` |
| `markets` | **id**(text: phuket/pattaya), name, currency, active | справочник рынков |
| `conversations` | id, client_id, message, response, intent, source | пишет бот; считает Воронка |
| `client_memory` | client_id, interests, budget_level, travel_style, arrival_date, group_size, has_children | пишет бот (`upsert_client_memory`); читает `get_kote_context` |

---

## Канон значений

- **booking.status:** `Новый` → (менеджер) `Подтверждён` / `Оплачено` / `Отменён` / `Перенесён`.
  При смене (кроме «Новый») клиент авто-уведомляется (`bot_booking_status_changes`, #3).
- **booking.source:** `Telegram (КотЭ)` | `Сайт` | `Приложение` | …
- **external_id:** уникален на бронь. Бот: `tg_<chat>_<timestamp>`; сайт/app — свой идемпотентный ключ.
- **Деньги:** `bookings.total` и `payments.amount` — в ₽ (целые). Цены туров — в ฿
  (`price_adult/price_child`); конверсия ฿→₽ курсом `YOOKASSA_BAHT_TO_RUB` при создании платежа.

---

## Оплата (YooKassa)

```
бронь готова → /pay/create (сумма = price_adult×adults + price_child×children × курс)
            → payments(pending, confirmation_url) → ссылка клиенту
оплата → /pay/webhook (перепроверка у YooKassa) → payments=succeeded
       → app_upsert_lead(external_id, status='Оплачено') → КотЭ пишет «оплачено 🐾»
```

⏳ Активируется ключами `YOOKASSA_SHOP_ID`/`SECRET_KEY` в `.env`.
