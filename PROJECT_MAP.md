# КАРТА ПРОЕКТА «Нестандартный Отдых®»
> Создано: 2026-06-28 · Актуализировано: 2026-07-02 (полный аудит системы; видение — docs/VISION.md)

---

## 1. ЧТО ЭТО ЗА ПРОЕКТ

**Нестандартный Отдых®** — туристическая платформа для продажи классических экскурсий. Сейчас фокус — только Пхукет (Паттайя и Вьетнам в архиве), цель — весь мир (docs/VISION.md).  
Главный KPI: **КПТ = Количество Проданных Туров**.

**Бизнес-модель:**  
Клиент → Telegram-бот КотЭ (AI) → подбор тура → менеджер закрывает сделку → оплата → экскурсия.

**Золотой треугольник продаж:**
- **Бот (КотЭ)** — универсальный, знает всё, может всё
- **Сайт** — стандартный каталог, SEO-трафик
- **PWA-приложение** — 50+ туров, личный кабинет

---

## 2. АРХИТЕКТУРА

```
┌─────────────────────────────────────────────────────────────────┐
│                    КЛИЕНТ                                       │
│  Telegram  /  Сайт nestandart.online  /  app.nestandart.online  │
└────────────────────┬────────────────────────────────────────────┘
                      │
          ┌───────────▼──────────┐
          │    nginx (reverse    │  VPS 77.42.93.187
          │    proxy + SSL)      │  Ubuntu 22.04
          └──┬──────────┬────────┘
             │          │
    ┌────────▼──┐  ┌────▼──────────────────┐
    │  FastAPI  │  │  n8n (self-hosted)     │
    │  backend  │  │  n8n.nestandart.online │
    │  :8000    │  │  :5678                 │
    └────────┬──┘  └────────┬───────────────┘
             └───────┬───────┘
                     │
          ┌──────────▼──────────┐
          │  Supabase (Cloud)   │
          │  PostgreSQL + Auth  │
          └─────────────────────┘
```

---

## 3. СТРУКТУРА ПРОЕКТА

