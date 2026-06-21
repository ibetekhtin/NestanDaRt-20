-- 013 — БЕЗОПАСНОСТЬ (P0): закрыть публичную утечку PII.
-- Применено 2026-06-22 через Supabase MCP после security-аудита (get_advisors).
-- Проблема: вьюхи v_clients/v_gifts — SECURITY DEFINER и были выданы роли anon на
-- SELECT (+запись) → по ПУБЛИЧНОМУ anon-ключу можно было читать всех клиентов
-- (имена/телефоны/почты) и подарочные коды в обход RLS.
-- Бот/сайт/приложение работают через RPC (app_upsert_lead, get_kote_context, ...),
-- этими вьюхами не пользуются. HQ (authenticated) доступ сохраняет.
-- Проверено: у anon не осталось грантов на эти вьюхи.

REVOKE ALL ON public.v_clients FROM anon;
REVOKE ALL ON public.v_gifts   FROM anon;

-- TODO (следующий заход, не блокер запуска):
--  • перевести v_clients/v_gifts на SECURITY INVOKER и закрыть RLS даже для authenticated
--    не-админов (сейчас любой залогиненный видит вьюху — гейтить через is_admin());
--  • get_bookings_by_phone — добавить секрет/лимит (сейчас anon без гейта);
--  • get_funnel_stats — ограничить ролью authenticated;
--  • включить leaked-password protection в Auth.
