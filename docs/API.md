# 🔌 FastAPI Backend — KOTЭ SYSTEM

## Base URL

```
http://localhost:8000/api/v1
```

## Authentication

Supabase JWT token via `Authorization: Bearer <token>` header. All endpoints require authentication.

---

## Endpoints

### Markets

#### GET `/api/v1/markets`
Получить список активных рынков.

**Response:**
```json
[
  { "id": "phuket", "name": "🏖 Пхукет", "currency": "THB", "timezone": "Asia/Bangkok" }
]
```

#### GET `/api/v1/markets/{market_id}`
Получить информацию о рынке + статистику.

---

### Leads

#### POST `/api/v1/leads`
Создать лид.

**Request:**
```json
{
  "market_id": "phuket",
  "telegram_id": "123",
  "name": "Иван",
  "phone": "+6690...",
  "email": "ivan@example.com",
  "source": "telegram",
  "notes": "Интересуется дайвингом"
}
```

**Response:** `{ "id": "uuid", "status": "new" }`

#### GET `/api/v1/leads?market_id=phuket&status=new`
Получить лиды (фильтры: market_id, status, source).

---

### Bookings

#### POST `/api/v1/bookings`
Создать бронь (через RPC app_create_booking).

**Request:**
```json
{
  "market_id": "phuket",
  "telegram_id": "123",
  "client_name": "Иван",
  "service_id": "uuid",
  "date": "2025-02-15"
}
```

**Response:** `{ "booking_id": "uuid", "status": "draft" }`

#### PATCH `/api/v1/bookings/{booking_id}`
Обновить статус брони.

**Request:** `{ "status": "confirmed" }`

#### GET `/api/v1/bookings/{booking_id}`
Получить полную информацию о брони (VIEW v_booking_full).

---

### Clients

#### GET `/api/v1/clients/{telegram_id}`
Получить клиента по Telegram ID.

**Response:**
```json
{
  "id": "uuid", "name": "Иван", "phone": "+66...",
  "market_id": "phuket", "created_at": "2025-01-01T00:00:00Z"
}
```

---

### AI

#### POST `/api/v1/ai/ask`
Задать вопрос КотЭ.

**Request:**
```json
{
  "market_id": "phuket",
  "session_id": "tg:123",
  "message": "Покажи мне туры на Пхи-Пхи"
}
```

**Response:**
```json
{
  "reply": "🐾 Вот туры на Пхи-Пхи! Выбери интересный...",
  "intent": "recommendation"
}
```

---

### SOS

#### POST `/api/v1/sos`
Экстренный вызов.

**Request:** `{ "telegram_id": "123", "market_id": "phuket" }`

**Response:** `{ "status": "alerted", "emergency_numbers": {...} }`

---

### Memory

#### GET `/api/v1/clients/{client_id}/memory`
Получить память клиента.

**Response:**
```json
[
  { "key": "prefers_pool", "value": "true", "importance": 8 },
  { "key": "allergic_seafood", "value": "true", "importance": 10 }
]
```

#### POST `/api/v1/clients/{client_id}/memory`
Обновить память.

**Request:**
```json
{
  "market_id": "phuket",
  "key": "anniversary",
  "value": "2025-03-15",
  "importance": 7,
  "expires_at": "2025-03-20T00:00:00Z"
}
```

---

### Health

#### GET `/api/v1/health`
Health check.

**Response:** `{ "status": "ok", "timestamp": "2025-01-01T00:00:00Z" }`

---

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request — невалидный JSON |
| 401 | Unauthorized — нет/невалидный JWT |
| 404 | Not Found |
| 422 | Validation Error — невалидные поля |
| 500 | Internal Server Error |