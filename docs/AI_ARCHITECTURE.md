# AI_ARCHITECTURE.md
## Архитектура AI-слоя проекта «Нестандартный Отдых»
**Версия:** 2.0  
**Дата:** 2026-06-21

> **С 21.06.2026 оба входа идут через ОДИН каскад.** Два endpoint'а backend, одна цепочка `providers/`:
> 1. **Live-бот** = n8n workflow `doCUKEZQpLQjDmxP` → модель-нода зовёт backend **`POST /api/v1/ai/chat`** (passthrough: принимает готовый OpenAI-формат `messages[]`, возвращает `choices[0].message.content`). Промпт собирает n8n, fallback обеспечивает backend. Ключи AI — только в backend, не в `kote-n8n`.
> 2. **PWA / приложение** → backend **`POST /api/v1/ai/ask`** (backend сам строит простой system prompt).
> Оба зовут `providers.ask()` → каскад **groq → aitunnel → openrouter → gemini**.

---

## 1. ОБЩАЯ СХЕМА

```
┌─────────────────────────────────────────────────────────┐
│                    ПОЛЬЗОВАТЕЛЬ                          │
│              (Telegram / Мобильное приложение)           │
└───────────────────────┬─────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
   ┌────▼────┐                    ┌────▼────┐
   │  n8n    │ /api/v1/ai/chat    │  PWA    │ /api/v1/ai/ask
   │self-host│───────┐    ┌───────│ (моб.)  │
   │(doCU…)  │       ▼    ▼       └─────────┘
   └─────────┘   ┌──────────────┐
                 │   Backend    │ providers/ai.py → ask()
                 │   FastAPI    │
                 └──────┬───────┘
                        ▼
        ┌─────────────────────────────────────┐
        │  Каскад (AI_PROVIDER_ORDER):         │
        │  Groq → AITUNNEL → OpenRouter → Gemini│
        │  (провайдер без ключа пропускается)  │
        └─────────────────────────────────────┘
```

> С 21.06 обе витрины идут через backend-каскад. Бот шлёт собранный в n8n промпт в `/api/v1/ai/chat`; PWA — в `/api/v1/ai/ask`. Один источник fallback — `providers/`.

---

## 2. КОМПОНЕНТЫ

### 2.1. providers/ — Единый AI-слой

#### `providers/__init__.py`
Точка входа. Экспортирует только `ask()`.

#### `providers/ai.py` — Оркестратор
- Принимает `prompt`, `system`, `max_tokens`, `temperature`
- Порядок берётся из `AI_PROVIDER_ORDER` (env), дефолт `groq,aitunnel,openrouter,gemini`
- `REGISTRY` сопоставляет имя → (функция, имя env-ключа); провайдер **без ключа пропускается** молча
- Логирует попытки/латентность/ошибки, возвращает первый непустой ответ или FALLBACK_MESSAGE

#### `providers/groq.py` — Провайдер Groq (основной)
- Ультрабыстрый inference, бесплатный tier
- Модель по умолчанию: `llama-3.3-70b-versatile`
- Тот же движок, что у live-бота в n8n

#### `providers/aitunnel.py` — Провайдер AITUNNEL (резерв 1)
- Российский OpenAI-совместимый прокси (`api.aitunnel.ru/v1`), оплата в рублях
- Один ключ → модели OpenAI / Anthropic / Google / DeepSeek
- Модель по умолчанию: `gpt-4o-mini`; базовый URL из `AITUNNEL_BASE_URL`

#### `providers/openrouter.py` — Провайдер OpenRouter (резерв 2)
- Единый API для любых моделей (Claude, Llama, Gemini)
- Модель по умолчанию: `google/gemini-2.0-flash-exp:free`

#### `providers/gemini.py` — Провайдер Gemini (финальный резерв)
- Прямой вызов через REST API, бесплатный free-tier (~1500 req/день)
- Поддержка `gemini-2.0-flash` и других моделей
- Обработка 429 (rate limit), 503 (недоступен)

---

## 3. ПОСЛЕДОВАТЕЛЬНОСТЬ РАБОТЫ

### 3.1. Порядок вызовов (дефолт `AI_PROVIDER_ORDER=groq,aitunnel,openrouter,gemini`)

1. **Groq** (основной, бесплатный)
   - Если ответ получен → вернуть пользователю
   - Если ошибка 429/503/timeout → перейти к #2

2. **AITUNNEL** (резерв 1, ₽)
   - Если ответ получен → вернуть пользователю
   - Если ошибка → перейти к #3

3. **OpenRouter** (резерв 2, $)
   - Если ответ получен → вернуть пользователю
   - Если ошибка → перейти к #4

4. **Gemini** (финальный резерв, бесплатный)
   - Если ответ получен → вернуть пользователю
   - Если ошибка → вернуть FALLBACK_MESSAGE

