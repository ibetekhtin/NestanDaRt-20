-- ============================================================================
-- Migration 005: Performance indexes (RECONCILED with the real schema)
-- Date: 2026-06-18
-- ============================================================================
-- IMPORTANT — this file was rewritten during the system audit.
--
-- The original 005 was generated against the STALE 6-table schema and was both
-- broken and unsafe, so it was NEVER applied. Specifically it:
--   • referenced columns that do not exist: bookings.date, bookings.market_id,
--     clients.telegram_id, clients.market_id, knowledge.market_id  → would error;
--   • added `bookings_anon_read USING (true)` → would let anon read EVERY booking
--     (PII leak), and an unvalidated `reviews_anon_insert WITH CHECK (true)`.
--
-- The live database already has STRONGER security in place (applied via dedicated
-- audit migrations, all live):
--   • RLS: bookings_anon_insert_new_only (no anon read), reviews rating-validated
--     insert, conversations source-checked anon insert, payments admin-only;
--   • EXECUTE revoked from PUBLIC on trigger functions;
--   • secret-gated get_new_leads / get_tour_reminders / get_review_requests /
--     bot_upsert_client (SHA-256 of KOTE_SECRET); old unprotected overloads dropped;
--   • FK covering indexes (action_history.booking_id, bookings.tour_id, reviews.*);
--   • knowledge RLS init-plan wrapped in (select auth.role()); duplicate tours
--     SELECT policy removed; search_path pinned on get_bookings_by_phone.
--
-- This file now contains ONLY the valid, schema-correct, useful indexes from the
-- original 005 (telegram_id -> tg_chat_id, market_id -> city corrected).
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_conversations_client_id   ON conversations(client_id);
CREATE INDEX IF NOT EXISTS idx_conversations_created_at  ON conversations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_client_id        ON bookings(client_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status           ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_clients_tg_chat_id        ON clients(tg_chat_id);
CREATE INDEX IF NOT EXISTS idx_clients_stage             ON clients(stage);
CREATE INDEX IF NOT EXISTS idx_tours_category            ON tours(category);
CREATE INDEX IF NOT EXISTS idx_tours_active_sort         ON tours(active, sort_order);
CREATE INDEX IF NOT EXISTS idx_tours_market_active_sort  ON tours(market_id, active, sort_order) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_client_memory_client_id   ON client_memory(client_id);
CREATE INDEX IF NOT EXISTS idx_action_history_client_id  ON action_history(client_id);
CREATE INDEX IF NOT EXISTS idx_action_history_created_at ON action_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_booking_id       ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_city            ON knowledge(city);

ANALYZE conversations; ANALYZE bookings; ANALYZE clients; ANALYZE tours;
ANALYZE client_memory; ANALYZE payments; ANALYZE action_history; ANALYZE knowledge;
