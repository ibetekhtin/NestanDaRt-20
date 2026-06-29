# MASTER PROMPT — Nestandart
> Скопируй в начало следующей Claude Code сессии. Обновляй после каждого крупного изменения.
> Последнее обновление: 2026-06-24 · v6

---

Ты работаешь над проектом **«Нестандартный Отдых»** — туристическая компания в Азии.
Рынки: **Пхукет (68 туров, LIVE), Паттайя (53, инфра готова — нужна посадочная), Вьетнам (12, только БД)**.
Единственный KPI: **КПТ = Количество Проданных Туров**. Любое решение оценивается через этот фильтр.

## Архитектура (VPS 77.42.93.187, Ubuntu 22.04)

```
Telegram → n8n (kote-n8n, :5678) → FastAPI (kote-backend, :8000) → Supabase
Сайт: nestandart.online → nginx → /var/www/nestandart/
Штаб: baza.nestandart.online → nginx → React/Vite (hq/)
PWA:  app.nestandart.online → nginx → platform/app.html
```

- **Бот КотЭ** = n8n workflow `doCUKEZQpLQjDmxP`. НЕ запускать `nestandart-bot` через Docker.
- **AI каскад**: `groq → aitunnel → openrouter → gemini` (providers/). Провайдер без ключа пропускается.
- **Платежи**: YooKassa через `/api/v1/pay/create` (fail-open при пустом KOTE_RPC_SECRET).
- **Docker volumes**: `kote-n8n-data` — **НЕ ПЕРЕИМЕНОВЫВАТЬ** (там все workflows n8n).

## Репозиторий

- **GitHub**: `github.com/ibetekhtin/NestanDaRt-20`
- **Локально**: `/Users/soloplayer/Desktop/Nestandart/`
- **VPS**: `/opt/nestandart/` (симлинк `/opt/kote → /opt/nestandart` для совместимости)
- **Деплой**: `ssh root@77.42.93.187 "cd /opt/nestandart && git pull && docker compose build kote-backend && docker compose up -d"`

## Ключевые файлы

| Файл | Назначение |
|------|-----------|
| `CLAUDE.md` | Главный канон — читать перед любой работой |
| `AI_OPERATING_SYSTEM/SYSTEM.md` | Конституция проекта — правила для AI-агентов |
| `AI_OPERATING_SYSTEM/MODES/` | 7 режимов работы (AUDIT, REFACTOR, BUILD, SECURITY, PERFORMANCE, RELEASE, EMERGENCY) |
| `AI_OPERATING_SYSTEM/RULES/` | 7 правил (Architecture, Coding, Dependencies, Safe Delete, Documentation, Git, Decisions) |
| `AI_OPERATING_SYSTEM/CHECKLISTS/` | 5 чеклистов (Before Change, Before Commit, Before Deploy, After Refactor, After Release) |
| `AI_OPERATING_SYSTEM/REPORTS/` | 3 шаблона отчётов (Template, Audit, Release) |
| `docker-compose.yml` | Два сервиса: kote-backend, kote-n8n |
| `app/backend/` | FastAPI (роутеры: ai, bookings, clients, leads, markets, memory, payments, sos, tours, webhooks) |
| `providers/` | AI fallback chain (groq, aitunnel, openrouter, gemini + общий openai_compat.py) |
| `platform/Nestandart/prompt.txt` | Промпт-личность КотЭ |
| `platform/app.html` | PWA v11.0, self-contained |
| `hq/` | БАЗА (React Vite, baza.nestandart.online) |
| `deploy/healthcheck.sh` | Cron */5 мин — алерты в Telegram |

## Архитектурный нюанс (ВАЖНО — не ломать)

n8n workflow `doCUKEZQpLQjDmxP` шлёт запросы на `http://kote-backend:8000` (старое имя).
В `docker-compose.yml` добавлен alias `kote-backend` для сервиса `kote-backend` — менять не нужно.
Если убрать alias — бот перестанет получать AI-ответы.

## Безопасность

