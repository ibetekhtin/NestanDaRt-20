# Changelog

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