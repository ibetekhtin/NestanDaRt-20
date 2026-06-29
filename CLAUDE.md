# CLAUDE.md — МАСТЕР-ФАЙЛ ПРОЕКТА
# Nestandart / Нестандартный Отдых®
> Последнее обновление: 2026-06-23 · v5 — единый канон Nestandart
> Этот файл — единственный источник истины для Claude Code и любого AI-агента.
> Читать полностью перед любой работой с проектом.

---

## 🏆 ГЛАВНАЯ МЕТРИКА — КПТ

**КПТ = Количество Проданных Туров**

Это единственная метрика, которая имеет значение.
Не средний чек. Не выручка. Не охваты. Не конверсия. **КПТ.**

Каждый принятый заказ = КПТ+1.
Вся система — КотЭ, бот, сайт, CRM, автоматизации — существует чтобы **максимизировать КПТ**.
При любом решении о фиче, изменении, автоматизации — спрашивай: «это увеличит КПТ?»

---

## 🗣️ ГЛОССАРИЙ (ЕДИНЫЙ СТАНДАРТ)

| Термин | Что это |
|--------|---------|
| **Nestandart** | Название проекта, имя репозитория, имя папки — везде одно |
| **ЗОЛОТОЙ ТРЕУГОЛЬНИК** | Три точки продаж: **Бот** + **Сайт** + **Приложение** |
| **БАЗА / Штаб** | React/Vite командный центр на baza.nestandart.online |
| **БД** | База данных = Supabase (PostgreSQL) |
| **КотЭ** | AI-бот в Telegram (@phuket_nestandart_bot), n8n workflow |
| **КПТ** | Количество Проданных Туров — единственный KPI |

---

## 🗺️ ЧТО ЭТО ЗА ПРОЕКТ

**Нестандартный Отдых®** — туристическая платформа в Таиланде (Пхукет, Паттайя, Вьетнам).
Продаём авторские экскурсии. Главный инструмент продаж — **Telegram-бот КотЭ** на базе AI.

**Бизнес-модель:** клиент пишет в Telegram → КотЭ помогает выбрать тур → менеджер закрывает сделку → клиент едет на экскурсию.

**Золотой треугольник:**
- **Бот (КотЭ)** = УНИВЕРСАЛЕН. Знает всё, может всё. Кастомные туры, любые настройки.
- **Сайт** = стандартный, автоматизированный, ограниченный каталог.
- **Приложение** = PWA, 50+ туров минимум, единый кабинет через Supabase Auth.

---

## 🏗️ АРХИТЕКТУРА СИСТЕМЫ

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
   │  ns-backend │  │  n8n.nestandart.online │
   │ port 8000 │  │  port 5678             │
   └────────┬──┘  └────────┬───────────────┘
            └───────┬───────┘
                    │
         ┌──────────▼──────────┐
         │  Supabase (Cloud)   │
         │  PostgreSQL + Auth  │
         │  cmmdrhususjuadqzyssc│
         └─────────────────────┘
