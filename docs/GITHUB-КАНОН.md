# 🐙 GITHUB-КАНОН — карта репозитория KOTЭ / Нестандартный Отдых

**Документ-канон по репозиторию.** Что где лежит на GitHub, что развёрнуто, что легаси, и где GitHub расходится с боевым VPS.
Составлен: **2026-06-21** (полное сканирование). Обновлять при крупных изменениях структуры.

---

## 0. ✅ GitHub ↔ VPS СВЕДЕНЫ (2026-06-21)

**Расхождение устранено.** `origin/main`, VPS `/opt/kote` (ветка `main`) и боевой код — все на коммите **`54f9101`** («chore(sync): version live VPS runtime»). Залито через git-bundle с VPS → local (у VPS нет push-доступа) → fast-forward `origin/main`. Прод теперь версионируется; деплой = обычный `git pull` на VPS.

- Сведено в git: groq-first `providers/` (+`aitunnel.py`, фикс openrouter), `app/backend/routers/ai.py` (`/ai/chat`), `docker-compose.yml`, `.env.example`, `set-secret.sh`, `platform/bot/*`.
- **Структура почищена** (`1ffdf3b`): root разгружен (убраны `vercel.json`, дубль `roadmap.html`, стале `deploy.sh` с неверным IP, `ARCHIVE_DUPLICATES.sh`, дубль `ПОЛНАЯ_СВОДКА.md`); доки→`docs/`, утилиты→`scripts/`. `set-secret.sh` оставлен в root (документированный entrypoint).
- **`docs/DEV_TOOLS.md`** — ключи вычищены (значения → `*-REDACTED`), теперь в git. ⚠️ Сами ключи всё равно надо **ротировать** (Groq+Gemini светились), это шаг владельца в консолях провайдеров.
- **`platform/kote/workflow.json`** — обновлён живым экспортом n8n (17 нод, нормализован), Supabase JWT вычищен → `SCRUBBED_SUPABASE_KEY__SET_ON_IMPORT`; `KOTE_SECRET` остаётся `{{ $env.KOTE_SECRET }}` (ссылка, не секрет).
- **Этот канон (`GITHUB-КАНОН.md`)** теперь в репо.

### Историческая справка (до сведения)
До 2026-06-21 GitHub `main` сильно отставал от VPS: вся работа после 19.06 (AI-каскад, /ai/chat, фиксы провайдеров, перенос n8n-ноды на backend) была сделана **прямо на VPS** и в git не попадала. Таблица расхождений ниже — снимок того состояния.

| Что | GitHub `main` (944379c, 19.06) | Боевой VPS `/opt/kote` |
|---|---|---|
| `app/backend/main.py` | **v1.0.0** | v2.0.0 (9 роутеров, вкл. `ai`) |
| `providers/ai.py` порядок | **gemini→openrouter→groq** (старый, без aitunnel, без env-конфига, без пропуска без ключа) | **groq→aitunnel→openrouter→gemini**, конфиг `AI_PROVIDER_ORDER`, авто-пропуск |
| `providers/aitunnel.py` | **отсутствует** | есть |
| endpoint `/api/v1/ai/chat` | **отсутствует** | есть (passthrough для бота) |
| `platform/kote/workflow.json` | зовёт Gemini **напрямую** (`generativelanguage…`) — очень старый | n8n-нода зовёт backend `/api/v1/ai/chat` |

➡️ **Вывод:** репозиторий — это история до 19.06 + исходники сайта/HQ. Боевой backend и n8n живут на VPS «своей жизнью». **Прод не версионируется git'ом** — это риск (нельзя откатиться, легко потерять при пересоздании VPS).
**Рекомендация:** свести VPS→GitHub (закоммитить актуальные `providers/`, `app/backend/`, экспорт `workflow.json`) и дальше деплоить только через `git pull`. См. §6.

---

## 1. Идентичность репозитория