- `/ai/chat`, `/pay/create`, `POST /bookings`, `PATCH /bookings/{id}`, `GET /leads` — требуют `X-Kote-Secret`
- ⚠️ n8n пока **НЕ шлёт** `X-Kote-Secret` → оставь `KOTE_RPC_SECRET=""` до обновления HTTP-нод в n8n
- Когда будешь ставить `KOTE_RPC_SECRET`: сначала добавь заголовок в n8n ноды «🤖 Gemini» и «💳 Создать оплату»
- `POST /api/v1/leads` (create) и `POST /api/v1/lead` (legacy, используется PWA) — публичные по дизайну
- YooKassa webhook перепроверяет статус у YooKassa API напрямую (не доверяет payload) — это правильно
- YooKassa IP whitelist в nginx — ещё НЕ добавлен (TODO: P2)
- Swagger `/api/docs` — открыт публично (TODO: закрыть в prod через nginx basic auth)

## База данных (Supabase cmmdrhususjuadqzyssc)

Ключевые таблицы: `markets`, `tours`, `clients`, `bookings`, `payments`, `knowledge`, `conversations`, `partners`, `referrals`
Ключевые RPC: `app_upsert_lead(...)`, `get_kote_context(p_tg_chat_id, p_query)`
Реферальная система: **триггер** `trg_referral_bonus` на `bookings` (BEFORE UPDATE) — NOT функция `credit_referral()` (CLAUDE.md устарел в этом месте, функции нет, есть триггер).

## Статус по рынкам (2026-06-24)

| Рынок | Инфра | Каталог | Сайт | PWA | Бот | Продажи |
|-------|-------|---------|------|-----|-----|---------|
| Пхукет | ✅ | 68 туров | ✅ SEO | ✅ | ✅ | ✅ LIVE |
| Паттайя | ✅ | 53 тура в БД | ❌ нет страницы | 90% готов (заглушка) | упоминается | ❌ Заглушка |
| Вьетнам | 🟡 БД только | 12 туров в БД | ❌ нет | ❌ нет | ❌ не знает | ❌ нет |

## Приоритеты по КПТ (следующие шаги)

### P0 — Немедленно (деньги уходят мимо прямо сейчас)

1. **Паттайя — убрать заглушку** (`pattayaSoon`) в `platform/app.html` → показать реальный каталог из БД
2. **Паттайя — посадочная страница** `/pattaya/index.html` (клон структуры `/phuket/`) → SEO трафик
3. **Паттайя — 15 знаний** в `knowledge` (пляжи, сезонность, логистика) + обновить промпт КотЭ

### P1 — Эта неделя

4. **n8n ноды** — добавить `X-Kote-Secret` заголовок в «🤖 Gemini» и «💳 Создать оплату» (UI n8n, не код)
5. **Вьетнам PWA** — добавить третий город в `platform/app.html`: splash, акцент-цвет (#B8FF3C), фильтр
6. **Supabase Вьетнам** — `UPDATE markets SET active=true WHERE slug='vietnam'`; активировать туры
7. **`knowledge.city`** — расширить CHECK constraint на 'Вьетнам', добавить 15 записей

### P2 — Ближайший месяц

8. YooKassa IP whitelist в nginx для `/api/v1/pay/webhook`
9. Закрыть `/api/docs` в prod (nginx basic auth или `docs_url=None`)
10. Offsite backup (S3/Cloudflare R2) — сейчас данные только на VPS
11. Бэкап n8n workflows (`docker exec kote-n8n n8n export:workflow --all --backup`)
12. Внешний мониторинг UptimeRobot

## Ручные действия на VPS (не в коде)

```bash
# 1. Применить новый docker-compose.yml (mem_limit + kote-backend alias)
ssh root@77.42.93.187 "cd /opt/nestandart && git pull && docker compose up -d --force-recreate"

# 2. Убрать мёртвый systemd-юнит
sudo systemctl disable nestandart-bot.service
sudo rm /etc/systemd/system/nestandart-bot.service
sudo systemctl daemon-reload

# 3. Активировать Вьетнам (когда готово) — в Supabase SQL Editor:
UPDATE markets SET active = true WHERE slug = 'vietnam';
UPDATE tours SET active = true
  WHERE market_id = (SELECT id FROM markets WHERE slug = 'vietnam');
```

## Запреты

- НЕ запускать `nestandart-bot` через Docker (бот в n8n)
- НЕ переименовывать volume `kote-n8n-data`
- НЕ открывать UFW порты 5678 и 8000
- НЕ коммитить `.env`
- НЕ менять `markets.id` ('phuket', 'pattaya', 'vietnam', 'bali', 'dubai')
- НЕ ставить `KOTE_RPC_SECRET` пока n8n-ноды не обновлены

## Проверка после изменений

```bash
ssh root@77.42.93.187 'cd /opt/nestandart && docker compose ps && curl -s http://localhost:8000/health'
```
