# ARCHITECTURE.md — «Нестандартный Отдых»
# Статус: АУДИТ 17-18 июня 2026

---

## ЦЕЛЕВАЯ АРХИТЕКТУРА

```
Internet
    │
  Nginx (VPS 77.42.93.187)
    ├── nestandart.online/              → /var/www/nestandart/nestandart-phuket/
    ├── nestandart.online/app/          → /var/www/nestandart/platform/app.html
    ├── nestandart.online/baza/         → /var/www/nestandart/nestandart-phuket/baza/
    ├── nestandart.online/tours/*       → /var/www/nestandart/nestandart-phuket/tours/
    ├── /api/leads                     → pm2: nestandart-api (порт 3055)
    └── /n8n/webhook                   → n8n Docker (порт 5678)
    
  Docker (на VPS)
    ├── kote-backend (порт 8000)       → FastAPI + Supabase
    └── n8n (порт 5678)               → ТОЛЬКО автоматизации
    
  Bot КотЭ
    └── n8n Cloud workflow             → PRODUCTION (Gemini 2.0 Flash)
    
  Supabase (cmmdrhususjuadqzyssc)
    ├── PostgreSQL (единственная БД)
    ├── Auth
    └── Storage
```

## ПРАВИЛА

1. Основная бизнес-логика — в коде, не в n8n
2. n8n — только для автоматизации (рассылки, напоминания, события)
3. Бот не зависит от n8n Cloud (нужно перенести на VPS Python)
4. Сайт, приложение, бот — три витрины одной БД (Supabase)
5. Новый рынок = новая запись в markets (не новый код)
6. service_role ключ только на сервере, никогда в клиентском коде
7. Всё в Docker на VPS (кроме nginx и pm2-api)

## ЧТО РЕАЛЬНО РАБОТАЕТ СЕЙЧАС

| Сервис | Где живёт | Статус |
|--------|-----------|--------|
| Сайт | nginx → /var/www/nestandart/nestandart-phuket/ | ✅ РАБОТАЕТ |
| Приложение /app | nginx → platform/app.html | ✅ РАБОТАЕТ |
| /baza/ (HQ) | nestandart-phuket/baza/ | ✅ РАБОТАЕТ |
| /api/leads | pm2: /opt/nestandart-api/server.js | ✅ РАБОТАЕТ |
| Bot КотЭ | n8n Cloud | ✅ РАБОТАЕТ (баги upsert + p_secret исправлены 18.06) |
| kote-backend (API) | Docker /opt/kote/app/backend/ | ✅ ЗАПУЩЕН |
| n8n Docker | Docker /opt/kote/ | ✅ ЗАПУЩЕН |
| Туры /tours/*.html | НИГДЕ — BUG! | ❌ 404 |

## ЧТО НЕ РАБОТАЕТ

| Проблема | Статус |
|----------|--------|
| /tours/*.html → 404 | ✅ ИСПРАВЛЕНО 17.06 |
| Bot не пишет клиентов | ✅ ИСПРАВЛЕНО 18.06 (bot_upsert_client + p_secret) |
| ЮKassa — оплата | ❌ Нужны SHOP_ID + SECRET_KEY |
| Фото 17 туров | ❌ Нужны реальные фото |
