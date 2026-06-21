-- 008 — Авто-уведомление клиента при смене статуса брони (#3)
-- Применено в боевой базе 2026-06-21 через Supabase MCP.
-- bookings.notified_status хранит последний статус, о котором клиент уже уведомлён.
-- bot_booking_status_changes() атомарно возвращает брони со сменившимся статусом
-- (кроме «Новый»/тест/архив, только клиенты с tg_chat_id) и помечает их уведомлёнными.

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS notified_status text;

CREATE OR REPLACE FUNCTION public.bot_booking_status_changes(p_secret text DEFAULT '')
RETURNS TABLE(tg_chat_id text, client_name text, tour_name text, status text, date_start date, booking_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  WITH changed AS (
    SELECT b.id AS bid, c.tg_chat_id AS chat, c.name AS cname,
           b.tour_name AS tname, b.status AS st, b.date_start AS ds
    FROM bookings b JOIN clients c ON c.id = b.client_id
    WHERE b.status IS DISTINCT FROM b.notified_status
      AND b.status <> 'Новый'
      AND b.status NOT ILIKE '%тест%' AND b.status NOT ILIKE '%архив%'
      AND c.tg_chat_id IS NOT NULL AND c.tg_chat_id <> ''
  ), upd AS (
    UPDATE bookings SET notified_status = status WHERE id IN (SELECT bid FROM changed)
  )
  SELECT chat, cname, tname, st, ds, bid FROM changed;
END; $function$;

GRANT EXECUTE ON FUNCTION public.bot_booking_status_changes(text) TO anon;
