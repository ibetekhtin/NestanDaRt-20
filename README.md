# Нестандартный Отдых®

> Ваш маршрут. Ваш темп. Ваши правила.

## Структура

```
NestanDaRt-20/
├── nestandart-phuket/   — публичный сайт (HTML/CSS/JS → Vercel)
├── hq/                  — панель управления (React + Vite → Supabase)
├── platform/            — архитектура платформы
│   ├── docs/            — STACK, SUPABASE, MULTI_MARKET, ROADMAP, KOTE
│   ├── supabase/        — schema.sql (единый источник данных)
│   ├── kote/            — промпт и воркфлоу КотЭ
│   ├── bot/             — Telegram бот
│   ├── mobile/          — мобильное приложение
│   └── n8n/             — автоматизации
└── shared/              — общие константы (markets.js, brand.js)
```

## Принцип масштабирования

**Один бренд. Один код. Одна база данных. Много рынков.**

Новый рынок = новая строка в `markets`. Не новый проект.

| Рынок | Статус |
|-------|--------|
| 🏝️ Пхукет | ✅ Активен |
| 🌅 Паттайя | 🔜 Coming soon |
| 🌿 Бали | 📋 Planned |
| 🏙️ Дубай | 📋 Planned |

## Быстрый старт

### Сайт (локально)
```bash
cd nestandart-phuket
npx serve . -p 3000
```

### HQ-панель
```bash
cd hq
cp .env.example .env   # заполни Supabase ключи
npm install
npm run dev
```

### База данных
```bash
# Supabase Dashboard → SQL Editor
# Запустить: platform/supabase/schema.sql
```

## Документация

- [Стек](platform/docs/STACK.md)
- [Supabase](platform/docs/SUPABASE.md)
- [Multi-Market](platform/docs/MULTI_MARKET.md)
- [Роадмап](platform/docs/ROADMAP.md)
- [КотЭ](platform/docs/KOTE_SYSTEM.md)

## Репозитории

- Сайт: https://github.com/ibetekhtin/NestanDaRt-20
- Платформа: https://github.com/ibetekhtin/NON-STANDART-PHUKET