```

---

## 📁 СТРУКТУРА ПРОЕКТА

### Репозиторий
- **GitHub:** `github.com/ibetekhtin/NestanDaRt-20`
- **Локально:** `/Users/soloplayer/Desktop/Nestandart/`
- **VPS:** `/opt/nestandart/` (симлинк `/opt/kote` → `/opt/nestandart` для совместимости)

### AI Operating System
- **Путь:** `AI_OPERATING_SYSTEM/`
- **Назначение:** Правила и режимы работы для AI-агентов
- **Структура:**
  ```
  AI_OPERATING_SYSTEM/
  ├── SYSTEM.md                    ← Конституция проекта
  ├── MODES/                       ← 7 режимов работы
  │   ├── AUDIT.md                 ← Только анализ
  │   ├── REFACTOR.md              ← Рефакторинг по аудиту
  │   ├── BUILD.md                 ← Новая функциональность
  │   ├── SECURITY.md              ← Безопасность
  │   ├── PERFORMANCE.md           ← Производительность
  │   ├── RELEASE.md               ← Деплой
  │   └── EMERGENCY.md             ← Восстановление
  ├── RULES/                       ← 7 правил
  │   ├── ARCHITECTURE.md          ← Архитектура
  │   ├── CODING.md                ← Стандарты кода
  │   ├── DEPENDENCIES.md          ← Зависимости
  │   ├── SAFE_DELETE.md           ← Безопасное удаление
  │   ├── DOCUMENTATION.md         ← Документация
  │   ├── GIT.md                   ← Git workflow
  │   └── DECISIONS.md             ← Журнал решений
  ├── CHECKLISTS/                  ← 5 чеклистов
  │   ├── BEFORE_CHANGE.md         ← Перед изменением
  │   ├── BEFORE_COMMIT.md         ← Перед коммитом
  │   ├── BEFORE_DEPLOY.md         ← Перед деплоем
  │   ├── AFTER_REFACTOR.md        ← После рефакторинга
  │   └── AFTER_RELEASE.md         ← После релиза
  └── REPORTS/                     ← 3 шаблона
      ├── TEMPLATE.md              ← Универсальный
      ├── AUDIT_TEMPLATE.md        ← Для аудита
      └── RELEASE_TEMPLATE.md      ← Для релиза
  ```
- **Использование:** Все AI-агенты должны следовать правилам из `SYSTEM.md` и использовать соответствующие режимы из `MODES/`

### Папки
```
Nestandart/
├── CLAUDE.md                  ← ЭТОТ ФАЙЛ
├── docker-compose.yml         ← name: Nestandart
├── docker-compose.override.yml
├── .env                       ← СЕКРЕТЫ (не коммитить!)
├── .env.example               ← шаблон без секретов
│
├── app/backend/               ← FastAPI REST API
│   ├── main.py
│   └── routers/               ← ai, bookings, clients, leads, markets, memory, sos, tours, webhooks
│
├── providers/                 ← AI fallback chain
│
│   ├── app.html               ← PWA v11.0, ~230 KB self-contained
│   ├── Nestandart/prompt.txt ← ЛИЧНОСТЬ КотЭ (n8n workflow prompt)
│   └── supabase/schema.sql    ← справочник схемы
│
├── baza/                        ← БАЗА (React Vite, baza.nestandart.online)
│   └── src/components/
│       ├── DashboardView.jsx  ← КПТ hero + KPI
│       ├── WikiView.jsx       ← база знаний (live Supabase)
│       ├── KoteView.jsx       ← диалоги КотЭ
│       └── ReferralsView.jsx  ← 3-уровневые рефералы
│
├── deploy/
│   ├── healthcheck.sh         ← cron */5 мин
│   └── run-backup.sh
│
└── docs/ + archive-docs/
```

---

## 🌐 СЕРВИСЫ И ДОМЕНЫ

| Сервис | URL | Статус |
|--------|-----|--------|
| Сайт | nestandart.online | ✅ |
| Приложение PWA | app.nestandart.online | ✅ |
| БАЗА (Штаб) | baza.nestandart.online | ✅ |
| n8n | n8n.nestandart.online | ✅ |
| API FastAPI | nestandart.online/api/v1/ | ✅ |

### VPS сервисы (все внутри /opt/nestandart/)

| Сервис | Порт | Управление |
|--------|------|-----------|
| kote-backend (FastAPI) | 127.0.0.1:8000 | Docker (project: Nestandart) |
| kote-n8n | 127.0.0.1:5678 | Docker (project: Nestandart) |
| nestandart-api (Node.js) | 127.0.0.1:3055 | PM2 |

> ⚠️ Volume `kote-n8n-data` — имя НЕ МЕНЯТЬ (там живут все workflows n8n). Объявлен в docker-compose.yml как `name: kote-n8n-data` — это намеренно.

---

## 🔑 ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ (`/opt/nestandart/.env`)

```bash
SUPABASE_URL=https://cmmdrhususjuadqzyssc.supabase.co
SUPABASE_SERVICE_KEY=...     # service_role — не светить!
SUPABASE_ANON_KEY=...
TELEGRAM_BOT_TOKEN=...       # @phuket_nestandart_bot
TELEGRAM_ADMIN_CHAT_ID=8943048058
MANAGER_CHAT_ID=8943048058
AI_PROVIDER_ORDER=groq,aitunnel,openrouter,gemini
GROQ_API_KEY=...
AITUNNEL_API_KEY=...
GEMINI_API_KEY=...
GEMINI_MODEL=gemini-2.5-flash
N8N_USER=admin
N8N_PASSWORD=...
YOOKASSA_SHOP_ID=...
YOOKASSA_SECRET_KEY=...
```

---

## 🗄️ БАЗА ДАННЫХ SUPABASE

**Проект:** `cmmdrhususjuadqzyssc`

### Таблицы

| Таблица | Назначение |
|---------|-----------|
| `markets` | Рынки (id text: 'phuket', 'pattaya', 'vietnam') |
| `tours` | Каталог туров (133 активных: Пхукет 68, Паттайя 53, Вьетнам 12) |
| `clients` | База клиентов |
| `bookings` | Брони |
| `payments` | Платежи YooKassa |
| `knowledge` | База знаний КотЭ (84+ записи) |
| `conversations` | История диалогов |
| `partners` | Партнёры / рефералы |
| `referrals` | Реферальные начисления |
| `content_plan` | Контент-план |

### Ключевые RPC-функции

```sql
app_upsert_lead(p_name, p_phone, p_email, p_telegram, p_tg_chat_id,
                p_tour_name, p_tour_slug, p_date_start, p_people,
                p_total, p_comment, p_status, p_ref_code)
