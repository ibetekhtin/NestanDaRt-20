# DEV_TOOLS.md — Интеграция AI-инструментов разработки
> Проект: Нестандартный Отдых® / КотЭ
> Обновлено: 2026-06-20

---

## 🎯 Цель

Единая конфигурация AI для всех инструментов разработки проекта.

---

## 🛠️ Инструменты

### 1. Cline (VS Code Extension)

Cline — AI-агент в VS Code, работает с любым OpenAI-совместимым API.

**Подключение к AITUNNEL:**

1. Открыть VS Code → Settings → Extensions → Cline
2. Настроить API Provider:
   - **Provider:** OpenAI Compatible
   - **Base URL:** `https://api.aitunnel.ru/v1`
   - **API Key:** `sk-REDACTED`
   - **Model:** `gemini-2.5-flash` (или `gpt-4o-mini`, `deepseek-chat`)

**Альтернатива — Groq (бесплатно, быстро):**
   - **Provider:** OpenAI Compatible
   - **Base URL:** `https://api.groq.com/openai/v1`
   - **API Key:** из `.env` → `GROQ_API_KEY`
   - **Model:** `llama-3.3-70b-versatile`

**Альтернатива — OpenRouter:**
   - **Provider:** OpenAI Compatible
   - **Base URL:** `https://openrouter.ai/api/v1`
   - **API Key:** из `.env` → `OPENROUTER_API_KEY`
   - **Model:** `google/gemini-2.5-flash-lite`

---

### 2. Claude Code (CLI)

Claude Code — AI-агент в терминале от Anthropic.

**Подключение к AITUNNEL:**

Claude Code работает через Anthropic API. Для использования AITUNNEL:

1. Настроить переменные окружения:
   ```bash
   export ANTHROPIC_BASE_URL=https://api.aitunnel.ru/v1
   export ANTHROPIC_API_KEY=sk-REDACTED
   ```

2. Или добавить в `~/.bashrc`:
   ```bash
   echo 'export ANTHROPIC_BASE_URL=https://api.aitunnel.ru/v1' >> ~/.bashrc
   echo 'export ANTHROPIC_API_KEY=sk-REDACTED' >> ~/.bashrc
   source ~/.bashrc
   ```

**Примечание:** Claude Code может не поддерживать все модели AITUNNEL. Если не работает — использовать native Anthropic API с `ANTHROPIC_API_KEY`.

---

### 3. VS Code + GitHub Copilot

GitHub Copilot использует OpenAI API. Для подключения через AITUNNEL:

1. Установить расширение Continue (альтернатива Copilot)
2. Настроить в `.continue/config.json`:
   ```json
   {
     "models": [{
       "title": "AITUNNEL Gemini",
       "provider": "openai",
       "model": "gemini-2.5-flash",
       "apiBase": "https://api.aitunnel.ru/v1",
       "apiKey": "sk-REDACTED"
     }]
   }
   ```

---

## 📋 Матрица совместимости

| Инструмент | AITUNNEL | Groq | OpenRouter | Gemini Direct |
|------------|----------|------|------------|---------------|
| Cline | ✅ | ✅ | ✅ | ❌ |
| Claude Code | ⚠️ | ❌ | ❌ | ❌ |
| VS Code Continue | ✅ | ✅ | ✅ | ❌ |
| GitHub Copilot | ❌ | ❌ | ❌ | ❌ |

**Примечания:**
- ✅ = работает через OpenAI-совместимый API
- ⚠️ = может потребоваться настройка
- ❌ = не поддерживается напрямую

---

## 🔧 Общие ENV-переменные

Для всех инструментов используются одинаковые ключи из `/opt/kote/.env`:

```bash
# Основной провайдер (AITUNNEL)
AITUNNEL_API_KEY=sk-REDACTED
AITUNNEL_MODEL=gemini-2.5-flash

# Запасной провайдер (Groq)
GROQ_API_KEY=gsk_REDACTED
GROQ_MODEL=llama-3.3-70b-versatile

# Третий провайдер (OpenRouter)
OPENROUTER_API_KEY=sk-REDACTED
OPENROUTER_MODEL=google/gemini-2.5-flash-lite

# Аварийный провайдер (Gemini)
GEMINI_API_KEY=AQ.REDACTED
GEMINI_MODEL=gemini-2.0-flash
```

---

## 💡 Рекомендации

1. **Для Cline** — используйте AITUNNEL как основной (российский, стабильный)
2. **Для Claude Code** — используйте native Anthropic API (если AITUNNEL не работает)
3. **Для быстрых задач** — Groq (бесплатный, ultra-fast)
4. **Для веб-поиска** — OpenRouter с `:online` суффиксом

---

*Документ создан 2026-06-20. Обновлять при изменении конфигурации инструментов.*