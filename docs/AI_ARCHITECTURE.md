# AI_ARCHITECTURE.md — Схема AI-инфраструктуры
> Проект: Нестандартный Отдых® / КотЭ
> Обновлено: 2026-06-20

---

## 🎯 Цель

Надёжный AI-слой для Telegram-бота КотЭ с автоматическим переключением между провайдерами при сбоях.

**Принцип:** минимум лишнего, максимум надёжности.

---

## 🔄 Схема работы (Fallback Chain)

```
┌─────────────────────────────────────────────────────────────┐
│                    ЗАПРОС ОТ КЛИЕНТА                         │
│              (Telegram → n8n → AI Router)                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │   1. AITUNNEL (primary) │  ← российский агрегатор
              │   gemini-2.5-flash      │     216+ моделей
              │   api.aitunnel.ru       │     600₽ на балансе
              └────────────┬───────────┘
                           │ ✗ ошибка / timeout
                           ▼
              ┌────────────────────────┐
              │   2. GROQ (backup 1)    │  ← бесплатный, ultra-fast
              │   llama-3.3-70b         │     llama-3.3-70b-versatile
              │   api.groq.com          │     ~500ms latency
              └────────────┬───────────┘
                           │ ✗ ошибка / timeout
                           ▼
              ┌────────────────────────┐
              │   3. OPENROUTER (backup 2) │  ← международный
              │   gemini-2.5-flash-lite │     openrouter.ai
              │   openrouter.ai/api     │     веб-поиск (:online)
              └────────────┬───────────┘
                           │ ✗ ошибка / timeout
                           ▼
              ┌────────────────────────┐
              │   4. GEMINI (emergency) │  ← прямой API Google
              │   gemini-2.0-flash      │     aistudio.google.com
              │   generativelanguage   │     бесплатно
              └────────────┬───────────┘
                           │ ✗ все упали
                           ▼
              ┌────────────────────────┐
              │   FALLBACK MESSAGE      │
              │   "🐾 Секунду, я немного│
              │    перегружен..."       │
              └────────────────────────┘
```

---

## 📡 Провайдеры — детали

### 1. AITUNNEL (основной)

| Параметр | Значение |
|----------|----------|
| API Endpoint | `https://api.aitunnel.ru/v1/chat/completions` |
| Модель | `gemini-2.5-flash` (настраивается через ENV) |
| Файл | `providers/aitunnel.py` |
| ENV | `AITUNNEL_API_KEY`, `AITUNNEL_MODEL` |
| Стоимость | 600₽ на балансе |
| Преимущества | Российский сервис, 216+ моделей, OpenAI-совместимый |
| Риски | Платный — нужен баланс |

**Доступные модели (примеры):**
- `gemini-2.5-flash` — дёшево, быстро (по умолчанию)
- `gpt-4o-mini` — OpenAI, бюджетный
- `deepseek-chat` — DeepSeek, дёшево
- `claude-haiku-4.5` — Anthropic, бюджетный
- `gemini-2.5-pro` — Google, мощный

### 2. Groq (запасной 1)

| Параметр | Значение |
|----------|----------|
| API Endpoint | `https://api.groq.com/openai/v1/chat/completions` |
| Модель | `llama-3.3-70b-versatile` |
| Файл | `providers/groq.py` |
| ENV | `GROQ_API_KEY`, `GROQ_MODEL` |
| Стоимость | Бесплатно (с лимитами) |
| Преимущества | Ultra-fast (~500ms), OpenAI-совместимый |
| Риски | Rate limits на бесплатном тарифе |

### 3. OpenRouter (запасной 2)

| Параметр | Значение |
|----------|----------|
| API Endpoint | `https://openrouter.ai/api/v1/chat/completions` |
| Модель | `google/gemini-2.5-flash-lite` |
| Файл | `providers/openrouter.py` |
| ENV | `OPENROUTER_API_KEY`, `OPENROUTER_MODEL` |
| Стоимость | Платный (баланс) |
| Преимущества | Веб-поиск (`:online`), любые модели |
| Риски | Международный — может быть заблокирован |

### 4. Gemini (аварийный)

| Параметр | Значение |
|----------|----------|
| API Endpoint | `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` |
| Модель | `gemini-2.0-flash` |
| Файл | `providers/gemini.py` |
| ENV | `GEMINI_API_KEY`, `GEMINI_MODEL` |
| Стоимость | Бесплатно (с лимитами) |
| Преимущества | Прямой API Google, не зависит от агрегаторов |
| Риски | Rate limits, другой формат API (не OpenAI-совместимый) |

---

## ⚡ Точки отказа и митигация

| Точка отказа | Вероятность | Влияние | Митигация |
|-------------|-------------|---------|-----------|
| AITUNNEL баланс = 0 | Средняя | Потеря основного провайдера | Автоматический fallback на Groq |
| AITUNNEL API down | Низкая | Временный сбой | Fallback на Groq |
| Groq rate limit | Средняя | Лимит запросов | Fallback на OpenRouter |
| Groq API down | Низкая | Временный сбой | Fallback на OpenRouter |
| OpenRouter заблокирован | Средняя | Недоступность | Fallback на Gemini |
| Gemini rate limit | Низкая | Лимит запросов | Fallback message |
| Все провайдеры упали | Очень низкая | Полный сбой AI | Клиент получает сообщение о перегрузке |
| VPS недоступен | Низкая | Всё падает | Мониторинг (UptimeRobot) |

---

## 🔧 Как добавить нового провайдера

1. Создать `providers/new_provider.py` с функцией `call_new_provider(prompt, system, max_tokens, temperature) -> str`
2. Добавить в `providers/ai.py`:
   - `from .new_provider import call_new_provider`
   - Добавить в список `PROVIDERS` на нужную позицию
3. Добавить ENV-переменные в `.env` и `.env.example`
4. Пересобрать бэкенд: `docker compose build kote-backend && docker compose up -d --force-recreate kote-backend`

---

## 📊 Мониторинг AI

### Логи

```bash
# Логи AI-вызовов (latency + fallback)
docker logs kote-backend --tail 100 | grep "\[AI\]"

# Пример вывода:
# [AI] Trying provider: aitunnel
# [AI] aitunnel responded in 1200ms
```

### Метрики для отслеживания

- **Latency** — время ответа каждого провайдера
- **Fallback rate** — как часто основной провайдер падает
- **Error rate** — количество ошибок по провайдерам

---

## 🔄 Порядок переключения (для оператора)

### Если нужно сменить основного провайдера

1. Изменить порядок в `providers/ai.py` (список `PROVIDERS`)
2. Обновить ENV-переменные в `.env`
3. Пересобрать: `docker compose build kote-backend && docker compose up -d --force-recreate kote-backend`
4. Проверить: `docker logs kote-backend --tail 20 | grep "\[AI\]"`

### Если нужно сменить модель

1. Изменить ENV-переменную (например, `AITUNNEL_MODEL=gpt-4o-mini`)
2. Перезапустить: `docker compose up -d --force-recreate kote-backend`
3. Проверить логи

---

## 💡 Рекомендации

1. **Мониторить баланс AITUNNEL** — основной провайдер платный
2. **Проверять лимиты Groq** — бесплатный тариф имеет ограничения
3. **Обновлять модели** — регулярно проверять новые версии
4. **Тестировать fallback** — периодически проверять работу цепочки
5. **Логировать latency** — для оптимизации выбора провайдера

---

*Документ создан 2026-06-20. Обновлять при изменении AI-инфраструктуры.*