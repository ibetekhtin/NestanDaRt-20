# N8N_AUDIT.md
## Аудит N8N Workflows проекта «Нестандартный Отдых»
**Дата:** 2025-06-18

---

## 1. ОБЗОР WORKFLOWS

Всего найдено: 7 workflow файлов в `n8n/flows/`:
1. `booking-confirm.json` — подтверждение/оплата брони
2. `booking-flow.json` — жизненный цикл брони (confirm/cancel/complete)
3. `daily-report.json` — ежедневный отчёт
4. `lead-intake.json` — приём лидов из Telegram/Web
5. `market-sync.json` — синхронизация рынков
6. `memory-update.json` — обновление памяти клиента
7. `reminder.json` — напоминания
8. `sos.json` — SOS сигналы

---

## 2. АНАЛИЗ КАЖДОГО WORKFLOW

### 2.1. booking-confirm.json
**Назначение:** Подтверждение брони + оплата + уведомления

**Узлы:**
- Webhook → Get Booking → Build Payload → Save Payment + Update Booking → Notify Client + Notify Manager

**Проблемы:**
- ⚠️ Дублирование: `Notify Manager` и `Notify Client` — отдельные узлы
- ⚠️ `Get Booking` использует `tableId: booking_details` (View?), а не `bookings`
- ⚠️ Нет проверки существования брони

**Упрощение:**
- Объединить уведомления через один Telegram узел с branching
- Добавить проверку статуса брони

---

### 2.2. booking-flow.json
**Назначение:** Смена статуса брони (confirm/cancel/complete)

**Узлы:**
- Webhook → Get Booking → Switch → Confirm/Cancel/Complete → Notify Client

**Проблемы:**
- ⚠️ Switch узел имеет всего 3 правила, а workflow одновременно и booking-confirm.json делают confirm
- ⚠️ Возможен race condition: оба workflow могут обновить бронь
- ⚠️ `Get Booking` ищет по `booking_id`, а в booking-confirm по `id`

**Упрощение:**
- Удалить дублирующий booking-flow, использовать только booking-confirm с расширенным Switch

---

### 2.3. lead-intake.json
**Назначение:** Приём лида и создание клиента

**Узлы:**
- Webhook → Create Client → Notify Manager

**Проблемы:**
- ⚠️ Нет проверки на дубликаты (уже есть ли клиент с таким telegram_id)
- ⚠️ Поля ограничены: нет `market_id` в обязательных?
- ⚠️ `Create Client` возвращает весь объект, но используется только для связи

**Упрощение:**
- Добавить IF узел: если клиент существует — обновить, иначе создать (upsert)

---

### 2.4. memory-update.json
**Назначение:** Обновление памяти клиента

**Узлы:**
- Webhook → Upsert Memory → Log Action

**Проблемы:**
- ⚠️ Использует `operation: create` вместо upsert — может дублировать записи
- ⚠️ Нет проверки на существующую память
- ⚠️ Можно объединить с lead-intake или booking-flow

**Упрощение:**
- Использовать Supabase `upsert` операции
- Объединить с lead-intake: при создании клиента сразу сохранить memory

---

### 2.5. market-sync.json
**Назначение:** Синхронизация рынков

**Проблемы:**
- ⚠️ Требует отдельного анализа (вне scope)
- ✅ Логика не ясна из файла

**Упрощение:**
- Оставить для отдельного аудита

---

### 2.6. daily-report.json
**Назначение:** Ежедневный отчёт

**Проблемы:**
- ⚠️ Расписание (cron) внутри workflow
- ⚠️ Зависит от supabase для данных

**Упрощение:**
- Оставить без изменений (работает)

---

### 2.7. reminder.json
**Назначение:** Напоминания клиентам

**Проблемы:**
- ⚠️ Зависит от booking данных
- ⚠️ Требует проверки

**Упрощение:**
- Оставить без изменений

---

### 2.8. sos.json
**Назначение:** SOS сигналы от клиентов

**Проблемы:**
- ⚠️ Нет приоритизации (все SOS одинаковые)
- ⚠️ Может спамить менеджеру

**Упрощение:**
- Добавить дедупликацию: не отправлять то же SOS чаще чем раз в N минут

---

## 3. ДУБЛИРОВАНИЕ

### 3.1. Дублирующиеся действия

| Действие | Где дублируется | Комментарий |
|----------|-----------------|-------------|
| Create Client | lead-intake.json | Может быть и через backend API |
| Notify Manager | booking-confirm.json, lead-intake.json, sos.json | 3 разных workflow |
| Save to Supabase | memory-update.json, booking-*.json | Много мелких записей |

### 3.2. Предлагаемые объединения

```
Текущие workflows (7)
    ↓
Упрощенная структура (4):
├── intake.json        # lead-intake + memory-update (объединённый)
├── booking.json       # booking-confirm + booking-flow (объединённый)
├── daily.json         # daily-report + reminder (частично)
└── sos.json           # без изменений
```

---

## 4. НЕИСПОЛЬЗУЕМЫЕ УЗЛЫ

**Найдено:**
- ❌ Нет явно неиспользуемых узлов (все узлы имеют связи)

**Потенциально не используются:**
- `market-sync.json` — непонятно, используется ли
- `daily-report.json` — требует проверки

---

## 5. УСТАРЕВШИЕ ИНТЕГРАЦИИ

