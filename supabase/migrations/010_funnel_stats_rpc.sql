-- 010 — Агрегаты воронки для дашборда HQ (#5)
-- Применено в боевой базе 2026-06-21 через Supabase MCP.
-- Одна читалка для вкладки «Воронка»: сообщения → клиенты → брони → оплаты,
-- плюс разбивки по источнику и статусу. SECURITY DEFINER (аккуратно обходит RLS
-- для агрегатов), доступна anon + authenticated.

CREATE OR REPLACE FUNCTION public.get_funnel_stats()
RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
  SELECT jsonb_build_object(
    'messages',  (SELECT count(*) FROM conversations),
    'clients',   (SELECT count(*) FROM clients),
    'bookings',  (SELECT count(*) FROM bookings WHERE coalesce(status,'') NOT ILIKE '%тест%' AND coalesce(status,'') NOT ILIKE '%архив%'),
    'paid',      (SELECT count(*) FROM payments WHERE status = 'succeeded'),
    'revenue',   (SELECT coalesce(sum(amount),0) FROM payments WHERE status = 'succeeded'),
    'by_source', (SELECT coalesce(jsonb_object_agg(src, cnt),'{}'::jsonb)
                  FROM (SELECT coalesce(source,'—') AS src, count(*) AS cnt FROM bookings GROUP BY 1 ORDER BY 2 DESC) s),
    'by_status', (SELECT coalesce(jsonb_object_agg(st, cnt),'{}'::jsonb)
                  FROM (SELECT coalesce(status,'—') AS st, count(*) AS cnt FROM bookings GROUP BY 1 ORDER BY 2 DESC) s)
  );
$function$;

GRANT EXECUTE ON FUNCTION public.get_funnel_stats() TO anon, authenticated;
