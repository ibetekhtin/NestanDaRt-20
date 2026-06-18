# AI_INTEGRATION.md
## Интеграция AI Layer с Cline, Claude Code и VS Code
**Версия:** 1.0  
**Дата:** 2025-06-18

---

## 1. Cline (VS Code Extension)

Cline — AI ассистент для VS Code, который использует различные LLM провайдеры.

### 1.1. Конфигурация Cline

**Файл:** `.vscode/settings.json` или настройки Cline в VS Code

```json
{
  "cline.apiProvider": "openrouter",
  "cline.openRouterApiKey": "${OPENROUTER_API_KEY}",
  "cline.openRouterModelId": "google/gemini-2.0-flash-exp:free",
  "cline.maxTokens": 2000,
  "cline.temperature": 0.7
}
```

### 1.2. Использование .env файла

Cline может читать переменные из `.env` файла в корне проекта.

**Настройка в VS Code:**
1. Откройте VS Code Settings (`Cmd+,`)
2. Найдите "Cline: Api Key"
3. Выберите "Use Environment Variable"
4. Укажите `OPENROUTER_API_KEY`

### 1.3. Преимущества

- ✅ Единый ключ с OpenRouter
- ✅ Возможность использовать любую модель через OpenRouter
- ✅ Fallback через Groq при проблемах с OpenRouter

---

## 2. Claude Code

Claude Code — CLI инструмент от Anthropic для разработки.

### 2.1. Конфигурация

**Файл:** `~/.claude/config.json`

```json
{
  "apiKey": "${ANTHROPIC_API_KEY}",
  "model": "claude-3-5-sonnet-20240620",
  "maxTokens": 2000,
  "temperature": 0.7
}
```

### 2.2. Интеграция с проектом

Claude Code работает независимо от AI Layer проекта, но может использовать те же ENV переменные.

**В `.env.example` добавить:**
```env
# Claude Code (опционально, для разработки)
ANTHROPIC_API_KEY=your_anthropic_key_here
```

### 2.3. Использование

```bash
# Запуск Claude Code в контексте проекта
claude --api-key $ANTHROPIC_API_KEY

# Или через ENV файл
export $(grep -v '^#' .env | xargs) && claude
```

---

## 3. VS Code + Copilot (опционально)

GitHub Copilot может работать вместе с Cline.

### 3.1. Конфигурация GitHub Copilot

**Файл:** `.vscode/settings.json`

```json
{
  "github.copilot.enable": {
    "*": true
  },
  "github.copilot.inlineSuggest.enable": true
}
```

### 3.2. Совместное использование с Cline

```json
{
  // Cline для сложных задач
  "cline.apiProvider": "openrouter",
  
  // Copilot для автодополнения кода
  "github.copilot.enable": true
}
```

---

## 4. ЕДИНАЯ КОНФИГУРАЦИЯ

### 4.1. Централизованный `.env` файл

Проект уже использует `.env` в корне. Все инструменты могут читать его:

```
.nevandart-otdykh/
├── .env                  # ← Все ключи здесь
├── .env.example          # ← Шаблон
├── .vscode/
│   └── settings.json     # ← VS Code + Cline
├── providers/            # ← AI Layer
├── app/
│   └── backend/
│       └── config.py     # ← Читает .env
└── platform/
    └── bot/
        └── main.py       # ← Читает .env
```

### 4.2. Чтение .env в разных инструментах

| Инструмент | Метод чтения |
|------------|--------------|
| Python (FastAPI) | `pydantic-settings` → автоматически |
| Python (Bot) | `os.getenv()` → вручную |
| Cline | Настройка VS Code → ENV переменная |
| Claude Code | CLI аргумент или `~/.claude/config.json` |
| npm scripts | `dotenv` пакет или `export $(cat .env)` |

---

## 5. ПРОВЕРКА ИНТЕГРАЦИИ

### 5.1. Проверка Python импортов

```bash
# Проверка providers модуля
python -c "from providers import ask; print('OK')"

# Проверка конфига
python -c "from config import settings; print(settings.GEMINI_API_KEY[:10])"

# Проверка backend
cd app/backend && python -c "from routers import ai; print('AI router OK')"
```

### 5.2. Проверка Docker

```bash
# Сборка образа
docker compose build kote-backend

# Проверка конфигурации
docker compose config

# Запуск
docker compose up -d

# Проверка логов
docker compose logs kote-backend -f
```

### 5.3. Проверка .env

```bash
# Проверка синтаксиса
cat .env | grep -v '^#' | grep '=' | wc -l

# Тест загрузки в Python
python -c "
import os
from dotenv import load_dotenv
load_dotenv()
print('GEMINI:', bool(os.getenv('GEMINI_API_KEY')))
print('OPENROUTER:', bool(os.getenv('OPENROUTER_API_KEY')))
print('GROQ:', bool(os.getenv('GROQ_API_KEY')))
"
```