```
NestanDaRt-20/
├── CLAUDE.md                  ← ГЛАВНЫЙ КАНОН (читать перед любой работой)
├── MASTER_PROMPT.md           ← Промпт для AI-сессий
├── README.md                  ← Краткая инструкция
├── docker-compose.yml         │
├── docker-compose.override.yml│
├── .env                       ← СЕКРЕТЫ (НЕ коммитить!)
├── .env.example               ← Шаблон
│
├── app/backend/               ← FastAPI REST API
│   ├── main.py
│   ├── config.py
│   ├── db.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── routers/
│       ├── ai.py              ← AI-чат (fallback chain)
│       ├── bookings.py        ← Брони
│       ├── clients.py         ← Клиенты
│       ├── leads.py           ← Лиды (публичный + защищённый)
│       ├── markets.py         ← Рынки
│       ├── memory.py          ← Память диалогов
│       ├── sos.py             ← SOS-уведомления
│       ├── tours.py           ← Каталог туров
│       └── webhooks.py        ← YooKassa webhook
│
├── providers/                 ← AI fallback chain
│   ├── __init__.py
│   ├── ai.py                  ← Базовый класс
│   ├── aitunnel.py            ← aitunnel
│   ├── gemini.py              ← Google Gemini
│   ├── groq.py                ← Groq (основной)
│   ├── openai_compat.py       ← Универсальный OpenAI-совместимый
│   └── openrouter.py          ← OpenRouter
│
│   ├── app.html               ← PWA v11.0 (~230 KB, self-contained)
│   ├── app-hyper.html         ← Альтернативная версия PWA
│   ├── wrangler.toml
│   ├── Nestandart/  (личность КотЭ)
│   │   └── prompt.txt         ← Личность КотЭ (для n8n)
│   ├── supabase/
│   │   └── schema.sql         ← Справочник схемы БД
│   ├── bot/
│   │   └── main.py            ← Старый бот (deprecated, используется n8n)
│   ├── public/
│   │   └── index.html         ← Альтернативная версия
│   └── docs/
│
├── nestandart-phuket/         ← САЙТ (лендинг Пхукет)
│   ├── index.html             ← Главная страница (1433 строки)
│   ├── 404.html
│   ├── robots.txt
│   ├── sitemap.xml
│   ├── netlify.toml
│   ├── vercel.json
│   ├── og-image.png
│   ├── favicon.svg
│   ├── css/
│   │   └── style.css          ← 1265 строк, mobile-first
│   ├── js/
│   │   ├── config.js          ← Конфиг (туры, цены, фильтры)
│   │   └── app.js             ← Логика (drag, фильтры, модалки)
│   ├── blog/                  ← 6 статей
│   │   ├── luchshie-ekskursii-na-phukete.html
│   │   ├── chto-posmotret-na-phukete.html
│   │   ├── skolko-stoit-otdyh-na-phukete.html
│   │   ├── ostrova-ryadom-s-phuketom.html
│   │   ├── kogda-letet-na-phukete.html
│   │   ├── chto-poprobovat-na-phukete.html
│   │   └── pattaya-vs-phuket.html
│   ├── tours/                 ← Детальные страницы туров
│   └── baza/                  ← Дополнительные файлы
│
├── baza/                        ← БАЗА (Штаб) — React/Vite
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   ├── eslint.config.js
│   ├── public/
│   │   ├── favicon.svg
│   │   └── icons.svg
│   └── src/
│       ├── App.jsx            ← Главный роутер
│       ├── context/
│       │   └── AppContext.jsx  ← Глобальный стейт (Supabase live)
│       └── components/
│           ├── DashboardView.jsx   ← КПТ hero + KPI
│           ├── WikiView.jsx        ← База знаний
│           ├── KoteView.jsx        ← Диалоги бота
│           ├── ReferralsView.jsx   ← Рефералы 3 уровня
│           ├── ClientsView.jsx     ← CRM клиенты
│           ├── BookingsView.jsx    ← Канбан заявок
│           ├── ToursView.jsx       ← Управление турами
│           ├── ContentView.jsx     ← Контент-план
│           ├── FinanceView.jsx     ← Платежи
│           └── FunnelView.jsx      ← Воронка продаж
│
├── n8n/                       ← n8n workflows (backup)
│   ├── live/                   ← актуальные экспорты (10 воркфлоу, без секретов)
│   └── migration/
│
├── deploy/                    ← VPS-скрипты
│   ├── deploy.sh
│   ├── backup-supabase.sh
│   ├── backup-offsite.sh
│   ├── healthcheck.sh         ← Cron */5 мин
│   ├── monitoring.sh
│   ├── rollback.sh
│   ├── run-backup.sh
│   ├── setup-vps.sh
│   ├── nginx.conf
│   ├── nginx-nestandart-online.conf
│   ├── nginx-nestandart-phuket-redirect.conf
│   └── systemd/
│       └── nestandart-bot.service  ← Мёртвый (отключить)
│
├── docs/                      ← Документация
│   ├── ACTION_PLAN.md
│   ├── AI_ARCHITECTURE.md
│   ├── AI_INTEGRATION.md
│   ├── API.md
│   ├── AUDIT.md
│   ├── AUDIT_REPORT.md
│   ├── AUTONOMY_TEST.md
│   ├── DATA_MODEL.md
│   ├── DEV_TOOLS.md
│   ├── ENV.md
│   ├── FRONTEND_SNIPPETS.md
│   ├── GITHUB-КАНОН.md
│   ├── N8N.md
│   ├── N8N_AUDIT.md
│   ├── SUPABASE.md
│   └── VPS_SETUP.md
│
├── supabase/
│   ├── schema.legacy.sql
│   └── migrations/
│
├── scripts/                   ← Вспомогательные скрипты
│   ├── generate_tours.py
│   ├── health-check.sh
│   ├── ship.sh
│   ├── status.sh
│   └── enable-kote-secret.sh
│
├── shared/                    ← Общие модули
│   ├── brand.js
│   └── markets.js
│
└── Остальное/                 ← Старые версии, прототипы
    ├── nestandart-app_v10.html
    ├── nestandart-app_v10_FINAL.html
    ├── nestandart-phuket-app.html
    ├── Prototype.html
    ├── Prototype-2.html
    ├── ai_studio_code.html
    ├── code.html
    ├── Каталог экскурсий.html
    ├── archive/               ← Старые бэкапы
    ├── docs-drafts/           ← Черновики документации
    ├── tools/
    └── МотоТур по Пхукету/    ← Фото
```