get_kote_context(p_tg_chat_id, p_query)
credit_referral(p_booking_id)   -- начисляет % партнёру при оплате
```

### RLS

- **anon:** читает туры/знания, пишет через `app_upsert_lead`
- **authenticated:** `email = auth.jwt()->>'email'` (клиент видит СВОИ данные)
- **is_admin():** полный доступ (ibetekhtin@gmail.com)
- **service_role:** полный доступ через backend

### Supabase Auth

- Magic link (OTP по email) реализован в app.html
- Redirect URL: `https://app.nestandart.online/` ← добавлен в Auth → URL Configuration
- Политики: `client_self_read`, `client_self_update`, `client_self_bookings_read`

---

## 🔌 FASTAPI BACKEND

```
GET   /health
GET   /api/v1/markets
GET   /api/v1/tours[?market_id=phuket&active=true]
POST  /api/v1/leads            ← создать/обновить лид (X-Kote-Secret)
GET   /api/v1/bookings/{id}    ← статус брони
PATCH /api/v1/bookings/{id}    ← сменить статус (X-Kote-Secret)
POST  /api/v1/ai/chat          ← AI для n8n-бота (X-Kote-Secret)
POST  /api/v1/ai/ask           ← AI для PWA (без авторизации)
POST  /api/v1/pay/create       ← создать платёж YooKassa (X-Kote-Secret)
POST  /api/v1/pay/webhook      ← вебхук YooKassa

# Legacy (backward-compat, deprecated):
POST /api/v1/lead   → /api/v1/leads
GET  /api/v1/bookings?phone=... → /api/v1/bookings/{id}
```

### AI Fallback Chain

```
groq (основной) → aitunnel → openrouter → gemini (резерв)
```

---

## 🤖 N8N АВТОМАТИЗАЦИИ

| Workflow | Триггер | Действие |
|----------|---------|----------|
| КотЭ (`doCUKEZQpLQjDmxP`) | Telegram | Клиент → AI → CRM → оплата |
| Уведомление о заявках | Webhook | Менеджеру в Telegram |
| Напоминание за день | Schedule | Клиенту |
| Запрос отзыва | Schedule | После тура |
| Статус брони (`kotestatusnt0001`) | Schedule 5 мин | Уведомить клиента |
| Дожим броней (`kotenudge000001`) | Schedule 1/день | Пинг по «Новый» 24ч |

---

## 💳 РЕФЕРАЛЬНАЯ СИСТЕМА

| Уровень | % | Описание |
|---------|---|---------|
| 1 | 1.5% | Новый партнёр |
| 2 | 2.5% | Активный |
| 3 | 3.5% | Топ (максимум) |

Начисление автоматически при статусе «Оплачено»/«Завершён».

---

## 📱 ПРИЛОЖЕНИЕ PWA (app.html v11.0)

- 50+ туров (только `active=true`, без ограничений)
- **Кабинет:** Supabase Auth magic link → реальный профиль + брони
- YooKassa оплата, промокоды → ref_code → партнёру
- Кеш: `nop_tours_v12`
- CRM endpoint: `https://nestandart.online/api/v1/lead`