- **Remote:** `github.com/ibetekhtin/kote-system.git` (origin).
- **Имена:** `README.md` и `CLAUDE.md` теперь оба зовут репо **`kote-system`** (исправлено в `1ffdf3b`). Локальная папка на диске пока `Desktop/папка с проектом` — рекомендуется переименовать в `kote-system` для полного совпадения (по согласованию с владельцем).
- **Тип:** монорепо (один бренд, один код, одна база, много рынков).
- **Ветки:** `main` (944379c) и `chore/audit-fixes-and-track-sources` (058d0fc) — обе от 19.06. PR'ов нет (gh CLI не установлен; ветки сравниваются через `git`).
- **Объём:** 199 отслеживаемых файлов.
- **Локальный клон:** `/Users/soloplayer/Desktop/папка с проектом` (= `origin/main`, есть несведённые правки docs).

---

## 2. Карта верхнего уровня (что где живёт)

| Каталог | Файлов | Что это | Статус |
|---|---|---|---|
| `nestandart-phuket/` | 59 | **САЙТ**: `index.html`, 27 стр. туров, 10 статей блога, `baza/` (знания), `js/config.js` (боты, города), sitemap/robots/og | ✅ деплоится на VPS nginx (`/var/www/nestandart`) |
| `platform/` | 26 | **ПЛАТФОРМА** (см. §3) | смешанный |
| `hq/` | 25 | **ШТАБ**: React + Vite админка → Supabase. Вьюхи: CRM, ContentFactory, Dashboard, Finance, Kanban, Wiki. Вход только админу | ⏳ есть код, деплой не подтверждён |
| `app/` | 13 | **BACKEND**: `app/backend/` FastAPI (роутеры ai/bookings/clients/leads/markets/memory/sos/webhooks) | ✅ деплоится (`kote-backend`), но GitHub-версия v1.0.0 — отстаёт |
| `archive-docs/` | 13 | архив старых доков | 🗄️ архив |
| `docs/` | 10 | актуальные каноны: `АРХИТЕКТУРА-КАНОН.md`, `AI_ARCHITECTURE.md`, `ARCHITECTURE.md`, `N8N_MIGRATION.md`, `ENV.md`, `SUPABASE.md`, `API.md`, `DEPLOY.md` + этот файл | ✅ канон |
| `deploy/` | 10 | скрипты VPS: setup, deploy, backup, healthcheck, nginx.conf | ⚠️ часть устарела (см. CLAUDE.md «деплой ручной») |
| `n8n/` | 8 | экспорт воркфлоу (`n8n/flows/`) | 🗄️ снимки, не живой источник |
| `supabase/` | 7 | `schema.sql` + 6 миграций | ✅ справочник схемы |
| `providers/` | 5 | **AI-каскад**: `ai.py`, `groq.py`, `aitunnel.py`*, `openrouter.py`, `gemini.py` (*aitunnel только на VPS) | ⚠️ GitHub-версия старая |
| `shared/` | 2 | `markets.js`, `brand.js` — константы рынков и бренда | ✅ |
| root | — | `docker-compose.yml`, `README.md`, `Makefile`, `CHANGELOG.md`, `ACTION_PLAN.md`, `VPS_SETUP.md`, `.github/` | ✅ |

---

## 3. `platform/` — что внутри

- `platform/bot/` — **Python-бот** (aiogram + tools): `main.py`, `intent.py`, `supabase_client.py`, `admin_notify.py`, `tools_knowledge.py`. ⚠️ **НЕ боевой** — живой бот = n8n workflow `doCUKEZQpLQjDmxP`. Это легаси/альтернатива (см. CLAUDE.md).
- `platform/kote/` — `prompt.txt` (личность КотЭ) + `workflow.json` (экспорт n8n). ⚠️ `workflow.json` устарел (зовёт Gemini напрямую).
- `platform/docs/` — STACK, SUPABASE, MULTI_MARKET, ROADMAP, KOTE_SYSTEM, KOTE_VISION.
- `platform/supabase/schema.sql` — справочник реальной схемы.
- `platform/app.html`, `app-hyper.html`, `app/index.html`, `public/` — варианты **PWA** (личный кабинет). Несколько копий — кандидаты на консолидацию.
- `platform/wrangler.toml` — конфиг **Cloudflare Workers** (origin-overview в CLAUDE.md упоминает workers; на VPS не используется напрямую).
- `platform/.github/workflows/ai-pair-review.yml` — CI авто-ревью.

