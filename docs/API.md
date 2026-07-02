# API — nestandart-backend (FastAPI)

> Актуализировано 2026-07-02 по коду `app/backend/` (main.py + роутеры). Swagger скрыт в проде намеренно.

**База:** `https://nestandart.online` (nginx → kote-backend :8000). Префикс `/api/v1`, кроме особо указанных.

## Аутентификация

Приватные эндпоинты требуют заголовок **`X-Kote-Secret`** (fail-closed: без настроенного секрета — 503, с неверным — 403). JWT не используется. Публичные эндпоинты защищены rate-limit на nginx (зоны `api`, `leads`).

## Эндпоинты

| Метод и путь | Доступ | Что делает |
|---|---|---|
| `GET /health` | публичный (без префикса) | `{"status":"ok","version":"2.0.0"}` |
| `GET /api/v1/markets` · `GET /markets/{id}` | публичный | справочник рынков (404 если нет) |
| `GET /api/v1/tours?market_id&active&category` · `GET /tours/{id\|slug}` | публичный | каталог туров |
| `POST /api/v1/leads` | публичный | лид; **требует** phone/tg_chat_id/telegram/email (иначе 400) |
| `POST /api/v1/lead` | публичный, legacy | обратная совместимость, тот же гейт идентификатора |
| `POST /api/leads` (без /v1) | публичный | checkout PWA «Нестандарт»; гейт идентификатора; уведомляет менеджера |
| `GET /api/v1/leads?status&stage&limit` | 🔒 X-Kote-Secret | список лидов (PII) |
| `POST /api/v1/bookings` | 🔒 | создать бронь |
| `PATCH /api/v1/bookings/{id}` | 🔒 | статус: Новый/Подтверждён/Оплачено/Завершён/Отменён |
| `GET /api/v1/bookings/{id}` | 🔒 | бронь + клиент + тур (PII) |
| `GET /api/v1/clients/{tg_chat_id}` | 🔒 | карточка клиента (PII) |
| `GET/POST /api/v1/clients/{id}/memory` | 🔒 | память клиента |
| `POST /api/v1/ai/chat` | 🔒 | AI для n8n-бота (каскад providers/) |
| `POST /api/v1/ai/ask` | публичный | AI для PWA |
| `POST /api/v1/pay/create` | 🔒 | платёж ЮKassa: сумма считается на сервере из tours; идемпотентно по брони |
| `POST /api/v1/pay/webhook` | публичный | вебхук ЮKassa: статус перепроверяется у API, сверка суммы/валюты, refund/cancel |
| `POST /api/v1/pay/reconcile` | 🔒 | сверка зависших платежей (зовёт n8n по крону) |
| `POST /api/v1/sos` | 🔒 | SOS: номера экстренных служб рынка + алерт менеджеру |
| `POST /api/v1/webhook/lead` · `/webhook/booking` | 🔒 | входящие из n8n |

## Модель данных лида

Все записи лидов идут через единый helper `db.upsert_lead()` → RPC `app_upsert_lead` (Supabase, SECURITY DEFINER, вызов только под service_role + sha256-гейт секрета).

## Ошибки

- 400 — нет идентификатора лида; 403/503 — секрет-гейт; 404 — не найдено; 422 — невалидная схема (pydantic).
- 500 — generic «Внутренняя ошибка сервера» (текст ошибки БД клиенту не отдаётся, детали в логах контейнера).

## Смоук-проверка

```bash
curl -s https://nestandart.online/health
curl -s https://nestandart.online/api/v1/markets
pytest app/backend/tests/ -q       # 25 тестов (нужен KOTE_RPC_SECRET в env для PII-кейсов)
```
