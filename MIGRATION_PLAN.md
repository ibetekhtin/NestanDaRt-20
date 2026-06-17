# MIGRATION_PLAN.md — План миграции
# Статус: ОЖИДАЕТ ПОДТВЕРЖДЕНИЯ

---

## ЦЕЛЬ

Из текущего хаоса (2 кодовые базы на сервере + дубли локально) →
в одну чистую структуру: git репо = единственный источник истины.

**Никаких изменений без подтверждения Ильи.**

---

## ФАЗА 0 — НЕМЕДЛЕННО (критические баги)

### 0.1 Починить туры (404)
**Проблема:** 26 страниц туров недоступны.
**Решение:** Изменить `generate_tours.py` — выходная папка `nestandart-phuket/tours/`
вместо корневого `tours/`.
**После:** Перегенерировать все туры, закоммитить.

**Затронутые файлы:**
- `generate_tours.py` (строка с output dir)
- удалить `/var/www/nestandart/tours/` (корневая папка — мусор)

### 0.2 Удалить мусор с сервера (не в git)
Файлы которые сервер не обслуживает, не нужны, занимают место:
- `/var/www/nestandart/platform/app.html.bak_v9`
- `/var/www/nestandart/platform/app/index.html` (дубль app.html)
- `/var/www/nestandart/tours/` (неправильная папка)

---

## ФАЗА 1 — ЧИСТКА ЛОКАЛЬНОГО РЕПО

### 1.1 Удалить дубли старой структуры из репо

Старая структура (корень репо) → можно удалить после того как всё переехало в `nestandart-phuket/`:

| Файл/Папка | Статус | Действие |
|------------|--------|----------|
| `index.html` (корень) | Дубль nestandart-phuket/index.html | Удалить |
| `css/` (корень) | Дубль nestandart-phuket/css/ | Удалить |
| `js/` (корень) | Дубль nestandart-phuket/js/app.js | Удалить |
| `blog/` (корень) | Дубль nestandart-phuket/blog/ | Удалить |
| `tours/mototour.html` (корень) | Должен быть в nestandart-phuket/tours/ | Переместить → Удалить |
| `404.html` (корень) | Дубль? | Проверить |
| `roadmap.html` (корень) | Дубль? | Проверить |
| `sitemap.xml` (корень) | Дубль nestandart-phuket/? | Проверить |
| `robots.txt` (корень) | Дубль? | Проверить |
| `website/` (папка) | Дубль сайта | Удалить |
| `og-image.png` (корень) | Перенести в nestandart-phuket/ | Переместить |

### 1.2 Объединить bot/ и platform/bot/

Сейчас два места с ботом:
- `bot/` — старый (JS + Python смешаны)
- `platform/bot/` — новый (только Python, неполный)

Действие: `platform/bot/` должен стать единственным местом.
Перенести из `bot/` всё уникальное в `platform/bot/`, потом удалить `bot/`.

Node.js файлы (`ai.js, index.js, supabase.js, memory.js`) — архивировать или удалить
(текущий production бот работает на n8n Cloud с Gemini, не на Node.js).

### 1.3 Убрать дубли схемы Supabase

Сейчас три места:
- `supabase/schema.sql` (корень)
- `platform/supabase/schema.sql`

Оставить: только `platform/supabase/schema.sql` или создать `supabase/migrations/` в репо.

### 1.4 ai/ → platform/kote/

`ai/kote_prompt.txt` → уже есть `platform/kote/prompt.txt`.
Папку `ai/` можно удалить.

---

## ФАЗА 2 — ЧИСТКА СЕРВЕРА (/opt/kote/)

`/opt/kote/` — старая кодовая база. Docker контейнеры запускаются отсюда.

### 2.1 Перенести docker-compose.yml

Перенести активный docker-compose из `/opt/kote/` в `/var/www/nestandart/` (git репо).
Закоммитить правильную версию.

### 2.2 Перенести полный app/backend/ в репо

`/opt/kote/app/backend/routers/` содержит 9 роутеров которых НЕТ в git репо.
Перенести всё в `platform/backend/` или `app/backend/` в репо.

### 2.3 После переноса — убрать /opt/kote/

После того как всё нужное перенесено в git репо и задеплоено:
```bash
# Остановить Docker (перенесли compose в /var/www)
cd /opt/kote && docker-compose down
# Бэкап на всякий случай (уже есть /opt/kote.tar.gz)
# Удалить
rm -rf /opt/kote
```

---

## ФАЗА 3 — ДОВЕСТИ БОТ ДО ПОЛНОЦЕННОСТИ

Текущий production бот — n8n Cloud. Цель — перенести на VPS Python бот.

### 3.1 Доработать platform/bot/main.py

Добавить функции которые сейчас только в n8n workflow:
- `upsert_client()` при /start
- `save_conversation()` после каждого ответа
- `load_history()` из Supabase (не из RAM)
- `get_kote_context()` RPC вызов
- `update_client_memory()` и `update_client_stage()`

### 3.2 Создать platform/bot/supabase_client.py

Отдельный модуль для всех операций с Supabase.

### 3.3 Обновить docker-compose.yml

Добавить сервис `kote-bot` (Python) без зависимостей от других сервисов.

### 3.4 Переключить webhook

Остановить n8n Cloud workflow.
Запустить Python бот на VPS.
Зарегистрировать Telegram webhook на новый адрес.

---

## ФАЗА 4 — АВТОМАТИЗАЦИИ В N8N (LOCAL)

После переноса бота — n8n Cloud больше не нужен.
Локальный n8n Docker остаётся только для:
- Уведомления менеджеру о новых заявках
- Напоминания клиентам за день до тура
- Запрос отзыва после тура

---

## ПОРЯДОК ВЫПОЛНЕНИЯ

```
Фаза 0.1 — Починить туры (404)  ← ПЕРВЫМ ДЕЛОМ
Фаза 0.2 — Мусор с сервера
Фаза 1   — Чистка репо (локально + git push)
Фаза 2   — Чистка сервера
Фаза 3   — Python бот
Фаза 4   — n8n автоматизации
```

---

## ПРАВИЛО

**Перед каждой фазой — подтверждение Ильи.**
**Никаких "заодно" изменений.**