---

## 4. Источники истины (из README)

| Что | Где | Как менять |
|---|---|---|
| Туры, цены, сезоны | Supabase → `tours` | SQL / HQ-панель → КотЭ подхватит сам |
| База знаний | Supabase → `knowledge` | SQL → КотЭ ищет по вопросу |
| Клиенты, заявки, платежи | Supabase → `clients`/`bookings`/`payments` | через HQ или бота |
| Личность КотЭ | `platform/kote/prompt.txt` | правка → импорт workflow в n8n |
| Контент сайта | `nestandart-phuket/*.html` | правка + git push (VPS подтянет) |
| Конфиг сайта | `nestandart-phuket/js/config.js` | правка + push |

---

## 5. История («что нового») — таймлайн

- **08.06** v1.0.0 — Telegram-бот (Node.js + Telegraf).
- **09.06** v2.0.0 — полный rebuild платформы: FastAPI backend (8 роутеров), Supabase migration 002 (7 таблиц), RLS, 6 RPC, 3 триггера, Docker Compose, deploy-скрипты, сайт+блог, доки.
- **11.06** Python-бот (aiogram + Claude + tools): `tools_knowledge`, `admin_notify`, `search_knowledge`.
- **18.06** end-to-end (бот+n8n+RPC), миграция `nestandart-phuket.ru → nestandart.online`, PWA через `app_upsert_lead`, фиксы миграций/CI, **провайдерский fallback-слой** (тогда Gemini→OpenRouter→Groq).
- **19.06** аудит P0-P1, добавление рынка Паттайя (migration 006), nginx под nestandart.online, deploy/healthcheck (автоперезагрузка backend). **← последний коммит `main`.**
- **19–21.06 (только на VPS, в git НЕ попало):** перенос n8n Cloud→self-hosted; Groq-ключ в бот; переписан каскад на **groq→aitunnel→openrouter→gemini** + `AI_PROVIDER_ORDER` + авто-пропуск; добавлен `aitunnel.py`; новый endpoint `/api/v1/ai/chat`; n8n-нода переключена с api.groq.com на backend; AITUNNEL и Gemini (`gemini-2.5-flash`) подключены. **Эти изменения нужно свести в GitHub.**

---

## 6. Деплой и сведение VPS↔GitHub

- **Деплой ручной** (VPS сам git не тянет): `ssh root@77.42.93.187 'cd /opt/kote && git pull && docker compose up -d --build'`.
- **Backend бакает код при сборке** (нет volume) → правки кода применяются только через `--build`.
- **`.env` не в git** (секреты только в `/opt/kote/.env` и env контейнеров). Новый ключ: `bash /opt/kote/set-secret.sh VARNAME kote-backend`.
- **⚠️ Проблема:** `/opt/kote` на VPS разошёлся с GitHub (другая родословная + несведённые правки) → простой `git pull` конфликтнёт. Свести аккуратно: забрать с VPS актуальные `providers/`, `app/backend/`, экспорт `platform/kote/workflow.json`, закоммитить в `main`, затем выровнять VPS на origin. Делать ТОЛЬКО с подтверждения (прод).

---

## 7. Легаси / кандидаты на чистку

- `platform/bot/` — Python-бот не развёрнут (боевой = n8n). Решить: архив или довести.
- `nestandart-phuket/vercel.json` + `netlify.toml` — канон запрещает Vercel/Netlify (хостинг = свой VPS). Удалить/заархивировать.
- `roadmap.html` (root) дублирует `nestandart-phuket/roadmap.html`.
- `platform/app.html` / `app-hyper.html` / `app/index.html` — несколько версий PWA, выбрать одну.
- Имя репо: `NestanDaRt-20` (README) vs `kote-system` (remote/CLAUDE) — унифицировать.
