# PROMPT.md — План развития «Нестандартный Отдых»
> Сгенерирован 18.06.2026. **Аудит №2 проведён.**  
> Единственный источник правды: МАСТЕР_ФАЙЛ_ПРОЕКТА.md

---

## Контекст проекта
Проект «Нестандартный Отдых» — AI-платформа путешествий в Азии. 
- **Supabase БД:** `cmmdrhususjuadqzyssc` (us-east-1)
- **КотЭ:** n8n Cloud (`ibetekhtin.app.n8n.cloud`) + Gemini 2.0 Flash
- **Сайт:** `nestandart.online` (VPS Hetzner `77.42.93.187`, редирект с `nestandart-phuket.ru`)
- **Бот:** `@phuket_nestandart_bot`
- **Репозиторий:** `ibetekhtin/nestandart-20`
- Все секреты и ключи → МАСТЕР_ФАЙЛ_ПРОЕКТА.md

---

## Статус реализации (Аудит №2)

### ✅ Полностью исправлено

| Задача | Статус | Детали |
|--------|--------|--------|
| Фото туров | ✅ | 17/33 туров — сделано |
| CTA на бота — app.js | ✅ | `TG_BOT` → `phuket_nestandart_bot` |
| CTA на бота — index.html | ✅ | `sameAs` в JSON-LD |
| CTA на бота — shared/markets.js | ✅ | Все 4 рынка |
| CTA на бота — футеры блогов | ✅ | 7 файлов blog/*.html |
| CTA на бота — футеры туров | ✅ | tours/mototour.html |
| CTA на бота — тело статьи | ✅ | blog/kak-dobratsya-iz-aeroporta-phuketa.html (2 ссылки) |
| Паттайя — platform/app.html | ✅ | `PATTAYA_ENABLED = true` |
| Паттайя — platform/public/index.html | ✅ | Уже было `true` |
| PROMPT.md | ✅ | Создан |

### ❌ Осталось сделать

| Задача | Приоритет | Описание |
|--------|-----------|----------|
| Усиление КотЭ (function calling) | 🟡 Важно | Добавить в n8n workflow 4 инструмента Gemini |
| ЮKassa webhook | 🔴 Критично | После получения SHOP_ID + SECRET_KEY |
| HQ дашборд + CRM | 🟡 Важно | Допилить React в hq/ |
| Сбор отзывов | 🟢 Потом | Запустить n8n workflow |
| Бали / Дубай / Вьетнам | 🟢 Потом | Наполнить контентом |

---

## Структура репо

```
/
├── МАСТЕР_ФАЙЛ_ПРОЕКТА.md     
├── docker-compose.yml          
├── PROMPT.md                   ← Этот файл
├── app/backend/                ← FastAPI (Python, порт 8000)
│   ├── main.py
│   ├── config.py
│   └── routers/ (ai, bookings, clients, leads, markets, memory, sos, webhooks)
├── platform/
│   ├── bot/                    ← Python-бот (ВЫКЛ, сейчас n8n Cloud)
│   └── docs/
├── nestandart-phuket/          ← Сайт (HTML/CSS/JS)
│   ├── index.html              ← ✅ CTA исправлен
│   ├── blog/ (10 статей)       ← ✅ CTA исправлены
│   ├── tours/ (24 страницы)    ← ✅ CTA исправлены
│   ├── css/
│   └── js/
│       ├── app.js              ← ✅ TG_BOT исправлен
│       └── config.js
├── hq/                         ← React дашборд (нужно допилить)
├── n8n/flows/                  ← 8 workflow (экспорты)
├── supabase/migrations/
├── deploy/
└── shared/markets.js           ← ✅ tg_bot исправлены
```

---

## Этап 1: Быстрые победы (сделано)

### Задача 1.1 — Фото туров ✅
- 17 туров без картинок — загружены

### Задача 1.2 — CTA на бота ✅
- Заменены все ссылки `@nestandart_phuket` → `@phuket_nestandart_bot`
- Затронуто: app.js, index.html, shared/markets.js, 7 blog/*.html, tours/mototour.html

### Задача 1.3 — Паттайя ✅
- `platform/app.html`: `PATTAYA_ENABLED = true`
- `platform/public/index.html`: уже `true`
- В `shared/markets.js` pattaya.active остаётся `false` (решать тебе)

### Задача 1.4 — Усиление КотЭ ⬜
- Добавить в n8n workflow «КотЭ — AI Агент с памятью» инструменты Gemini:
  1. `search_knowledge(query)` — поиск по базе знаний Supabase
  2. `get_tour_info(tour_id)` — информация о конкретном туре
  3. `check_availability(tour_id, date)` — проверка доступных дат
  4. `create_booking_draft(tour_id, client_id, date)` — черновик бронирования

---

## Этап 2: Онлайн-оплата (после получения ключей ЮKassa)

- Добавить webhook `/api/v1/payment/yookassa` в `app/backend/routers/payments.py`
- При статусе `succeeded` → `booking.status = 'paid'`
- Создать n8n workflow для обработки платежей
- Обновить `payments` таблицу

---

## Этап 3: HQ Дашборд + CRM

- Допилить React приложение в `hq/`
- Подключить к Supabase (service_role)
- Реализовать:
  - **CRMView:** таблица клиентов, фильтры, поиск
  - **DashboardView:** графики (лиды/день, конверсия, доход)
  - **ContentFactoryView:** управление контентом (туры, знания)

---

## Важные ограничения
- ❌ НЕ создавать вторую БД
- ❌ НЕ писать напрямую в clients/bookings минуя RPC
- ❌ НЕ хранить ключи в коде (только .env)
- ❌ НЕ запускать Python-бот и n8n Cloud одновременно
- ✅ Все изменения деплоить через git push на VPS