**Найдено:**
- ⚠️ Используется только Supabase (прекрасно)
- ⚠️ Нет AI узлов (все AI в отдельном боте)
- ⚠️ Webhook triggers для всех потоков

**Рекомендации:**
- Текущие интеграции актуальны
- Следовать принципу "не трогать работающее"

---

## 6. ПРЕДЛОЖЕНИЯ ПО УПРОЩЕНИЮ

### 6.1. Немедленные (минимальные правки)

1. **lead-intake.json + memory-update.json → intake.json**
   - Объединить в один workflow
   - Добавить IF для проверки существующего клиента
   - Использовать Supabase upsert вместо create

2. **booking-confirm.json + booking-flow.json → booking.json**
   - Убрать дублирование confirm логики
   - Один Switch для всех действий

3. **Убрать дублирование Notify Manager**
   - Создать helper workflow "send-manager-notification"
   - Подключать через "Execute Workflow" узел

### 6.2. Краткосрочные (после основной задачи)

4. **Унифицировать структуру webhook'ов**
   - Все webhook с префиксом `/api/n8n/`
   - Единый формат входных данных

5. **Добавить валидацию**
   - JSON Schema для входных данных
   - Проверка обязательных полей

### 6.3. Долгосрочные (вне scope)

6. **Удалить n8n workflows и перенести логику в backend**
   - Если n8n Cloud надёжен — оставить
   - Если нет — переехать на FastAPI endpoints

---

## 7. КОНКРЕТНЫЕ ИЗМЕНЕНИЯ

### 7.1. Объединение lead-intake + memory-update

**Новый intake.json:**

```json
{
  "name": "Lead Intake & Memory",
  "nodes": [
    {"name": "Webhook", "type": "n8n-nodes-base.webhook"},
    {"name": "Get Client", "type": "n8n-nodes-base.supabase", "operation": "get"},
    {"name": "Check Exists", "type": "n8n-nodes-base.if"},
    {
      "true": [
        {"name": "Update Client", "operation": "update"},
        {"name": "Upsert Memory", "operation": "upsert"}
      ],
      "false": [
        {"name": "Create Client", "operation": "create"}
      ]
    },
    {"name": "Notify Manager", "type": "n8n-nodes-base.telegram"}
  ]
}
```

### 7.2. Объединение booking-confirm + booking-flow

**Новый booking.json:**

```json
{
  "name": "Booking Manager",
  "nodes": [
    {"name": "Webhook", "type": "n8n-nodes-base.webhook"},
    {"name": "Get Booking", "operation": "get"},
    {"name": "Switch Action", "rules": ["confirm", "cancel", "complete"]},
    {
      "confirm": [
        {"name": "Save Payment", "operation": "create"},
        {"name": "Update Status", "fields": {"status": "confirmed"}}
      ],
      "cancel": [{"name": "Update Status", "fields": {"status": "cancelled"}}],
      "complete": [{"name": "Update Status", "fields": {"status": "completed"}}]
    },
    {"name": "Notify Client", "type": "n8n-nodes-base.telegram"}
  ]
}
```

---

## 8. ПРАВИЛА БЕЗОПАСНОСТИ

### 8.1. Никогда не удалять workflow без:
1. Бэкапа JSON файла
2. Проверки, используется ли он в n8n Cloud
3. Проверки, ссылается ли на него другой workflow

### 8.2. Правило:
```
Редактировать → Тестировать → Бэкапить → Деплоить
```

### 8.3. Откат:
```bash
# Откат одного workflow
cp n8n/flows/booking.json.bak n8n/flows/booking.json

# Импорт в n8n через UI
```

---

## 9. РЕЗЮМЕ

### Что хорошо:
✅ Все workflows простые и понятные
✅ Используют Supabase и Telegram
✅ Webhook-based архитектура

### Что плохо:
⚠️ Дублирование логики (create client, notify manager)
⚠️ Race condition между booking-confirm и booking-flow
⚠️ Потенциальные дубликаты в memory-update

### Что улучшить:
1. Объединить связанные workflows (2-3 файла → 1)
2. Добавить upsert операции вместо create
3. Добавить валидацию входных данных

---

## 10. ПЛАН ИСПРАВЛЕНИЙ

| Приоритет | Workflow | Изменение | Риск |
|-----------|----------|-----------|------|
| 1 | intake (новый) | Объединить lead-intake + memory-update | Средний |
| 2 | booking (новый) | Объединить booking-confirm + booking-flow | Высокий |
| 3 | Все | Создать backup перед изменениями | Низкий |

**Важно:** Изменения в N8N требуют осторожности, так как это production система.

---

## 11. ИНСТРУКЦИЯ ПО ИСПРАВЛЕНИЯМ

### Этап 1: Бэкап
```bash
mkdir -p n8n/flows/backup
cp n8n/flows/*.json n8n/flows/backup/
```

### Этап 2: Создание объединённых workflows
1. Создать `n8n/flows/intake.json` на основе lead-intake + memory-update
2. Создать `n8n/flows/booking.json` на основе booking-confirm + booking-flow

### Этап 3: Тестирование
1. Импортировать новые workflows в n8n (не заменяя старые!)
2. Протестировать каждый endpoint
3. Сравнить результаты

### Этап 4: Деплой
1. Отключить старые workflows в n8n Cloud
2. Включить новые
3. Мониторить логи 24 часа

### Этап 5: Удаление старых
- Только после подтверждения работоспособности новых