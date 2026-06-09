# 🔑 Environment Variables — KOTЭ SYSTEM

## Required

| Variable | Description | Example |
|----------|-------------|---------|
| `SUPABASE_URL` | Supabase project URL | `https://xxx.supabase.co` |
| `SUPABASE_SERVICE_KEY` | Supabase service_role key (bot/backend) | `eyJ...` |
| `SUPABASE_ANON_KEY` | Supabase anon key (website) | `eyJ...` |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot API token | `123456:ABC...` |
| `GEMINI_API_KEY` | Google Gemini API key | `AIza...` |
| `MANAGER_CHAT_ID` | Telegram chat ID менеджера | `8943048058` |

## Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKEND_PORT` | `8000` | FastAPI port |
| `N8N_HOST` | `http://localhost:5678` | n8n base URL |
| `BOT_LOG_LEVEL` | `info` | Log level (debug/info/warn/error) |
| `GEMINI_MODEL` | `gemini-2.0-flash` | Gemini model |
| `GEMINI_MAX_TOKENS` | `600` | Max output tokens |

## Security Notes

- `SUPABASE_SERVICE_KEY` — **никогда** не публикуй, обходит RLS
- `TELEGRAM_BOT_TOKEN` — **никогда** не публикуй
- `.env` в `.gitignore` — не коммить