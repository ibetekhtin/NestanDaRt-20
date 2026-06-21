-- 009 — Дожим зависших броней (#6)
-- Применено в боевой базе 2026-06-21 через Supabase MCP.
-- bookings.nudged_at — когда клиента уже мягко дожали (чтобы не повторяться).
-- bot_abandoned_bookings() возвращает брони Telegram-клиентов, застрявшие в «Новый»
-- дольше p_hours и ещё не дожатые, и помечает их nudged_at = now().

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS nudged_at timestamptz;

CREATE OR REPLACE FUNCTION public.bot_abandoned_bookings(p_secret text DEFAULT '', p_hours integer DEFAULT 24)
RETURNS TABLE(tg_chat_id text, client_name text, tour_name text, booking_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  WITH stuck AS (
    SELECT b.id AS bid, c.tg_chat_id AS chat, c.name AS cname, b.tour_name AS tname
    FROM bookings b JOIN clients c ON c.id = b.client_id
    WHERE b.status = 'Новый'
      AND b.created_at < now() - (p_hours || ' hours')::interval
      AND b.nudged_at IS NULL
      AND c.tg_chat_id IS NOT NULL AND c.tg_chat_id <> ''
  ), upd AS (
    UPDATE bookings SET nudged_at = now() WHERE id IN (SELECT bid FROM stuck)
  )
  SELECT chat, cname, tname, bid FROM stuck;
END; $function$;

GRANT EXECUTE ON FUNCTION public.bot_abandoned_bookings(text, integer) TO anon;
