# 🔑 Environment Variables — NestanDaRt-20

## Required

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | `https://your-project-id.supabase.co` |
| `SUPABASE_SERVICE_KEY` | service_role key — обходит RLS, не светить |
| `SUPABASE_ANON_KEY` | anon key (сайт, PWA) |
| `TELEGRAM_BOT_TOKEN` | токен @phuket_nestandart_bot |
| `TELEGRAM_ADMIN_CHAT_ID` | chat_id для алертов (= `MANAGER_CHAT_ID`) |
| `MANAGER_CHAT_ID` | chat_id менеджера для уведомлений о лидах |
| `KOTE_RPC_SECRET` | общий секрет n8n↔backend (защита /ai/chat, /pay/create, /bookings PATCH) |
| `GROQ_API_KEY` | основной AI (бесплатный, быстрый) |

## AI Fallback Chain

Порядок: `AI_PROVIDER_ORDER=groq,aitunnel,openrouter,gemini`. Провайдер без ключа — пропускается.

| Variable | Default |
|----------|---------|
| `AI_PROVIDER_ORDER` | `groq,aitunnel,openrouter,gemini` |
| `GROQ_API_KEY` | — |
| `GROQ_MODEL` | `llama-3.3-70b-versatile` |
| `AITUNNEL_API_KEY` | — |
| `AITUNNEL_MODEL` | `gemini-2.5-flash` |
| `OPENROUTER_API_KEY` | — |
| `OPENROUTER_MODEL` | `google/gemini-2.5-flash-lite` |
| `GEMINI_API_KEY` | — |
| `GEMINI_MODEL` | `gemini-2.5-flash` |

## YooKassa (платежи)

| Variable | Description |
|----------|-------------|
| `YOOKASSA_SHOP_ID` | ID магазина (без него платежи мягко отключены) |
| `YOOKASSA_SECRET_KEY` | секретный ключ магазина |
| `YOOKASSA_RETURN_URL` | `https://nestandart.online/` |
| `YOOKASSA_BAHT_TO_RUB` | `2.6` — курс ฿→₽ (правится без кода) |

## n8n

| Variable | Description |
|----------|-------------|
| `N8N_USER` | логин basic auth n8n |
| `N8N_PASSWORD` | пароль basic auth n8n |

## Security

- **Новый ключ на VPS:** `bash /opt/NestanDaRt-20/set-secret.sh VARNAME` → пересоздать контейнер `docker compose up -d nestandart-backend`
- `.env` в `.gitignore` — не коммитить
- `TELEGRAM_ADMIN_CHAT_ID` = `MANAGER_CHAT_ID` (один чат для простоты; можно разделить)