---

## 6. БЕЗОПАСНОСТЬ

### 6.1. .gitignore

Убедитесь, что `.env` игнорируется:

```bash
cat .gitignore | grep -E '^\.env$'
```

Если нет — добавить:
```bash
echo ".env" >> .gitignore
```

### 6.2. Защита ключей

❌ **НЕЛЬЗЯ:**
- Коммитить `.env` в git
- Логировать ключи
- Передавать ключи в URL параметрах (кроме Gemini, это их API)
- Делиться ключами через мессенджеры

✅ **МОЖНО:**
- Хранить в `.env` файле
- Использовать ENV переменные в production
- Шерить `.env.example` без реальных ключей
- Использовать secrets管理器 (AWS Secrets, HashiCorp Vault) в production

---

## 7. WORKFLOW РАЗРАБОТКИ

### 7.1. Локальная разработка

```bash
# 1. Клонировать репозиторий
git clone <repo>
cd nestandart-otdykh

# 2. Создать .env из шаблона
cp .env.example .env

# 3. Заполнить ключи
# Открыть .env и заполнить GEMINI_API_KEY, OPENROUTER_API_KEY, GROQ_API_KEY

# 4. Установить зависимости
pip install -r app/backend/requirements.txt
pip install -r platform/bot/requirements.txt

# 5. Проверить импорты
python -c "from providers import ask; print('OK')"

# 6. Запустить backend
cd app/backend && uvicorn main:app --reload

# 7. Или запустить через Docker
docker compose up -d
```

### 7.2. Разработка в VS Code + Cline

1. Открыть проект в VS Code
2. Установить extension "Cline"
3. В настройках Cline указать:
   - API Provider: OpenRouter
   - API Key: `$OPENROUTER_API_KEY`
4. Использовать Cline для:
   - Генерации кода
   - Рефакторинга
   - Объяснения кода
   - Написания тестов

### 7.3. Переключение между инструментами

| Задача | Инструмент |
|--------|-----------|
| Написание кода | Cline + Claude Code |
| Рефакторинг | Claude Code |
| Коммиты | Claude Code (`git commit -m "..."`) |
| Тестирование | pytest + Claude Code |
| Деплой | deploy.sh + GitHub Actions |

---

## 8. ТРОУБЛЕШООТИНГ

### 8.1. Cline не читает .env

**Решение:**
- Перезапустить VS Code
- Проверить путь к `.env` (должен быть в корне workspace)
- Явно указать путь в настройках Cline

### 8.2. Claude Code не находит API ключ

**Решение:**
```bash
# Проверить переменную
echo $ANTHROPIC_API_KEY

# Установить
export ANTHROPIC_API_KEY=your_key

# Или добавить в ~/.bashrc / ~/.zshrc
echo 'export ANTHROPIC_API_KEY=your_key' >> ~/.zshrc
source ~/.zshrc
```

### 8.3. Python модуль providers не найден

**Решение:**
```bash
# Проверить __init__.py
ls providers/__init__.py

# Проверить PYTHONPATH
python -c "import sys; print(sys.path)"

# Добавить корень в PYTHONPATH
export PYTHONPATH=$PYTHONPATH:$(pwd)
```

### 8.4. Docker не видит .env переменные

**Решение:**
```bash
# Проверить docker-compose.yml
grep env_file docker-compose.yml

# Проверить права
ls -la .env

# Проверить синтаксис
docker compose config
```

---

## 9. РЕКОМЕНДАЦИИ

### 9.1. Для разработчиков

1. **Используйте Cline** для:
   - Быстрого написания кода
   - Рефакторинга
   - Генерации тестов

2. **Используйте Claude Code** для:
   - Сложных архитектурных решений
   - Написания документации
   - Анализа кода

3. **Используйте Git + GitHub Actions** для:
   - Автоматического деплоя
   - Тестирования
   - Бэкапов

### 9.2. Для продакшена

1. **Мониторинг:**
   - Логировать все AI вызовы
   - Отслеживать latency
   - Алерты при fallback

2. **Безопасность:**
   - Ротация ключей раз в 90 дней
   - Разные ключи для dev/prod
   - Ограничение IP для API ключей (если возможно)

3. **Производительность:**
   - Кэширование (Redis)
   - Очереди (Celery)
   - CDN для статики

---

## 10. ССЫЛКИ

- **Cline:** https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev
- **Claude Code:** https://docs.anthropic.com/claude/docs/claude-code
- **OpenRouter:** https://openrouter.ai/docs
- **Gemini:** https://ai.google.dev/docs
- **Groq:** https://console.groq.com/docs

---

## 11. КОНТАКТЫ

**Вопросы по интеграции:** DevOps Team  
**Документация:** `docs/AI_INTEGRATION.md`  
**Исходный код:** `providers/`