---

## 4. СТАТУС ПО РЫНКАМ

| Рынок | Туры | Сайт | PWA | Бот | Продажи |
|-------|------|------|-----|-----|---------|
| 🏝️ Пхукет | 68 | ✅ LIVE | ✅ | ✅ | ✅ LIVE |
| 🌅 Паттайя | 53 | ❌ заглушка | 90% | упоминается | ❌ |
| 🌿 Вьетнам | 12 | ❌ нет | ❌ | ❌ | ❌ |
| 🏖️ Бали | — | 📋 planned | — | — | — |
| 🏙️ Дубай | — | 📋 planned | — | — | — |

---

## 5. КЛЮЧЕВЫЕ ФАЙЛЫ (что читать первым)

| Файл | Назначение | Приоритет |
|------|-----------|-----------|
| `CLAUDE.md` | Главный канон проекта | 🔴 КРИТИЧНО |
| `MASTER_PROMPT.md` | Контекст для AI-сессий | 🔴 КРИТИЧНО |
| `README.md` | Общая карта | 🟡 ВАЖНО |
| `app/backend/main.py` | Точка входа FastAPI | 🟡 ВАЖНО |
| `nestandart-phuket/index.html` | Сайт Пхукет | 🟡 ВАЖНО |
| `baza/src/App.jsx` | Штаб (React) | 🟢 ПОЛЕЗНО |
| `docker-compose.yml` | Инфраструктура | 🟢 ПОЛЕЗНО |

---

## 6. ЧТО МОЖНО ОПТИМИЗИРОВАТЬ / УБРАТЬ

### 6.1. Дубликаты и мёртвый код

| Что | Где | Действие |
|-----|-----|----------|
| `Остальное/Prototype.html` + `Prototype-2.html` | Остальное/ | Прототипы — удалить |
| `Остальное/ai_studio_code.html` + `code.html` | Остальное/ | Непонятные файлы — удалить |
| `deploy/systemd/nestandart-bot.service` | deploy/ | Мёртвый systemd-юнит (бот в n8n) |

### 6.2. Необязательные для запуска функции

| Функция | Где | Можно убрать? |
|---------|-----|----------------|
| Паттайя в `nestandart-phuket/index.html` | 6 туров + placeholder | ✅ Да — отдельный лендинг |
| Вьетнам в коде (упоминания) | везде | ✅ Да — когда не нужен |
| `pattayaSoon` placeholder | nestandart-phuket/ | ✅ Да |
| `baza/` (БАЗА) | React-приложение | ❌ Нет — нужно для менеджеров |
| `n8n/` (workflows backup) | n8n/live/ | ✅ Да — свежие экспорты в репо + Docker volume |
| `docs/` (документация) | docs/ | ❌ Нет — нужно для разработки |
| `supabase/migrations/` | миграции | ❌ Нет — история схемы |
| `providers/` (AI fallback) | providers/ | ❌ Нет — нужно для AI |
| `deploy/` (скрипты) | deploy/ | ❌ Нет — нужно для деплоя |

### 6.3. CSS/JS оптимизации

