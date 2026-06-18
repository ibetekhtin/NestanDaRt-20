# AUDIT_REPORT.md
## Аудит инфраструктуры проекта «Нестандартный Отдых»
**Дата:** 2025-06-18
**Статус:** Предварительный аудит

---

## 1. СРЕДА И ОБОРУДОВАНИЕ

| Компонент | Статус | Примечания |
|-----------|--------|-----------|
| VPS 77.42.93.187 | ✅ | Ubuntu/Debian (предположительно) |
| Docker | ✅ | Docker Compose используется |
| Nginx | ✅ | SSL сертификаты Let's Encrypt |

---

## 2. DOCKER & DOCKER COMPOSE

### Файл: `docker-compose.yml`

**Найдено:**
- ✅ 3 сервиса определены
- ✅ `kote-backend` — FastAPI REST API (порт 8000)
- ✅ `kote-bot` — Python бот (порт 8081, ПРОФИЛЬ `bot`, ВЫКЛЮЧЕН)
- ✅ `kote-n8n` — локальный n8n (порт 5678)
- ✅ Healthchecks настроены для всех сервисов
- ✅ Resource limits указаны (128-512MB)
- ✅ Логирование с ротацией (10MB, 3 файла)

**Проблемы:**
- ⚠️ `kote-bot` выключен — production использует n8n Cloud
- ⚠️ Дублирование функциональности: и n8n Cloud, и локальный бот могут обрабатывать Telegram

**Упрощение:**
- Оставить текущую структуру — она минимальна и работоспособна

---

## 3. ENV-ФАЙЛЫ

### Файл: `.env.example`

**Найдено:**
- ✅ Supabase credentials
- ✅ Telegram Bot Token
- ✅ Gemini AI Key
- ✅ n8n auth
- ✅ Backend port

**Проблемы:**
- ❌ НЕТ конфигурации для OpenRouter и Groq (требуется по задаче)
- ❌ НЕТ явных fallback настроек для AI провайдеров
- ⚠️ Значения по умолчанию (например, `gemini-2.0-flash`) — можно упростить

**Упрощение:**
- Добавить только переменные для OpenRouter и Groq
- Сохранить текущую структуру

---

## 4. BACKEND (FastAPI)

### Файл: `app/backend/`

**Найдено:**
- ✅ `config.py` — pydantic-settings, читает `.env`
- ✅ `main.py` — основной entry point
- ✅ `routers/` — модульная структура:
  - `ai.py` — AI endpoint (`/ai/ask`)
  - `bookings.py`
  - `clients.py`
  - `leads.py`
  - `markets.py`
  - `memory.py`
  - `sos.py`
  - `webhooks.py`

**Ключевые наблюдения:**

`app/backend/routers/ai.py`:
- ⚠️ Прямой вызов Gemini через `google.generativeai`
- ❌ НЕТ fallback на OpenRouter/Groq
- ❌ Если Gemini падает — возвращается ошибка пользователю
- ✅ История загружается из Supabase
- ✅ Memory context подтягивается

**Проблемы:**
- Только один AI провайдер (Gemini)
- Нет resilience механизма
- При ошибке Gemini пользователь получает сообщение "техническая пауза"

**Упрощение:**
- Добавить fallback chain: Gemini → OpenRouter → Groq
- Минимальные изменения в коде

---

## 5. TELEGRAM BOT (KOTE)

### Файл: `platform/bot/main.py`

**Найдено:**
- ✅ aiogram v3 (современный фреймворк)
- ✅ Поддержка webhook и polling
- ✅ Prompt engineering с системным промптом
- ✅ Контекст: память клиента, история диалога, туры, knowledge
- ✅ Intent detection
- ✅ Memory update через `upsert_client_memory`

**Ключевое:**
- ⚠️ Бот ВЫКЛЮЧЕН (profiles: bot)
- ⚠️ Production = n8n Cloud workflow
- ⚠️ Гемini вызывается напрямую через REST API (`httpx`)
- ❌ НЕТ fallback провайдеров
- ⚠️ Дублирование логики с backend ai.py

