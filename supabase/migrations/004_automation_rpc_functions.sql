-- ── Функция 1: Новые лиды за последние N минут ──────────────────────────────
CREATE OR REPLACE FUNCTION public.get_new_leads(p_minutes int DEFAULT 6)
RETURNS TABLE (
  id          uuid,
  name        text,
  phone       text,
  tg_chat_id  text,
  source      text,
  created_at  timestamptz
) LANGUAGE sql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $$
  SELECT id, name, phone, tg_chat_id, source, created_at
  FROM clients
  WHERE created_at > NOW() - (p_minutes || ' minutes')::INTERVAL
  ORDER BY created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.get_new_leads(int) TO anon;


-- ── Функция 2: Брони на N дней вперёд (напоминание накануне тура) ───────────
CREATE OR REPLACE FUNCTION public.get_tour_reminders(p_days_ahead int DEFAULT 1)
RETURNS TABLE (
  booking_id   uuid,
  tour_name    text,
  date_start   date,
  people_count int,
  client_name  text,
  tg_chat_id   text,
  phone        text
) LANGUAGE sql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $$
  SELECT b.id,
         b.tour_name,
         b.date_start,
         b.people_count,
         c.name,
         c.tg_chat_id,
         c.phone
  FROM bookings b
  JOIN clients c ON b.client_id = c.id
  WHERE b.date_start = (CURRENT_DATE + (p_days_ahead || ' days')::INTERVAL)::date
    AND b.status IN ('Подтверждена', 'Оплачено')
    AND c.tg_chat_id IS NOT NULL
  ORDER BY b.date_start;
$$;
GRANT EXECUTE ON FUNCTION public.get_tour_reminders(int) TO anon;


-- ── Функция 3: Туры которые завершились N дней назад (запрос отзыва) ────────
CREATE OR REPLACE FUNCTION public.get_review_requests(p_days_ago int DEFAULT 0)
RETURNS TABLE (
  booking_id   uuid,
  tour_name    text,
  date_start   date,
  client_name  text,
  tg_chat_id   text
) LANGUAGE sql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $$
  SELECT b.id,
         b.tour_name,
         b.date_start,
         c.name,
         c.tg_chat_id
  FROM bookings b
  JOIN clients c ON b.client_id = c.id
  WHERE b.date_start = (CURRENT_DATE - (p_days_ago || ' days')::INTERVAL)::date
    AND b.status IN ('Оплачено', 'Завершено')
    AND c.tg_chat_id IS NOT NULL
  ORDER BY b.date_start;
$$;
GRANT EXECUTE ON FUNCTION public.get_review_requests(int) TO anon;
