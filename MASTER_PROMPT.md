# MASTER PROMPT — NestanDaRt-20
> Скопируй в начало следующей Claude Code сессии. Обновляй после каждого крупного изменения.

---

Ты работаешь над проектом **«Нестандартный Отдых»** — туристическая компания в Азии.
Рынки: **Пхукет (68 туров), Паттайя (53), Вьетнам (12)**. Бали и Дубай в БД.
Единственный KPI: **КПТ = Количество Проданных Туров**. Любое решение оценивается через этот фильтр.

## Архитектура (VPS 77.42.93.187, Ubuntu 22.04)

```
Telegram → n8n (nestandart-n8n, :5678) → FastAPI (nestandart-backend, :8000) → Supabase
Сайт: nestandart.online → nginx → /var/www/nestandart/
Штаб: baza.nestandart.online → nginx → React/Vite (hq/)
PWA:  app.nestandart.online → nginx → platform/app.html
```

- **Бот КотЭ** = n8n workflow `doCUKEZQpLQjDmxP`. НЕ запускать `nestandart-bot` через Docker.
- **AI каскад**: `groq → aitunnel → openrouter → gemini` (providers/). Провайдер без ключа пропускается.
- **Платежи**: YooKassa через `/api/v1/pay/create` (требует `X-Kote-Secret`).
- **Docker volumes**: `kote-n8n-data` — **НЕ ПЕРЕИМЕНОВЫВАТЬ** (там все workflows n8n).

## Репозиторий

- **GitHub**: `github.com/ibetekhtin/NestanDaRt-20`
- **Локально**: `/Users/soloplayer/Desktop/NestanDaRt-20/`
- **VPS**: `/opt/NestanDaRt-20/` (симлинк `/opt/kote → /opt/NestanDaRt-20` для совместимости)
- **Деплой**: `ssh root@77.42.93.187 "cd /opt/NestanDaRt-20 && git pull && docker compose build nestandart-backend && docker compose up -d"`

## Ключевые файлы

| Файл | Назначение |
|------|-----------|
| `CLAUDE.md` | Главный канон — читать перед любой работой |
| `docker-compose.yml` | Два сервиса: nestandart-backend, nestandart-n8n |
| `app/backend/` | FastAPI (9 роутеров: ai, bookings, clients, leads, markets, memory, payments, sos, tours) |
| `providers/` | AI fallback chain (groq, aitunnel, openrouter, gemini + общий openai_compat.py) |
| `platform/nestandart-20/prompt.txt` | Промпт-личность КотЭ |
| `platform/app.html` | PWA v11.0, self-contained |
| `hq/` | БАЗА (React Vite, baza.nestandart.online) |
| `deploy/healthcheck.sh` | Cron */5 мин — алерты в Telegram |

## Безопасность (применено в этой сессии)

- `/ai/chat`, `/pay/create`, `/bookings PATCH` требуют заголовок `X-Kote-Secret: <KOTE_RPC_SECRET>`
- `market_id` валидируется через `Literal["phuket","pattaya","vietnam","bali","dubai"]`
- UFW: открыты только 22, 80, 443. Порты 5678 и 8000 — только через nginx.
- Пароль к БАЗЕ убран из CLAUDE.md — хранится только в `.env`

## База данных (Supabase)

Ключевые таблицы: `markets`, `tours`, `clients`, `bookings`, `payments`, `knowledge`, `conversations`, `partners`, `referrals`

Ключевые RPC: `app_upsert_lead(...)`, `get_kote_context(p_tg_chat_id, p_query)`, `credit_referral(p_booking_id)`

## Запреты

- НЕ запускать `nestandart-bot` через Docker (бот в n8n)
- НЕ переименовывать volume `kote-n8n-data`
- НЕ открывать UFW порты 5678 и 8000
- НЕ коммитить `.env`
- НЕ менять `markets.id` ('phuket', 'pattaya', 'vietnam', 'bali', 'dubai')

## Проверка после изменений

```bash
ssh root@77.42.93.187 'cd /opt/NestanDaRt-20 && docker compose ps && curl -s http://localhost:8000/health'
```

## ЗАДАЧА СЛЕДУЮЩЕЙ СЕССИИ

> [ВСТАВЬ КОНКРЕТНУЮ ЗАДАЧУ СЮДА]

Приоритеты по КПТ:
1. Конверсия в оплату (YooKassa, /pay/create надёжность)
2. Вьетнам — запуск страницы продаж
3. Паттайя — страница продаж
4. PWA — расширить каталог (50+ туров из 133 активных)
5. Рефералы — автоматизация начисления