**Проблемы:**
- Два места вызывают Gemini: backend ai.py и bot/main.py
- При отказе Gemini — оба падают
- Дублирование prompt engineering

**Упрощение:**
- Вынести AI вызовы в общий модуль
- Использовать тот же fallback chain

---

## 6. N8N WORKFLOWS

### Файлы: `n8n/flows/*.json`

**Найдено (7 workflows):**

1. `booking-confirm.json` — подтверждение оплаты
2. `booking-flow.json` — жизненный цикл брони
3. `daily-report.json` — ежедневный отчёт
4. `lead-intake.json` — приём лидов
5. `market-sync.json` — синхронизация рынков
6. `memory-update.json` — обновление памяти
7. `reminder.json` — напоминания
8. `sos.json` — SOS сигналы

**Анализ:**
- ✅ Все workflows используют Supabase
- ✅ Telegram notifications включены
- ✅ Webhook triggers для внешних вызовов
- ⚠️ Нет AI-узлов (n8n AI nodes) — все AI в отдельном боте
- ✅ Логика простая и понятная

**Проблемы:**
- `memory-update.json` и `lead-intake.json` могут быть частью общего потока
- Дублирование: Create Client в lead-intake и Save Conversation в боте

**Упрощение:**
- Объединить lead-intake и memory-update в единый поток
- Сократить количество workflows на 1-2

---

## 7. SUPABASE

### Файлы: `supabase/schema.sql`, `supabase/migrations/*`

**Найдено:**
- ✅ Основная схема БД
- ✅ Миграции (002-005)
- ✅ Таблицы: clients, bookings, messages, client_memory, action_history
- ✅ RPC функции (например, `app_get_client_context`)

**Проблемы:**
- Требует отдельного аудита схемы (вне scope этого отчёда)
- ✅ Используется Stateful backend

---

## 8. NGINX

### Файлы: `deploy/nginx*.conf`

**Найдено:**
- ✅ `nginx-nestandart-online.conf` — основной сайт
- ✅ `nginx-nestandart-phuket-redirect.conf` — редирект старого домена
- ✅ SSL via Let's Encrypt
- ✅ Reverse proxy для backend (8000) и leads API (3055)
- ✅ gzip compression
- ✅ Security headers

**Проблемы:**
- ⚠️ n8n (порт 5678) проксируется "только по IP" (commented)
- ⚠️ Бот (порт 8081) НЕ проксируется через nginx — webhook?

**Упрощение:**
- Оставить как есть — работает стабильно

---

## 9. SSL & DNS

**Найдено:**
- ✅ Let's Encrypt сертификаты для `nestandart.online`
- ✅ HTTP → HTTPS redirect
- ✅ www → non-www redirect
- ⚠️ SSL для `nestandart-phuket.ru` — требует проверки (есть ли)

**Примечание:** DNS конфигурация не найдена в файлах (ожидается на VPS /etc/bind или Cloudflare)

---

## 10. CI/CD

**Найдено:**
- ⚠️ Отсутствует явный CI/CD pipeline
- ✅ `deploy.sh` — скрипт деплоя
- ✅ `deploy/setup-vps.sh` — настройка VPS
- ✅ `deploy/rollback.sh` — откат
- ⚠️ Git hooks отсутствуют
- ⚠️ Автоматические деплои через GitHub Actions/VPS не настроены

**Упрощение:**
- Вне scope (не входит в задачу по AI инфраструктуре)

---

## 11. AI ИНТЕГРАЦИИ

### Текущее состояние

| Компонент | Провайдер | Fallback | Статус |
|-----------|-----------|----------|--------|
| Backend /ai/ask | Gemini (прямой вызов) | ❌ НЕТ | Работает, но хрупкий |
| Telegram Bot | Gemini (REST API) | ❌ НЕТ | ВЫКЛЮЧЕН (n8n Cloud активен) |
| n8n Workflows | ❌ НЕТ AI | N/A | Без AI узлов |

