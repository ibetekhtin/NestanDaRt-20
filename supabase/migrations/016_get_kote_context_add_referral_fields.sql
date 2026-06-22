-- 016 — get_kote_context: добавить bonus_balance + ref_code.
-- Применено 2026-06-22 (Supabase MCP). DROP+CREATE нужен: PostgreSQL запрещает менять RETURNS TABLE.
-- КотЭ теперь видит бонусный счёт клиента и его реф-ссылку — рефералка полностью работает в боте.

DROP FUNCTION IF EXISTS public.get_kote_context(text, text, text);

CREATE FUNCTION public.get_kote_context(
  p_tg_chat_id text,
  p_query      text DEFAULT NULL::text,
  p_secret     text DEFAULT NULL::text
)
RETURNS TABLE(
  client_id          uuid,
  client_name        text,
  client_stage       text,
  is_new_client      boolean,
  client_country     text,
  interests          text[],
  budget_level       text,
  travel_style       text,
  last_tour_viewed   text,
  tours_viewed       text[],
  tours_booked       text[],
  last_conversations jsonb,
  arrival_date       text,
  group_size         integer,
  has_children       boolean,
  tours_catalog      jsonb,
  knowledge_pack     jsonb,
  bonus_balance      integer,
  ref_code           text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_id          uuid;
  v_name        text;
  v_stage       text;
  v_country     text;
  v_created_at  timestamptz;
  v_bonus       integer;
  v_ref         text;
  v_authorized  boolean;
begin
  v_authorized := encode(extensions.digest(coalesce(p_secret,''), 'sha256'), 'hex')
                  = '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda';

  if v_authorized then
    select c.id, c.name, c.stage, c.country, c.created_at,
           coalesce(c.bonus_balance, 0), c.ref_code
      into v_id, v_name, v_stage, v_country, v_created_at, v_bonus, v_ref
      from clients c where c.tg_chat_id = p_tg_chat_id limit 1;
  end if;

  return query
  select
    case when v_authorized then v_id end,
    case when v_authorized then v_name end,
    coalesce(v_stage, 'new'),
    (v_id is null or now() - v_created_at < interval '5 minutes'),
    v_country,
    coalesce(cm.interests, '{}'),
    coalesce(cm.budget_level, 'medium'),
    cm.travel_style,
    cm.last_tour_viewed,
    coalesce(cm.tours_viewed, '{}'),
    coalesce(cm.tours_booked, '{}'),
    case when v_authorized then
      coalesce((
        select jsonb_agg(jsonb_build_object('msg', cv.message, 'res', cv.response) order by cv.created_at desc)
        from (
          select message, response, created_at from conversations
          where conversations.client_id = v_id
          order by created_at desc limit 10
        ) cv
      ), '[]'::jsonb)
    else '[]'::jsonb end,
    cm.arrival_date,
    cm.group_size,
    coalesce(cm.has_children, false),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        't', t.title, 'city', t.city, 'cat', t.category,
        'price', t.price_adult, 'child', t.price_child,
        'dur', t.duration, 'slug', t.slug, 'season', t.season_note
      ) order by t.city, t.sort_order)
      from tours t where t.active
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object('t', k.title, 'c', k.content, 'tip', k.insider_tip, 'city', k.city))
      from (
        (select * from knowledge where active and priority >= 88 and city = 'Общее' limit 4)
        union
        (select * from knowledge where active and p_query is not null
          and (title || ' ' || content) ilike any(
            select '%' || w || '%'
            from unnest(string_to_array(lower(p_query), ' ')) w
            where length(w) > 3
          )
          order by priority desc limit 6
        )
      ) k
    ), '[]'::jsonb),
    case when v_authorized then v_bonus else 0 end,
    case when v_authorized then v_ref  else null end
  from (select 1) one
  left join client_memory cm on v_authorized and cm.client_id = v_id;
end;
$function$;

GRANT EXECUTE ON FUNCTION public.get_kote_context(text, text, text) TO anon, authenticated, service_role;