| Что | Где | Как улучшить |
|-----|-----|--------------|
| `style.css` 1265 строк | nestandart-phuket/css/ | Разбить на модули, убрать дубли |
| `app.js` | nestandart-phuket/js/ | Минифицировать для продакшена |
| SVG-иллюстрации (20 штук) | index.html | Вынести в отдельные файлы или спрайт |
| `config.js` | nestandart-phuket/js/ | ✅ Уже вынесен — хорошо |
| Анимации (glitch, loader) | CSS | Оставить — это бренд |

### 6.4. SEO-дубли

| Что | Где | Действие |
|-----|-----|----------|
| `pattaya-vs-phuket.html` | blog/ | Оставить — полезная статья |
| H1 в hero (визуально скрыт) | index.html | ✅ Оставить — SEO |
| Schema.org (3 блока) | index.html | ✅ Оставить — rich snippets |

---

## 7. ИНФРАСТРУКТУРА

### VPS (77.42.93.187)

| Сервис | Порт | Docker? |
|--------|------|---------|
| nginx | 80/443 | ❌ systemd |
| kote-backend (FastAPI) | 127.0.0.1:8000 | ✅ Docker |
| kote-n8n | 127.0.0.1:5678 | ✅ Docker |

### Supabase

| Проект | ID |
|--------|-----|
| Основной | `cmmdrhususjuadqzyssc` |

### n8n

| Workflow | ID | Назначение |
|----------|-----|-----------|
| КотЭ | `doCUKEZQpLQjDmxP` | Основной бот |
| Статус брони | `kotestatusnt0001` | Уведомления |
| Дожим броней | `kotenudge000001` | Пинг клиентов |

---

## 8. БЕЗОПАСНОСТЬ

| Правило | Статус |
|---------|--------|
| RLS (Row Level Security) | ✅ Включено |
| X-Kote-Secret | ✅ Боевой (fail-closed); RPC — только service_role |
| UFW (только 22, 80, 443) | ✅ |
| `.env` в gitignore | ✅ |
| Swagger `/api/docs` публичный | ⚠️ TODO: закрыть |
| YooKassa IP whitelist | ⚠️ TODO: добавить |

---

## 9. ПРИОРИТЕТЫ (по КПТ)

### Актуальные приоритеты — см. docs/VISION.md §6 (этапы)

Прежние P0/P1 (посадочные Паттайи/Вьетнама, X-Kote-Secret в n8n) — выполнены или отменены
решением «фокус только Пхукет» (2026-07-01) и security-харднингом (2026-07-02).

### P2 — Месяц

8. YooKassa IP whitelist
9. Закрыть `/api/docs`
10. Offsite backup (S3/R2)
11. Бэкап n8n workflows
12. Внешний мониторинг (UptimeRobot)

---

## 10. КОМАНДЫ (шпаргалка)

```bash
# Локально
cd nestandart-phuket && npx serve . -p 3000      # Сайт
cd baza && npm install && npm run dev             # БАЗА (Штаб)
cd app/backend && pip install -r requirements.txt && uvicorn main:app --reload  # Backend

# VPS
ssh root@77.42.93.187
cd /opt/nestandart
docker compose ps                                 # Статус
docker compose logs -f kote-backend              # Логи
git pull && docker compose build kote-backend && docker compose up -d  # Деплой

# Supabase
# SQL Editor: https://supabase.com/dashboard/project/cmmdrhususjuadqzyssc
```

---

## 11. КОНТАКТЫ

| Ресурс | Данные |
|--------|--------|
| VPS SSH | `root@77.42.93.187` |
| Supabase | `cmmdrhususjuadqzyssc` |
| n8n | https://n8n.nestandart.online |
| Telegram Bot | @phuket_nestandart_bot |
| Manager | chat_id: 8943048058 |
| GitHub | github.com/ibetekhtin/NestanDaRt-20 |

---

*Карта создана автоматически при сканировании проекта.*  
*Для вопросов — читай `CLAUDE.md` и `MASTER_PROMPT.md`.*