# Нестандартный Отдых®

> Ваш маршрут. Ваш темп. Ваши правила.

**Монорепо.** Один бренд. Один код. Одна база. Много рынков.

## Карта системы

```
NestanDaRt-20/                       ← github.com/ibetekhtin/NestanDaRt-20
├── nestandart-phuket/   САЙТ        HTML/CSS/JS → VPS 77.42.93.187 (nginx + SSL)
├── hq/                  ШТАБ        React + Vite → Supabase (вход только для админа)
├── platform/            ПЛАТФОРМА
│   ├── kote/            🐾 КотЭ: prompt.txt (личность) + workflow.json (n8n)
│   ├── supabase/        schema.sql — справочник реальной схемы БД
│   └── docs/            STACK, SUPABASE, MULTI_MARKET, ROADMAP, KOTE_SYSTEM
└── shared/              константы рынков и бренда
```

## Где что живёт (источники истины)

| Что | Где | Как менять |
|-----|-----|-----------|
| Туры, цены, сезоны | Supabase → `tours` | SQL / HQ-панель. КотЭ подхватит сам |
| База знаний (84 записи) | Supabase → `knowledge` | SQL. КотЭ ищет по вопросу клиента |
| Клиенты, заявки, платежи | Supabase → `clients`, `bookings`, `payments` | через HQ или бота |
| Личность КотЭ | `platform/kote/prompt.txt` | правишь текст → импорт workflow в n8n |
| Контент сайта | `nestandart-phuket/*.html` | правка + git push (VPS подтянет за 5 мин) |
| Конфиг сайта (боты, города) | `nestandart-phuket/js/config.js` | правка + push |

**Supabase проект:** `cmmdrhususjuadqzyssc` (NON-STANDART)

## Архитектура КотЭ

```
Telegram → n8n → get_kote_context(chat_id, вопрос) → Supabase
                       ↓ один запрос отдаёт всё:
              память клиента + живой каталог туров + знания под вопрос
                       ↓
                 Gemini (личность из prompt.txt) → ответ
```

Новый тур или факт = insert в базу. Воркфлоу не трогается.

## Рынки

| Рынок | Статус |
|-------|--------|
| 🏝️ Пхукет | ✅ Активен (33 тура, 41 знание) |
| 🌅 Паттайя | 🟡 Туры и знания готовы, сайт «coming soon» |
| 🌿 Бали | 📋 Planned |
| 🏙️ Дубай | 📋 Planned |

## Быстрый старт

```bash
# Сайт локально
cd nestandart-phuket && npx serve . -p 3000

# ШТАБ
cd hq && npm install && npm run dev   # вход: админ-email + пароль

# КотЭ live: VPS /opt/kote (docker compose), мозг = n8n workflow kote-main
# Редактор n8n: ssh -L 5678:localhost:5678 root@VPS → http://localhost:5678
```

## Безопасность (что уже настроено)

- RLS: персональные данные читает только админ (email в JWT), anon — лишь публичное
- Сайт: HTTPS (Let's Encrypt, автопродление), HSTS, X-Frame-Options — в nginx на VPS
- БАЗА (ШТАБ): https://nestandart-phuket.ru/baza — вход только по админ-паролю, скрыта от поисковиков
- Секреты: только в `.env` (gitignore) и n8n credentials — в репо ничего нет
- КотЭ ходит в базу через SECURITY DEFINER RPC — у бота нет прямого доступа к таблицам

## Документация

[Стек](platform/docs/STACK.md) · [Supabase](platform/docs/SUPABASE.md) · [Multi-Market](platform/docs/MULTI_MARKET.md) · [Роадмап](platform/docs/ROADMAP.md) · [КотЭ](platform/docs/KOTE_SYSTEM.md)

## ⚠️ Что нужно для работы КотЭ

Мозг КотЭ (n8n → Gemini) подключён и активен, но требует **валидный Gemini API-ключ**:
1. Получить ключ на https://aistudio.google.com/apikey (формат `AIza...`)
2. На VPS: заменить строку `GEMINI_API_KEY=` в `/opt/kote/.env`
3. `cd /opt/kote && docker compose restart n8n`

Воркфлоу читает ключ через `$env.GEMINI_API_KEY` — править воркфлоу не нужно, только .env.
Текущий ключ невалиден (формат не `AIza`, отдаёт 401) — до замены КотЭ не отвечает.

## 🐾 КотЭ-бот: перенос с Railway на наш VPS

Код бота (@phuket_nestandart_bot, Python/aiogram + Claude) теперь в `platform/bot/`,
задеплоен как контейнер `kote-tg-bot` на VPS рядом со старым стеком.

**Чтобы запустить — впиши 2 секрета из Railway в `/opt/kote/bot/.env`:**
1. `TELEGRAM_BOT_TOKEN` — токен @phuket_nestandart_bot (Railway → Variables)
2. `ANTHROPIC_API_KEY` — ключ Claude (Railway → Variables)

Затем:
```bash
# 1. На Railway: остановить (Pause) деплой бота — иначе два инстанса
#    конфликтуют за getUpdates (Telegram отдаёт 409).
# 2. На VPS:
cd /opt/kote && docker compose up -d kote-tg-bot
docker logs -f kote-tg-bot   # увидеть "🐾 КотЭ (Python/Claude) запущен!"
```

Бот работает на polling (отдельный токен от @nestandart_phuket_bot — конфликта нет).
Что починено при переносе: `market`→`city` в поиске знаний (был баг — знания не находились),
память диалога (была заглушка `get_session(0)`), тёплый промпт-сердце.