> Любой провайдер без ключа в ENV **пропускается автоматически** — цепочка подстраивается под то, что реально подключено.

### 3.2. Критерии переключения

| Код/Ошибка | Действие |
|------------|----------|
| HTTP 429 | Переход к следующему провайдеру |
| HTTP 503 | Переход к следующему провайдеру |
| Timeout > 30s | Переход к следующему провайдеру |
| HTTP 401/403 | Переход к следующему провайдеру |
| Ошибка JSON | Переход к следующему провайдеру |
| Пустой ответ | Переход к следующему провайдеру |

---

## 4. ТОЧКИ ОТКАЗА

### 4.1. Полная схема отказов

```
User Request
    ↓
┌──────────────────────────────────────────┐
│ 1. Telegram Bot (n8n Cloud)              │ ← Single point of failure
│    Если падает — бот не отвечает         │
└──────────────────────────────────────────┘
    ↓
┌──────────────────────────────────────────┐
│ 2. Backend API (Docker)                  │ ← Single point of failure
│    Если падает — приложение не работает   │
└──────────────────────────────────────────┘
    ↓
┌──────────────────────────────────────────┐
│ 3. Supabase                              │ ← Single point of failure
│    Если падает — останов всего            │
└──────────────────────────────────────────┘
```

### 4.2. AI-отказы (улучшено)

```
User Message
    ↓
┌────────────────────────────────────────────────┐
│ 1. Groq API (основной, бесплатный) ✅           │
│    Ошибки: 429, 503, timeout, 401, empty        │
│    Если ошибка → Переход к #2                   │
└────────────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────────────┐
│ 2. AITUNNEL (резерв 1, ₽) ✅                     │
│    Ошибки: 429, 503, timeout, empty             │
│    Если ошибка → Переход к #3                   │
└────────────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────────────┐
│ 3. OpenRouter ($, резерв 2) ⏳ ждёт оплаты       │
│    Если ошибка → Переход к #4                   │
└────────────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────────────┐
│ 4. Gemini (финальный резерв) ⏳ перевыпустить ключ│
│    Если ошибка → Fallback-сообщение             │
└────────────────────────────────────────────────┘
    ↓
return FALLBACK_MESSAGE
```

---

## 5. КОНФИГУРАЦИЯ

### 5.1. ENV переменные

```env
# ─── AI Fallback Chain ─────────────────────────────────
AI_PROVIDER_ORDER=groq,aitunnel,openrouter,gemini

GROQ_API_KEY=              # основной (бесплатный)
GROQ_MODEL=llama-3.3-70b-versatile

AITUNNEL_API_KEY=          # резерв 1 (₽)
AITUNNEL_MODEL=gpt-4o-mini
AITUNNEL_BASE_URL=https://api.aitunnel.ru/v1

OPENROUTER_API_KEY=        # резерв 2 ($)
OPENROUTER_MODEL=google/gemini-2.0-flash-exp:free

GEMINI_API_KEY=            # финальный резерв (бесплатный)
GEMINI_MODEL=gemini-2.0-flash
```

### 5.2. Приоритет (по умолчанию)

```
1. Groq        (бесплатный, основной)
2. AITUNNEL    (₽, резерв 1)
3. OpenRouter  ($, резерв 2)
4. Gemini      (бесплатный, финальный резерв)
```

Порядок меняется через env `AI_PROVIDER_ORDER` (без правки кода). Новый провайдер добавляется в `REGISTRY` в `providers/ai.py`.

---

## 6. БЕЗОПАСНОСТЬ

### 6.1. Ключи API
- Все ключи хранятся только в `.env` файле
- `.env` в `.gitignore`
- Никакие ключи не логируются
- Доступ только через environment variables

### 6.2. Защита от утечек
- Ключи не передаются в ответы API
- Ключи не логируются
- Используется `os.getenv()` с дефолтом `""`
- Проверка наличия ключа перед вызовом

---

## 7. МОНИТОРИНГ

### 7.1. Логирование

Формат логов:
```
[AI] Trying provider: gemini
[AI] gemini responded in 1234ms
[AI] Provider openrouter failed: Rate limited: 429
[AI] All providers failed: gemini(RuntimeError), openrouter(RuntimeError), groq(RuntimeError)
```

### 7.2. Где смотреть

```bash
# Backend
docker compose logs kote-backend -f

# Bot (если включен)
docker compose logs kote-bot -f

# n8n
docker compose logs kote-n8n -f
```

---

## 8. ТЕСТИРОВАНИЕ

### 8.1. Юнит-тесты (рекомендуется)

