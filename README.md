# Нестандартный Отдых®

> Ваш маршрут. Ваш темп. Ваши правила.

**Монорепо.** Один бренд. Один код. Одна база. Много рынков.

## Карта системы

```
NestanDaRt-20/                       ← github.com/ibetekhtin/NestanDaRt-20
├── nestandart-phuket/   САЙТ        HTML/CSS/JS → Vercel (vercel.json = security)
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
| Контент сайта | `nestandart-phuket/*.html` | правка + git push (Vercel автодеплой) |
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

# КотЭ: n8n → Import from File → platform/kote/workflow.json
```

## Безопасность (что уже настроено)

- RLS: персональные данные читает только админ (email в JWT), anon — лишь публичное
- Сайт: HSTS, CSP, X-Frame-Options через `vercel.json`
- Секреты: только в `.env` (gitignore) и n8n credentials — в репо ничего нет
- КотЭ ходит в базу через SECURITY DEFINER RPC — у бота нет прямого доступа к таблицам

## Документация

[Стек](platform/docs/STACK.md) · [Supabase](platform/docs/SUPABASE.md) · [Multi-Market](platform/docs/MULTI_MARKET.md) · [Роадмап](platform/docs/ROADMAP.md) · [КотЭ](platform/docs/KOTE_SYSTEM.md)