### Проблемы
1. **Single Point of Failure:** Gemini — единственный AI провайдер
2. **Отсутствие резервирования:** Если Gemini недоступен — все AI функции падают
3. **Дублирование кода:** Prompt engineering и вызов AI в двух местах
4. **Дублирование инфраструктуры:** Параллельно работают backend API и n8n Cloud

### Требуется
1. Fallback chain: Gemini → OpenRouter → Groq
2. Единый AI Layer для backend и бота
3. Обработка ошибок и повторные попытки
4. ENV-based конфигурация ключей

---

## 12. ЛИШНЕЕ И НЕ ИСПОЛЬЗУЕМОЕ

| Элемент | Причина удаления/оптимизации |
|---------|------------------------------|
| `platform/bot/` (отдельный бот) | ❌ ВЫКЛЮЧЕН, используется n8n Cloud |
| Дублирование AI-вызовов | ⚠️ В backend и в боте |
| Дублирование Supabase операций | ⚠️ В workflows и в коде |

**Важно:** Удаление бота требует осторожности — это production система.

---

## 13. ЧТО РАБОТАЕТ

✅ **VPS и Docker** — стабильно работают
✅ **FastAPI Backend** — REST API функционирует
✅ **n8n (локальный)** — автоматизации работают
✅ **Supabase** — БД доступна
✅ **Nginx + SSL** — сайт доступен по HTTPS
✅ **Telegram бот (через n8n Cloud)** — отвечает пользователям
✅ **AI через Gemini** — генерирует ответы

---

## 14. ЧТО НЕ РАБОТАЕТ

❌ **Fallback AI провайдеры** — отсутствуют
❌ **Единый AI слой** — разрозненная реализация
❌ **Автоматическое переключение при ошибках** — нет resilience
❌ **CI/CD** — нет автоматизации деплоя

---

## 15. ЧТО МОЖНО УПРОСТИТЬ

### Немедленно (минимальные изменения):
1. Добавить ENV переменные для OpenRouter и Groq
2. Создать `providers/` модуль с fallback chain
3. Обновить `.env.example` с новыми провайдерами
4. Добавить базовую обработку ошибок

### Среднесрочно (после основной задачи):
5. Объединить AI вызовы в backend и боте
6. Упростить N8N workflows (убрать дубликаты)
7. Добавить базовый CI/CD (deploy script → GitHub Action)

---

## 16. ТОЧКИ ОТКАЗА

```
User Request
    ↓
┌──────────────────────────────────────┐
│  1. Telegram Bot (n8n Cloud)         │ ← Если падает — бот не отвечает
│     ↓                                 │
│  2. Backend API (Docker)              │ ← Если падает — мобильное приложение не работает
│     ↓                                 │
│  3. Supabase                           │ ← Если падает — всё останавливается
│     ↓                                 │
│  4. Nginx                              │ ← Если падает — сайт недоступен
└──────────────────────────────────────┘
```

**AI Критический путь:**
```
User Message
    ↓
Gemini API → ❌ 503/Timeout
  ↓
OpenRouter API → ❌ 503/Timeout
  ↓
Groq API → ❌ 503/Timeout
  ↓
Fallback Answer (hardcoded)
```

---

## ВЫВОДЫ

1. **Инфраструктура работоспособна**, но хрупкая из-за отсутствия fallback AI
2. **Код минималистичен** — можно улучшить без усложнения
3. **Главный риск:** Одиночная зависимость от Gemini
4. **Приоритет:** Добавить 2 резервных AI провайдера с минимальными изменениями

---

## СЛЕДУЮЩИЕ ШАГИ

1. Создать `PLAN.md` с детальным планом внедрения AI Layer
2. Представить ключевым лицам на утверждение
3. После одобрения — реализация