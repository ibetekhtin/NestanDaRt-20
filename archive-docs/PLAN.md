# PLAN.md
## План внедрения AI Layer для проекта «Нестандартный Отдых»
**Дата:** 2025-06-18

---

## 1. ЦЕЛЬ

Создать надёжный AI-слой с fallback chain: **Gemini → OpenRouter → Groq**

---

## 2. ПРИНЦИПЫ

- Минимум лишнего
- Максимальная простота
- Минимальные изменения в существующий код
- Все ключи только через ENV

---

## 3. СТРУКТУРА ИЗМЕНЕНИЙ

### 3.1. Новый модуль `providers/`

```
providers/
  __init__.py
  ai.py          # Единый интерфейс для AI
  gemini.py      # Gemini провайдер
  openrouter.py  # OpenRouter провайдер  
  groq.py        # Groq провайдер
```

**Назначение:**
- Единый API для вызова AI, независимо от провайдера
- Fallback chain автоматически
- Обработка ошибок и retry-логика

### 3.2. Обновление `.env.example`

Добавить переменные:
```env
# ─── AI Fallback Chain ─────────────────────────────────────────
GEMINI_API_KEY=your_gemini_key
OPENROUTER_API_KEY=your_openrouter_key
GROQ_API_KEY=your_groq_key
```

### 3.3. Обновление `app/backend/config.py`

Добавить в `Settings`:
```python
OPENROUTER_API_KEY: str = ""
GROQ_API_KEY: str = ""
```

### 3.4. Обновление `app/backend/routers/ai.py`

Заменить прямой вызов Gemini на вызов `providers.ai.ask()`

### 3.5. Обновление `platform/bot/main.py`

Заменить прямые вызовы Gemini на вызов `providers.ai.ask()`

---

## 4. ПОЭТАПНЫЙ ПЛАН

### ЭТАП 1: Подготовка (5 мин)
1. Backup текущих файлов:
   - `app/backend/routers/ai.py` → `app/backend/routers/ai.py.bak`
   - `platform/bot/main.py` → `platform/bot/main.py.bak`
   - `.env.example` → `.env.example.bak`
   - `app/backend/config.py` → `app/backend/config.py.bak`

### ЭТАП 2: Создание AI Layer (15 мин)
1. Создать директорию `providers/`
2. Создать `providers/__init__.py`
3. Создать `providers/ai.py` с fallback chain
4. Создать `providers/gemini.py`
5. Создать `providers/openrouter.py`
6. Создать `providers/groq.py`

### ЭТАП 3: Интеграция (10 мин)
1. Обновить `app/backend/config.py`
2. Обновить `app/backend/routers/ai.py`
3. Обновить `platform/bot/main.py`
4. Обновить `.env.example`

### ЭТАП 4: Документация (5 мин)
1. Создать `docs/AI_ARCHITECTURE.md`
2. Создать `docs/AI_INTEGRATION.md`

### ЭТАП 5: Тестирование (10 мин)
1. Проверить импорты
2. Проверить синтаксис Python
3. Проверить docker-compose config
4. Dry-run: `docker compose config`

### ЭТАП 6: Деплой (5 мин)
1. Пересобрать backend: `docker compose build kote-backend`
2. Перезапустить: `docker compose up -d`
3. Проверить логи: `docker compose logs kote-backend`

---

## 5. ТЕХНИЧЕСКИЕ ОПИСАНИЯ

### 5.1. providers/ai.py — интерфейс

```python
from typing import Optional

async def ask(
    prompt: str,
    system: str = "",
    max_tokens: int = 600,
    temperature: float = 0.85
) -> str:
    """
    Универсальный вызов AI с fallback chain.
    Возвращает текст ответа или fallback-сообщение.
    """
```

### 5.2. providers/gemini.py

```python
import httpx
import os

async def call(prompt: str, system: str) -> str:
    # Прямой вызов Gemini REST API
    # Обработка ошибок 429, 503
    pass
```

### 5.3. providers/openrouter.py

```python
import httpx
import os

async def call(prompt: str, system: str) -> str:
    # Вызов через OpenRouter API
    # Любая модель (gemini, claude, llama через OpenRouter)
    pass
```

### 5.4. providers/groq.py

```python
import httpx
import os

async def call(prompt: str, system: str) -> str:
    # Вызов через Groq API
    # Llama 3/4 ultra-fast
    pass
```

---

## 6. ПОСЛЕДОВАТЕЛЬНОСТЬ ВЫЗОВОВ

```
providers.ai.ask(prompt, system)
    ↓
[1] providers.gemini.call(prompt, system)
    ↓ (если ошибка)
[2] providers.openrouter.call(prompt, system)
    ↓ (если ошибка)
[3] providers.groq.call(prompt, system)
    ↓ (если ошибка)
return "🐾 Извини, я немного перегружен. Напиши чуть позже!"
```

