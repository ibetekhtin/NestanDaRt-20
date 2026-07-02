# Changelog

## [2.2.0] - 2026-07-02

### Security
- Supabase lockdown: все 21 бизнес-RPC — только service_role (REVOKE anon/authenticated/PUBLIC + default privileges); partner_stats скрыт от anon; справочники anon read-only
- n8n переведён на service_role через `{{ $env.SUPABASE_SERVICE_KEY }}` — ключей в JSON воркфлоу нет
- Утечка текстов ошибок БД клиенту закрыта; PII-эндпоинты под X-Kote-Secret

### Fixed
- Пустое тело POST /api/leads создавало мусорный лид + спам менеджеру → 400
- Сломанные crontab-пути после переименования (/opt/NestanDaRt-20 → /opt/nestandart): healthcheck и pg_dump-бэкап снова работают
- Битый симлинк /opt/kote; мёртвый порт 3055 в nginx (главный сайт и app-субдомен)
- n8n: сбой записи диалога больше не блокирует создание брони; таймауты HTTP-нод; алерт при ошибке создания оплаты; Telegram-рассылки не падают от одного 403-клиента
- Сайт: битые клики 4 туров (data-id ≠ имя файла); дубль moto_tour консолидирован; sitemap 12 → 37 URL
- PWA: title/meta «только Пхукет», мёртвый домен в шаринге → app.nestandart.online

### Changed
- Единый helper db.upsert_lead() вместо 4 копий словаря RPC (−60 строк)
- Sync-Supabase уведён из event loop (def-эндпоинты / run_in_threadpool)
- KOTE_SOUL: вырезаны Паттайя/Вьетнам (фокус Пхукет)
- Репозиторий: hq-артефакты удалены, ветки-сироты удалены (архив-теги локально), .OLD удалён (бэкапы в /root/backups/old-repo), platform/ и доки восстановлены, docs/archive/ для исторических отчётов

### Added
- docs/VISION.md (карта видения), docs/SECURITY.md, актуальный API.md, baza/README.md
- n8n/live/ — экспорты живых воркфлоу; supabase/schema.reference.sql — свежий дамп (73 объекта)
- tests/test_payments.py (11 тестов); смоуки под приватные PII (25/25)

## [2.0.0] - 2026-06-09

### Added
- FastAPI Backend API (`app/backend/`) — 8 routers, 14 endpoints
- Supabase Migration 002 — 7 new tables (leads, ai_interactions, client_memory, reviews, partners, action_history, tours)
- RLS policies for all tables
- 6 RPC functions (app_upsert_lead, app_create_booking, app_update_memory, app_get_client_context, app_get_market_stats, app_log_action)
- 3 database triggers (auto-audit, auto-updated_at)
- 4 new n8n workflows (memory-update, daily-report, market-sync, booking-flow)
- Docker Compose (bot + backend + n8n)
- Dockerfiles for bot and backend
- VPS deployment scripts (setup, deploy, backup, healthcheck)
- Nginx reverse proxy config
- Systemd service file
- Bot improvements: logger, error_handler, memory system
- Mobile app skeleton (Expo)
- Full documentation (8 docs files)

### Changed
- Bot: structured JSON logging
- Bot: error handling with global handlers
- Bot: memory integration for AI context

## [1.0.0] - 2026-06-08

### Added
- Initial release
- Telegram bot (Node.js + Telegraf)
- AI integration (Gemini 2.0 Flash)
- Supabase schema (6 tables)
- 4 n8n workflows
- Static website