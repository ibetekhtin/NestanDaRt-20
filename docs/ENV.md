# 🔑 Environment Variables — KOTЭ SYSTEM

## Required

| Variable | Description | Example |
|----------|-------------|---------|
| `SUPABASE_URL` | Supabase project URL | `https://xxx.supabase.co` |
| `SUPABASE_SERVICE_KEY` | Supabase service_role key (bot/backend) | `eyJ...` |
| `SUPABASE_ANON_KEY` | Supabase anon key (website) | `eyJ...` |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot API token | `123456:ABC...` |
| `GROQ_API_KEY` | Groq API key — основной AI (live-бот + backend) | `gsk_...` |
| `MANAGER_CHAT_ID` | Telegram chat ID менеджера | `8943048058` |

## AI Fallback Chain (backend `providers/`)

Порядок перебора задаётся `AI_PROVIDER_ORDER`. Провайдер без ключа пропускается.

| Variable | Default | Description |
|----------|---------|-------------|
| `AI_PROVIDER_ORDER` | `groq,aitunnel,openrouter,gemini` | Порядок перебора провайдеров |
| `GROQ_API_KEY` | — | Groq (основной, бесплатный). Тот же ключ читает live-бот в n8n (`$env.GROQ_API_KEY`) |
| `GROQ_MODEL` | `llama-3.3-70b-versatile` | Модель Groq |
| `AITUNNEL_API_KEY` | — | AITUNNEL (резерв 1, ₽). aitunnel.ru |
| `AITUNNEL_MODEL` | `gpt-4o-mini` | Модель AITUNNEL |
| `AITUNNEL_BASE_URL` | `https://api.aitunnel.ru/v1` | OpenAI-совместимый endpoint |
| `OPENROUTER_API_KEY` | — | OpenRouter (резерв 2, $) |
| `OPENROUTER_MODEL` | `google/gemini-2.0-flash-exp:free` | Модель OpenRouter |
| `GEMINI_API_KEY` | — | Gemini (финальный резерв, бесплатный) |
| `GEMINI_MODEL` | `gemini-2.0-flash` | Модель Gemini |

## Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKEND_PORT` | `8000` | FastAPI port |
| `N8N_HOST` | `http://localhost:5678` | n8n base URL |
| `BOT_LOG_LEVEL` | `info` | Log level (debug/info/warn/error) |

## Security Notes

- `SUPABASE_SERVICE_KEY` — **никогда** не публикуй, обходит RLS
- `TELEGRAM_BOT_TOKEN`, `GROQ_API_KEY` и прочие AI-ключи — **никогда** не публикуй (в т.ч. в чате)
- `.env` в `.gitignore` — не коммить. Секреты живут только в `.env` (локально) и env контейнеров на VPS
- Новый ключ на VPS: вписать в `/opt/kote/.env`, затем `docker compose up -d <service>` (recreate, не restart)