---

## 7. КОНФИГУРАЦИЯ

### 7.1. ENV переменные

```env
# Обязательные (минимум один):
GEMINI_API_KEY=
OPENROUTER_API_KEY=
GROQ_API_KEY=

# Опциональные (если нужно переопределить модель):
GEMINI_MODEL=gemini-2.0-flash
OPENROUTER_MODEL=google/gemini-2.0-flash-exp:free
GROQ_MODEL=llama-3.3-70b-versatile

# Включение/выключение провайдеров (опционально):
ENABLE_GEMINI=true
ENABLE_OPENROUTER=true
ENABLE_GROQ=true
```

### 7.2. Приоритет (по умолчанию)

1. Gemini (основной)
2. OpenRouter (резерв 1)
3. Groq (аварийный)

Можно изменить через ENV при необходимости.

---

## 8. ПОРЯДОК ПЕРЕКЛЮЧЕНИЯ

### Триггеры переключения:
1. **HTTP 429** — превышен лимит запросов
2. **HTTP 503** — сервис недоступен
3. **Timeout > 30s** — долгий ответ
4. **HTTP 401/403** — неверный ключ
5. **Любая ошибка JSON** — невалидный ответ

### Алгоритм:
```
try:
    response = current_provider.call()
    if is_error(response):
        raise ProviderError
    return response
except ProviderError:
    next_provider = get_next()
    if next_provider:
        return await next_provider.call()
    else:
        return FALLBACK_MESSAGE
```

---

## 9. ФАЛЛБЭК-СООБЩЕНИЯ

**Для пользователя:**
```
🐾 Секунду, я немного перегружен.
Попробуй ещё раз через минуту — Reflect точно помогу!
```

**Для логов:**
```
[AI] All providers failed: Gemini(429), OpenRouter(timeout), Groq(503)
```

---

## 10. РИСКИ И МИТИГАЦИЯ

| Риск | Вероятность | Влияние | Митигация |
|------|-------------|---------|-----------|
| Все 3 провайдера упадут одновременно | Низкая | Критическое | Fallback-сообщение пользователю |
| Утечка API ключей | Низкая | Критическое | Только ENV, .env в .gitignore |
| Сбой в логике fallback | Средняя | Среднее | Unit-тесты на каждый провайдер |
| Задержки из-за последовательных вызовов | Средняя | Среднее | Timeout 30s на каждый провайдер |

---

## 11. ОТКАТ (ROLLBACK)

### Сценарий 1: Критическая ошибка после деплоя

```bash
# Откат к backup
cp app/backend/routers/ai.py.bak app/backend/routers/ai.py
cp platform/bot/main.py.bak platform/bot/main.py
cp app/backend/config.py.bak app/backend/config.py

# Пересборка
docker compose build kote-backend
docker compose restart kote-backend
```

### Сценарий 2: Провайдеры не работают

```bash
# Временно отключить fallback chain в ai.py:
# Вместо: reply = await ai.ask(...)
# Использовать: reply = await call_gemini_directly(...)
```

### Сценарий 3: Удалить providers/ полностью

```bash
rm -rf providers/
# Восстановить backup'ы
```

---

## 12. ЧЕК-ЛИСТ ПЕРЕД ДЕПЛОЕМ

- [ ] Backup всех изменяемых файлов
- [ ] Код проходит синтаксис Python (можно проверить `python -m py_compile`)
- [ ] Docker Compose config валиден: `docker compose config`
- [ ] Все ENV переменные задокументированы в `.env.example`
- [ ] Логика fallback протестирована (можно unit-тест)
- [ ] Мониторинг: где смотреть логи (`docker compose logs kote-backend`)

---

## 13. РЕСУРСЫ НА ИЗМЕНЕНИЯ

### Код:
- Новые файлы: 4 (`providers/*.py`)
- Изменённые файлы: 4 (`ai.py`, `main.py`, `config.py`, `.env.example`)

### Размер:
- ~200 строк нового кода
- ~30 строк изменённого кода

### Время внедрения:
- Написание кода: 15 мин
- Интеграция: 10 мин
- Тестирование: 10 мин
- Итого: ~35 минут

---

## 14. СЛЕДУЮЩИЕ ШАГИ

1. Утвердить план
2. Создать providers/ модуль
3. Интегрировать в backend и бота
4. Протестировать
5. Задеплоить
6. Создать документацию

---

## ПОДГОТОВКА К ПОДПИСИ

- [x] План создан
- [ ] Ожидает подтверждения пользователя
- [ ] После подтверждения → START IMPLEMENTATION

**Критически:** Никаких изменений до явного "START IMPLEMENTATION"