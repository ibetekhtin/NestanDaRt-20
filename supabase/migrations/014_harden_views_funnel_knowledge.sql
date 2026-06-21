-- 014 — Харднинг безопасности по итогам get_advisors. Применено 2026-06-22 (Supabase MCP).
-- Проверено ролевой импесонацией: не-админ видит v_clients = 0 строк, админ = все.

-- 1) v_clients/v_gifts → SECURITY INVOKER. Раньше были SECURITY DEFINER (обходили RLS).
--    Теперь применяется RLS подлежащих таблиц: clients/bookings/gift_certificates имеют
--    политику USING is_admin() → только владелец видит данные; reviews/packages публичны.
--    anon доступ к вьюхам уже отозван (миграция 013).
ALTER VIEW public.v_clients SET (security_invoker = true);
ALTER VIEW public.v_gifts   SET (security_invoker = true);

-- 2) get_funnel_stats — снять публичный anon, оставить authenticated (HQ под логином).
REVOKE EXECUTE ON FUNCTION public.get_funnel_stats() FROM anon;

-- 3) knowledge: убрать дублирующую permissive SELECT-политику. knowledge_service_write был
--    ALL для service_role, но service_role обходит RLS → политика избыточна и порождала
--    две permissive-политики на SELECT. Чтение остаётся на knowledge_read_all (active=true).
DROP POLICY IF EXISTS knowledge_service_write ON public.knowledge;

-- НЕ ТРОГАЕМ get_bookings_by_phone: его напрямую (anon) зовут приложения
-- (platform/app/index.html, app-hyper.html) — клиент смотрит свои брони. Секрет в публичный
-- фронт не положить. Правильный харднинг = перевести вызов на backend /api/v1/bookings
-- (там rate-limit nginx) — это фронт-задача владельца.

-- Auth → leaked-password protection включается в Дашборде (Authentication → Sign In/Up →
-- Password) — это не SQL.