```python
# tests/test_providers.py
import pytest
from providers import ai

@pytest.mark.asyncio
async def test_gemini():
    reply = await ai.ask("Привет!", system="Ты — КотЭ")
    assert reply

@pytest.mark.asyncio
async def test_fallback():
    # Имитация падения Gemini
    ...
```

### 8.2. Интеграционное тестирование

```bash
# Проверка импортов
python -c "from providers import ask; print('OK')"

# Проверка синтаксиса
python -m py_compile providers/*.py

# Проверка docker
docker compose build kote-backend
docker compose config
```

---

## 9. ОБНОВЛЕНИЯ И ПОДДЕРЖКА

### 9.1. Добавление нового провайдера

1. Создать `providers/newprovider.py`:
```python
async def call_newprovider(prompt, system, max_tokens, temperature):
    # Реализация
    pass
```

2. Добавить в `REGISTRY` в `providers/ai.py`:
```python
from .newprovider import call_newprovider
REGISTRY = {
    "groq": (call_groq, "GROQ_API_KEY"),
    "aitunnel": (call_aitunnel, "AITUNNEL_API_KEY"),
    "openrouter": (call_openrouter, "OPENROUTER_API_KEY"),
    "gemini": (call_gemini, "GEMINI_API_KEY"),
    "newprovider": (call_newprovider, "NEWPROVIDER_API_KEY"),  # Новый
}
```
3. Включить в цепочку через env: `AI_PROVIDER_ORDER=groq,aitunnel,newprovider,...`

### 9.2. Изменение порядка провайдеров

Отредактировать env `AI_PROVIDER_ORDER` (перечислить имена через запятую). Код менять не нужно.

### 9.3. Обновление моделей

Изменить ENV переменные:
```env
GEMINI_MODEL=gemini-2.0-flash
OPENROUTER_MODEL=google/gemini-2.0-flash-exp:free
GROQ_MODEL=llama-3.3-70b-versatile
```

---

## 10. ПРОИЗВОДИТЕЛЬНОСТЬ

### 10.1. Задержки

- **Gemini:** ~500-2000ms
- **OpenRouter:** ~1000-3000ms
- **Groq:** ~100-500ms (самый быстрый)

### 10.2. Timeout

- Каждый провайдер: 30s
- Максимальная задержка при полном fallback: ~90s
- Рекомендуется: показать "загрузку" пользователю

### 10.3. Рекомендации

- Использовать `asyncio` для параллельных операций (уже реализовано)
- Кэшировать частые запросы (Redis, в будущем)
- Мониторить latency в production

---

## 11. ОТКАТ (ROLLBACK)

### Сценарий 1: Критическая ошибка

```bash
# Откат к backup
cp app/backend/routers/ai.py.bak app/backend/routers/ai.py
cp platform/bot/main.py.bak platform/bot/main.py

# Перезапуск
docker compose build kote-backend
docker compose restart kote-backend
```

### Сценарий 2: Удаление providers/

```bash
rm -rf providers/
# Восстановить backup'ы конфигов
```

### Сценарий 3: Отключение fallback

В `app/backend/routers/ai.py` вместо:
```python
reply = await ai_ask(...)
```
Использовать:
```python
reply = await call_gemini_directly(...)
```

---

## 12. СТОИМОСТЬ

### 12.1. Тарифы (примерные)

| Провайдер | Модель | Стоимость за 1K токенов |
|------------|--------|------------------------|
| Gemini | gemini-2.0-flash | ~$0.0002-0.0004 |
| OpenRouter | google/gemini-2.0-flash-exp:free | Бесплатно |
| Groq | llama-3.3-70b-versatile | ~$0.0001 |

### 12.2. Оптимизация

- Использовать бесплатные модели в OpenRouter как резерв
- Groq — самый дешёвый для bulk-запросов
- Gemini — основной (баланс цена/качество)

---

## 13. БУДУЩИЕ УЛУЧШЕНИЯ

1. **Кэширование** — Redis для частых запросов
2. **Очередь** —Celery для фоновой обработки
3. **Метрики** — Prometheus + Grafana для мониторинга
4. **A/B тесты** — сравнение качества моделей
5. **Fine-tuning** — кастомная модель на основе диалогов
6. **Мультиязычность** — автоматическое определение языка

---

## 14. ИНТЕГРАЦИЯ С CI/CD

### 14.1. GitHub Actions (рекомендуется)

```yaml
name: Deploy AI Layer
on:
  push:
    paths:
      - 'providers/**'
      - 'app/backend/routers/ai.py'
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Test Python
        run: python -m py_compile providers/*.py
  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VPS
        run: ssh user@vps 'cd /path && docker compose build kote-backend && docker compose restart kote-backend'
```

---

## 15. КОНТАКТЫ

**Ответственный:** DevOps Team  
**Документация:** `docs/AI_ARCHITECTURE.md`  
**Исходный код:** `providers/`