---

## 🏠 БАЗА (Штаб / HQ)

**URL:** https://baza.nestandart.online | **Пароль:** `<в .env — BAZA_PASSWORD>` ⚠️ не хранить в git

| Раздел | Данные |
|--------|--------|
| Дашборд (КПТ hero) | bookings, clients, payments |
| CRM / Kanban | clients, bookings |
| Туры | tours table |
| Вики | knowledge table |
| КотЭ | conversations |
| Контент | content_plan |
| Финансы | payments |
| Рефералы | partners, referrals |

---

## 🐾 КотЭ — ЛОГИКА БРОНИ

КотЭ собирает: **имя, телефон, тур, дата, отель, комната, кол-во гостей (взрослые/дети/младенцы до 4 лет)**.
При готовности — добавляет `[[BRON]]...[[/BRON]]`. n8n парсит, вырезает из ответа, пишет в CRM.

---

## 🐳 DOCKER

```bash
cd /opt/nestandart

docker compose ps                              # статус
docker compose logs -f kote-backend           # логи
docker compose build kote-backend && \
  docker compose up -d --force-recreate kote-backend  # ребилд после изменений кода
```

---

## 🔄 ДЕПЛОЙ

```bash
# Синхронизировать VPS с GitHub:
ssh root@77.42.93.187 "cd /opt/nestandart && git pull"

# app.html → VPS:

# nginx изменения:
nginx -t && systemctl reload nginx
```

---

## 💾 БЭКАПЫ (cron)

```
0  3  * * *  /root/backup-supabase.sh
30 3  * * *  /root/backup-vps.sh
*/5 * * * *  /opt/nestandart/deploy/healthcheck.sh
15 3  * * *  /opt/nestandart/deploy/run-backup.sh
0  4  * * *  /root/backup-offsite.sh
```

---

## 🩺 БЫСТРАЯ ДИАГНОСТИКА

```bash
docker ps && curl -s https://nestandart.online/api/v1/markets
docker logs kote-backend --tail 50 | grep -v "GET /health"
tail -20 /var/log/nginx/error.log
fail2ban-client status sshd
```

---

## ⛔ ЧЕГО НЕ ДЕЛАТЬ

1. **НЕ запускать nestandart-bot через Docker** — бот в n8n.
2. **НЕ менять `markets.id`** — это text ('phuket', 'pattaya', 'vietnam').
3. **НЕ передавать `p_market_id`** в `app_upsert_lead`.
4. **НЕ использовать `n8nio/n8n:latest`** — фиксировать версию.
5. **НЕ коммитить `.env`**.
6. **НЕ переименовывать Docker volume `kote-n8n-data`** — там живут все workflows n8n.
7. **НЕ импортировать `daily-report.json`** — невалидный синтаксис.

---

## 📞 КОНТАКТЫ И ДОСТУПЫ

| Ресурс | URL / Данные |
|--------|-------------|
| VPS SSH | `ssh root@77.42.93.187` (ключ) |
| Supabase | https://supabase.com/dashboard/project/cmmdrhususjuadqzyssc |
| n8n | https://n8n.nestandart.online |
| Telegram Bot | @phuket_nestandart_bot |
| Manager Telegram | chat_id: 8943048058 |
| GitHub | github.com/ibetekhtin/NestanDaRt-20 |
| Домены | nestandart.online, nestandart-phuket.ru |

---

## 🚀 СЛЕДУЮЩИЕ ШАГИ (по ROI)

- [ ] Сайт — единый кабинет через Supabase Auth (как в приложении)
- [ ] Паттайя полный запуск (туры готовы, нужна страница)
- [ ] Вьетнам полный запуск (12 туров уже в БД, рынок готов — нужна страница)
- [ ] SUPABASE_DB_URL → SQL-бэкапы через pg_dump
- [ ] Offsite backup (S3/Cloudflare R2)
- [ ] Внешний мониторинг (UptimeRobot)
- [ ] n8n версия зафиксирована в docker-compose.yml

---

*Nestandart CLAUDE.md · v5 · 2026-06-23*
*Единый канон. Один репозиторий. Один стандарт.*
