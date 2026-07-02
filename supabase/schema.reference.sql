-- АВТОДАМП боевой схемы (pg_dump --schema-only), проект cmmdrhususjuadqzyssc, 2026-07-02.
-- Обновление: pg_dump "$SUPABASE_DB_URL" --schema-only --schema=public --no-owner > supabase/schema.reference.sql
--
-- PostgreSQL database dump
--

\restrict rApyPbbkodbm9xWOnsXWnscBxZIpbZLhQLsspiIUCx54ZQNQJdHJ6cGDUaxe1GI

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.10 (Ubuntu 17.10-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: app_mark_paid(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_mark_paid(p_external_id text, p_secret text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE v_id uuid; v_old text;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT status INTO v_old FROM bookings WHERE external_id = p_external_id LIMIT 1;
  UPDATE bookings SET status = 'Оплачено' WHERE external_id = p_external_id RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', v_id IS NOT NULL, 'booking_id', v_id, 'prev_status', v_old);
END; $$;


--
-- Name: app_set_booking_status(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_set_booking_status(p_external_id text, p_status text, p_secret text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE v_id uuid; v_old text;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT status INTO v_old FROM bookings WHERE external_id=p_external_id LIMIT 1;
  UPDATE bookings SET status=p_status WHERE external_id=p_external_id RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', v_id IS NOT NULL, 'booking_id', v_id, 'prev_status', v_old);
END; $$;


--
-- Name: app_upsert_lead(text, text, text, text, text, text, text, text, text, text, text, text, date, integer, integer, integer, text, text, integer, integer, integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_upsert_lead(p_external_id text, p_source text DEFAULT 'Сайт'::text, p_name text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_telegram text DEFAULT NULL::text, p_tg_chat_id text DEFAULT NULL::text, p_whatsapp text DEFAULT NULL::text, p_instagram text DEFAULT NULL::text, p_vk text DEFAULT NULL::text, p_tour_name text DEFAULT NULL::text, p_tour_slug text DEFAULT NULL::text, p_date_start date DEFAULT NULL::date, p_people integer DEFAULT NULL::integer, p_budget integer DEFAULT NULL::integer, p_total integer DEFAULT NULL::integer, p_comment text DEFAULT NULL::text, p_status text DEFAULT 'Новый'::text, p_adults integer DEFAULT NULL::integer, p_children integer DEFAULT NULL::integer, p_infants integer DEFAULT NULL::integer, p_ref_code text DEFAULT NULL::text, p_secret text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_client_id uuid; v_booking_id uuid; v_tour_id uuid;
  v_is_new_client boolean := false; v_is_new_booking boolean := false;
  v_email text := lower(nullif(trim(p_email), ''));
  v_ref text := upper(nullif(trim(p_ref_code), '')); v_ref_valid text := NULL;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF p_phone IS NOT NULL THEN SELECT id INTO v_client_id FROM clients WHERE phone = p_phone LIMIT 1; END IF;
  IF v_client_id IS NULL AND p_tg_chat_id IS NOT NULL THEN SELECT id INTO v_client_id FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1; END IF;
  IF v_client_id IS NULL AND v_email IS NOT NULL THEN SELECT id INTO v_client_id FROM clients WHERE lower(email) = v_email LIMIT 1; END IF;
  IF v_ref IS NOT NULL THEN SELECT ref_code INTO v_ref_valid FROM clients WHERE ref_code = v_ref LIMIT 1; END IF;

  IF v_client_id IS NULL THEN
    INSERT INTO clients (name, phone, email, telegram, tg_chat_id, whatsapp, instagram, vk, source, status, referred_by, first_contact, last_contact)
    VALUES (COALESCE(NULLIF(trim(p_name),''),'Без имени'), p_phone, v_email, p_telegram, p_tg_chat_id, p_whatsapp, p_instagram, p_vk, p_source, 'Новый', v_ref_valid, now(), now())
    RETURNING id INTO v_client_id;
    v_is_new_client := true;
  ELSE
    UPDATE clients SET
      name=COALESCE(NULLIF(trim(p_name),''),name), phone=COALESCE(p_phone,phone), email=COALESCE(v_email,email),
      telegram=COALESCE(p_telegram,telegram), tg_chat_id=COALESCE(p_tg_chat_id,tg_chat_id),
      whatsapp=COALESCE(p_whatsapp,whatsapp), instagram=COALESCE(p_instagram,instagram), vk=COALESCE(p_vk,vk),
      referred_by=CASE WHEN (referred_by IS NULL OR referred_by='') AND v_ref_valid IS NOT NULL AND v_ref_valid<>ref_code THEN v_ref_valid ELSE referred_by END,
      last_contact=now()
    WHERE id=v_client_id;
  END IF;

  IF p_tour_slug IS NOT NULL THEN SELECT id INTO v_tour_id FROM tours WHERE slug = p_tour_slug LIMIT 1; END IF;
  IF p_external_id IS NOT NULL THEN SELECT id INTO v_booking_id FROM bookings WHERE external_id = p_external_id LIMIT 1; END IF;

  IF v_booking_id IS NULL THEN
    INSERT INTO bookings (external_id, client_id, tour_id, tour_name, date_start, people_count, adults, children, infants, budget, total, comment, source, status)
    VALUES (p_external_id, v_client_id, v_tour_id, p_tour_name, p_date_start, p_people, p_adults, p_children, p_infants, p_budget, p_total, p_comment, p_source, p_status)
    RETURNING id INTO v_booking_id;
    v_is_new_booking := true;
  ELSE
    UPDATE bookings SET
      client_id=COALESCE(v_client_id,client_id), tour_id=COALESCE(v_tour_id,tour_id),
      tour_name=COALESCE(p_tour_name,tour_name), date_start=COALESCE(p_date_start,date_start),
      people_count=COALESCE(p_people,people_count), adults=COALESCE(p_adults,adults),
      children=COALESCE(p_children,children), infants=COALESCE(p_infants,infants),
      budget=COALESCE(p_budget,budget), total=COALESCE(p_total,total), comment=COALESCE(p_comment,comment),
      status=CASE WHEN p_status IS NOT NULL AND p_status <> 'Новый' THEN p_status ELSE status END
    WHERE id=v_booking_id;
  END IF;

  INSERT INTO action_history (client_id, booking_id, action, details)
  VALUES (v_client_id, v_booking_id, CASE WHEN v_is_new_booking THEN 'lead_created' ELSE 'lead_updated' END,
          jsonb_build_object('source',p_source,'external_id',p_external_id,'tour',p_tour_name,'status',p_status,'referred_by',v_ref_valid));

  RETURN jsonb_build_object('client_id',v_client_id,'booking_id',v_booking_id,'is_new_client',v_is_new_client,'is_new_booking',v_is_new_booking);
END; $$;


--
-- Name: apply_referral(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_referral(p_tg_chat_id text, p_ref_code text, p_secret text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE v_client uuid; v_client_ref text; v_client_refby text; v_owner uuid;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT id, ref_code, referred_by INTO v_client, v_client_ref, v_client_refby
    FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1;
  IF v_client IS NULL THEN RETURN jsonb_build_object('ok', false, 'reason', 'client_not_found'); END IF;
  -- уже привязан → честный no-op
  IF v_client_refby IS NOT NULL AND v_client_refby <> '' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_referred', 'referred_by', v_client_refby);
  END IF;
  SELECT id INTO v_owner FROM clients WHERE ref_code = upper(p_ref_code) AND id <> v_client LIMIT 1;
  IF v_owner IS NULL THEN RETURN jsonb_build_object('ok', false, 'reason', 'bad_code'); END IF;
  IF EXISTS (SELECT 1 FROM clients WHERE id = v_owner AND referred_by IS NOT NULL AND referred_by <> '' AND referred_by = v_client_ref) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'circular_referral');
  END IF;
  UPDATE clients SET referred_by = upper(p_ref_code) WHERE id = v_client AND (referred_by IS NULL OR referred_by = '');
  RETURN jsonb_build_object('ok', true, 'referrer', v_owner);
END; $$;


--
-- Name: bookings_credit_referral_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bookings_credit_referral_trigger() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.status IN ('Оплачено', 'Завершён') AND
     (OLD.status IS DISTINCT FROM NEW.status) AND
     NEW.referral_credited_at IS NULL THEN
    PERFORM credit_referral(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: bot_abandoned_bookings(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bot_abandoned_bookings(p_secret text DEFAULT ''::text, p_hours integer DEFAULT 24) RETURNS TABLE(tg_chat_id text, client_name text, tour_name text, booking_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
END; $$;


--
-- Name: bot_booking_status_changes(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bot_booking_status_changes(p_secret text DEFAULT ''::text) RETURNS TABLE(tg_chat_id text, client_name text, tour_name text, status text, date_start date, booking_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
    UPDATE bookings b2 SET notified_status = b2.status WHERE b2.id IN (SELECT bid FROM changed)
  )
  SELECT chat, cname, tname, st, ds, bid FROM changed;
END; $$;


--
-- Name: bot_upsert_client(text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bot_upsert_client(p_tg_chat_id text, p_name text DEFAULT NULL::text, p_source text DEFAULT 'telegram'::text, p_secret text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE v_client_id uuid; v_is_new boolean := false;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT id INTO v_client_id FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1;
  IF v_client_id IS NULL THEN
    INSERT INTO clients (name, tg_chat_id, source, status, first_contact, last_contact)
    VALUES (COALESCE(NULLIF(trim(p_name),''), 'Гость'), p_tg_chat_id, p_source, 'Новый', now(), now())
    RETURNING id INTO v_client_id;
    v_is_new := true;
  ELSE
    UPDATE clients SET name = COALESCE(NULLIF(trim(p_name),''), name), last_contact = now()
     WHERE id = v_client_id;
  END IF;
  RETURN jsonb_build_object('client_id', v_client_id, 'is_new', v_is_new);
END;
$$;


--
-- Name: credit_referral(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.credit_referral(p_booking_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_client_id    uuid;
  v_ref_code     text;
  v_partner      partners%ROWTYPE;
  v_total        numeric;
  v_earned       numeric;
BEGIN
  -- Уже начислено?
  IF EXISTS (SELECT 1 FROM bookings WHERE id = p_booking_id AND referral_credited_at IS NOT NULL) THEN
    RETURN;
  END IF;

  -- Берём клиента и его реф-код
  SELECT b.client_id, b.total INTO v_client_id, v_total
  FROM bookings b WHERE b.id = p_booking_id;

  SELECT ref_code INTO v_ref_code FROM clients WHERE id = v_client_id;
  IF v_ref_code IS NULL THEN RETURN; END IF;

  -- Ищем партнёра по промокоду
  SELECT * INTO v_partner FROM partners WHERE promo = v_ref_code AND active = true;
  IF NOT FOUND THEN RETURN; END IF;

  -- Считаем бонус (max 3.5%)
  v_earned := ROUND(COALESCE(v_total, 0) * LEAST(v_partner.commission, 3.5) / 100, 2);

  -- Записываем начисление
  INSERT INTO referrals (partner_id, client_id, booking_id, booking_total, commission_pct, earned_thb)
  VALUES (v_partner.id, v_client_id, p_booking_id, COALESCE(v_total, 0), v_partner.commission, v_earned);

  -- Пополняем баланс партнёра
  UPDATE partners SET
    balance_thb = balance_thb + v_earned,
    total_sales = total_sales + 1
  WHERE id = v_partner.id;

  -- Помечаем бронь
  UPDATE bookings SET referral_credited_at = now() WHERE id = p_booking_id;
END;
$$;


--
-- Name: get_bookings_by_phone(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bookings_by_phone(p_phone text) RETURNS TABLE(id uuid, external_id text, tour_name text, date_start date, adults integer, children integer, total integer, status text, source text, created_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT b.id, b.external_id, b.tour_name, b.date_start, b.adults, b.children, b.total, b.status, b.source, b.created_at
  FROM public.bookings b JOIN public.clients c ON c.id = b.client_id
  WHERE c.phone = regexp_replace(p_phone, '[^0-9+]', '', 'g') OR c.phone = p_phone
  ORDER BY b.created_at DESC LIMIT 50;
$$;


--
-- Name: get_funnel_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_funnel_stats() RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
$$;


--
-- Name: get_kote_context(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_kote_context(p_tg_chat_id text, p_query text DEFAULT NULL::text, p_secret text DEFAULT NULL::text) RETURNS TABLE(client_id uuid, client_name text, client_stage text, is_new_client boolean, client_country text, interests text[], budget_level text, travel_style text, last_tour_viewed text, tours_viewed text[], tours_booked text[], last_conversations jsonb, arrival_date text, group_size integer, has_children boolean, tours_catalog jsonb, knowledge_pack jsonb, bonus_balance integer, ref_code text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_id uuid; v_name text; v_stage text; v_country text; v_created_at timestamptz;
  v_bonus integer; v_ref text; v_authorized boolean;
  v_market text; v_market_city text; v_ltv text;
begin
  v_authorized := encode(extensions.digest(coalesce(p_secret,''), 'sha256'), 'hex')
                  = '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda';
  if v_authorized then
    select c.id, c.name, c.stage, c.country, c.created_at, coalesce(c.bonus_balance,0), c.ref_code, c.market
      into v_id, v_name, v_stage, v_country, v_created_at, v_bonus, v_ref, v_market
      from clients c where c.tg_chat_id = p_tg_chat_id limit 1;

    if v_market is null and v_id is not null then
      select cm2.last_tour_viewed into v_ltv from client_memory cm2 where cm2.client_id = v_id limit 1;
      if v_ltv is not null then
        select t.market_id into v_market from tours t where t.slug = v_ltv limit 1;
        if v_market is null then
          v_market := case when v_ltv like 'pt-%' then 'pattaya'
                           when v_ltv like 'vn-%' then 'vietnam'
                           when v_ltv like 'ph-%' then 'phuket' else null end;
        end if;
      end if;
      if v_market is null then
        select t.market_id into v_market
          from bookings b join tours t on t.id = b.tour_id
          where b.client_id = v_id and t.market_id is not null
          order by b.created_at desc limit 1;
      end if;
    end if;
    v_market_city := case v_market when 'phuket' then 'Пхукет' when 'pattaya' then 'Паттайя' when 'vietnam' then 'Вьетнам' else null end;
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
      coalesce((select jsonb_agg(jsonb_build_object('msg', cv.message, 'res', cv.response) order by cv.created_at desc)
        from (select message, response, created_at from conversations where conversations.client_id = v_id order by created_at desc limit 10) cv), '[]'::jsonb)
    else '[]'::jsonb end,
    cm.arrival_date, cm.group_size, coalesce(cm.has_children, false),
    coalesce((
      select jsonb_agg(jsonb_build_object('t', t.title, 'city', t.city, 'cat', t.category,
        'price', t.price_adult, 'child', t.price_child, 'dur', t.duration, 'slug', t.slug, 'season', t.season_note)
        order by t.city, t.sort_order)
      from tours t where t.active and (v_market is null or t.market_id = v_market)
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(jsonb_build_object('t', k.title, 'c', k.content, 'tip', k.insider_tip, 'city', k.city))
      from (
        (select * from knowledge where active and priority >= 88 and city = 'Общее' limit 4)
        union
        (select * from knowledge where active and p_query is not null
          and (v_market_city is null or city in (v_market_city, 'Общее'))
          and (title || ' ' || content) ilike any(
            select '%' || w || '%' from unnest(string_to_array(lower(p_query), ' ')) w where length(w) > 3)
          order by priority desc limit 6)
      ) k
    ), '[]'::jsonb),
    case when v_authorized then v_bonus else 0 end,
    case when v_authorized then v_ref else null end
  from (select 1) one
  left join client_memory cm on v_authorized and cm.client_id = v_id;
end;
$$;


--
-- Name: get_new_leads(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_new_leads(p_minutes integer DEFAULT 6, p_secret text DEFAULT ''::text) RETURNS TABLE(id uuid, name text, phone text, tg_chat_id text, source text, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  SELECT c.id, c.name, c.phone, c.tg_chat_id, c.source, c.created_at
  FROM clients c
  WHERE c.created_at > NOW() - (p_minutes || ' minutes')::INTERVAL
  ORDER BY c.created_at DESC;
END; $$;


--
-- Name: get_referral_stats(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_referral_stats(p_tg_chat_id text, p_secret text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_client_id   uuid;
  v_ref_code    text;
  v_balance     integer;
  v_stats       jsonb;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''), 'sha256'), 'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT id, ref_code, coalesce(bonus_balance, 0)
    INTO v_client_id, v_ref_code, v_balance
    FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1;

  IF v_client_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'client_not_found');
  END IF;

  SELECT jsonb_build_object(
    'ok',           true,
    'ref_code',     v_ref_code,
    'ref_link',     'https://t.me/phuket_nestandart_bot?start=ref_' || v_ref_code,
    'bonus_balance', v_balance,
    'friends_paid', coalesce(ev.cnt, 0),
    'total_earned', coalesce(ev.total_earned, 0),
    'next_tier_pct', CASE
      WHEN coalesce(ev.cnt, 0) = 0 THEN 2.50
      WHEN coalesce(ev.cnt, 0) = 1 THEN 3.00
      WHEN coalesce(ev.cnt, 0) = 2 THEN 3.50
      ELSE null
    END,
    'events',       ev.events
  ) INTO v_stats
  FROM (
    SELECT
      count(*)                                          AS cnt,
      sum(bonus_credited)                               AS total_earned,
      jsonb_agg(jsonb_build_object(
        'tier', tier, 'pct', pct,
        'bonus', bonus_credited, 'at', created_at
      ) ORDER BY created_at) AS events
    FROM referral_events WHERE referrer_id = v_client_id
  ) ev;

  RETURN v_stats;
END;
$$;


--
-- Name: get_review_requests(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_review_requests(p_days_ago integer DEFAULT 0, p_secret text DEFAULT ''::text) RETURNS TABLE(booking_id uuid, tour_name text, date_start date, client_name text, tg_chat_id text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''), 'sha256'), 'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
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
END;
$$;


--
-- Name: get_tour_reminders(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_tour_reminders(p_days_ahead integer DEFAULT 1, p_secret text DEFAULT ''::text) RETURNS TABLE(booking_id uuid, tour_name text, date_start date, people_count integer, client_name text, tg_chat_id text, phone text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''), 'sha256'), 'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
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
END;
$$;


--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$ select coalesce(auth.jwt()->>'email', '') = 'ibetekhtin@gmail.com' $$;


--
-- Name: partners_set_commission(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.partners_set_commission() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  NEW.commission := CASE NEW.level
    WHEN 1 THEN 1.5
    WHEN 2 THEN 2.5
    WHEN 3 THEN 3.5
    ELSE 1.5
  END;
  RETURN NEW;
END;
$$;


--
-- Name: pay_stuck_report(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pay_stuck_report(p_secret text DEFAULT ''::text, p_hours integer DEFAULT 2) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE v_stale int; v_paid_nb int;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT count(*) INTO v_stale FROM payments WHERE status='pending' AND created_at < now() - (p_hours||' hours')::interval;
  SELECT count(*) INTO v_paid_nb FROM payments p WHERE p.status='succeeded'
     AND NOT EXISTS (SELECT 1 FROM bookings b WHERE b.id=p.booking_id AND b.status='Оплачено');
  RETURN jsonb_build_object('stale_pending', v_stale, 'paid_without_booking', v_paid_nb);
END; $$;


--
-- Name: redeem_gift(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_gift(p_code text, p_tg_chat_id text, p_secret text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_cert gift_certificates%rowtype;
  v_client_id uuid;
begin
  if encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     <> '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' then
    return jsonb_build_object('ok', false, 'error', 'unauthorized');
  end if;

  select id into v_client_id from clients where tg_chat_id = p_tg_chat_id limit 1;

  -- блокируем строку сертификата на время транзакции
  select * into v_cert from gift_certificates where code = p_code for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_cert.status = 'redeemed' then
    return jsonb_build_object('ok', false, 'error', 'already_redeemed');
  end if;
  if v_cert.status <> 'paid' then
    return jsonb_build_object('ok', false, 'error', 'not_paid');
  end if;

  -- «зачёркиваем» — больше никто не использует
  update gift_certificates
     set status = 'redeemed', redeemed_by_client_id = v_client_id, redeemed_at = now()
   where id = v_cert.id;

  -- зачисляем номинал получателю на бонусный баланс (баты)
  if v_client_id is not null then
    update clients set bonus_balance = coalesce(bonus_balance,0) + coalesce(v_cert.amount_thb,0)
     where id = v_client_id;
  end if;

  return jsonb_build_object('ok', true, 'amount', coalesce(v_cert.amount_thb,0),
                            'package', v_cert.package_slug);
end
$$;


--
-- Name: search_knowledge(text, text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_knowledge(p_query text, p_category text DEFAULT NULL::text, p_city text DEFAULT 'Пхукет'::text, p_limit integer DEFAULT 3) RETURNS TABLE(title text, content text, category text, area text, price_info text, best_time text, insider_tip text, related_tour_slug text, rank real)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_tsquery tsquery;
  v_city    text;
BEGIN
  p_limit := greatest(1, least(coalesce(p_limit,3), 5));

  -- Эффективный город: явное упоминание в самом запросе важнее контекста (p_city).
  -- Если ни в запросе, ни в контексте города нет — дефолт Пхукет.
  v_city := CASE
    WHEN lower(p_query) ~ 'паттай'             THEN 'Паттайя'
    WHEN lower(p_query) ~ 'пхукет'             THEN 'Пхукет'
    WHEN p_city IN ('Паттайя','Пхукет')        THEN p_city
    ELSE 'Пхукет'
  END;

  SELECT to_tsquery('russian', string_agg(lexeme || ':*', ' | '))
    INTO v_tsquery
  FROM (
    SELECT regexp_replace(word, '[^а-яёa-z0-9]', '', 'g') AS lexeme
    FROM unnest(string_to_array(lower(p_query), ' ')) AS word
    WHERE length(regexp_replace(word, '[^а-яёa-z0-9]', '', 'g')) >= 3
  ) w
  WHERE lexeme <> '';

  RETURN QUERY
  SELECT k.title, k.content, k.category, k.area,
         k.price_info, k.best_time, k.insider_tip,
         k.related_tour_slug,
         ( coalesce(ts_rank(to_tsvector('russian', k.title || ' ' || k.content), v_tsquery), 0) * 2
           + similarity(k.title || ' ' || k.content, p_query)
           + k.priority / 200.0
           + CASE
               WHEN k.city = v_city  THEN 0.40    -- сильный буст «своему» городу
               WHEN k.city = 'Общее' THEN 0.10    -- общее (визы, деньги, безопасность) всегда уместно
               ELSE -0.50                          -- штраф «чужому» городу: Пхукет не лезет в ответы про Паттайю и наоборот
             END
         )::real AS rank
  FROM knowledge k
  WHERE k.active
    AND (p_category IS NULL OR k.category = p_category)
    AND (
      (v_tsquery IS NOT NULL AND to_tsvector('russian', k.title || ' ' || k.content) @@ v_tsquery)
      OR similarity(k.title || ' ' || k.content, p_query) > 0.05
      OR k.tags && string_to_array(lower(p_query), ' ')
    )
  ORDER BY rank DESC
  LIMIT p_limit;
END;
$$;


--
-- Name: spend_bonus(text, numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.spend_bonus(p_tg_chat_id text, p_amount_thb numeric, p_secret text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_id uuid;
  v_bal numeric;
  v_applied numeric;
begin
  if encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     <> '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' then
    return jsonb_build_object('ok', false, 'applied', 0);
  end if;

  select id, coalesce(bonus_balance,0) into v_id, v_bal
    from clients where tg_chat_id = p_tg_chat_id for update;
  if v_id is null then
    return jsonb_build_object('ok', false, 'applied', 0);
  end if;

  v_applied := least(greatest(v_bal,0), greatest(p_amount_thb,0));
  if v_applied > 0 then
    update clients set bonus_balance = v_bal - v_applied where id = v_id;
  end if;
  return jsonb_build_object('ok', true, 'applied', v_applied, 'balance_left', v_bal - v_applied);
end
$$;


--
-- Name: trg_booking_status_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_booking_status_history() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if old.status is distinct from new.status then
    insert into action_history (client_id, booking_id, action, details)
    values (
      new.client_id, new.id, 'booking_status_changed',
      jsonb_build_object('old_status', old.status, 'new_status', new.status,
                          'tour_name', new.tour_name, 'source', new.source)
    );
  end if;
  return new;
end;
$$;


--
-- Name: trg_client_stage_from_booking(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_client_stage_from_booking() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_rank constant jsonb := '{"new":0,"interest":1,"thinking":2,"booking":3,"done":4,"cold":0}';
  v_target text;
  v_cur text;
begin
  if new.client_id is null then return new; end if;

  -- какая стадия соответствует событию
  if new.status in ('Оплачено','Завершён') then
    v_target := 'done';
  elsif new.status in ('Новый','Ждёт оплату') then
    v_target := 'booking';
  else
    v_target := null;
  end if;

  if v_target is null then return new; end if;

  select stage into v_cur from clients where id = new.client_id;

  -- двигаем только вперёд
  if (v_rank->>v_target)::int > (v_rank->>coalesce(v_cur,'new'))::int then
    update clients set stage = v_target, last_contact = now()
     where id = new.client_id;
  end if;

  return new;
end;
$$;


--
-- Name: trg_payment_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_payment_history() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_client_id uuid;
begin
  select client_id into v_client_id from bookings where id = new.booking_id;

  if tg_op = 'INSERT' then
    insert into action_history (client_id, booking_id, action, details)
    values (v_client_id, new.booking_id, 'payment_created',
            jsonb_build_object('amount', new.amount, 'currency', new.currency,
                                'status', new.status, 'provider', new.provider));
  elsif old.status is distinct from new.status then
    insert into action_history (client_id, booking_id, action, details)
    values (v_client_id, new.booking_id, 'payment_status_changed',
            jsonb_build_object('old_status', old.status, 'new_status', new.status,
                                'amount', new.amount));

    if new.status = 'succeeded' then
      if new.paid_at is null then
        new.paid_at := now();
      end if;
      update bookings
         set status = 'Оплачено'
       where id = new.booking_id
         and status not in ('Оплачено','Завершён');
    end if;
  end if;

  return new;
end;
$$;


--
-- Name: trg_referral_bonus(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_referral_bonus() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_ref_code   text;
  v_owner      uuid;
  v_client_ref text;
  v_prev_count bigint;
  v_tier       smallint;
  v_pct        numeric(4,2);
  v_bonus      integer;
BEGIN
  -- Срабатывает только при переходе → 'Оплачено' и если ещё не обрабатывали
  IF NEW.status != 'Оплачено'
     OR OLD.status = 'Оплачено'
     OR OLD.referral_credited_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Реф-код клиента и его собственный код
  SELECT referred_by, ref_code INTO v_ref_code, v_client_ref
    FROM clients WHERE id = NEW.client_id LIMIT 1;
  IF v_ref_code IS NULL OR v_ref_code = '' THEN
    RETURN NEW;
  END IF;

  -- Рефер
  SELECT id INTO v_owner
    FROM clients WHERE ref_code = v_ref_code AND id <> NEW.client_id LIMIT 1;
  IF v_owner IS NULL THEN
    RETURN NEW;
  END IF;

  -- 🔒 Антикруговая проверка в триггере
  IF EXISTS (
    SELECT 1 FROM clients
    WHERE id = v_owner AND referred_by = v_client_ref
  ) THEN
    RETURN NEW; -- круговая ссылка — не начисляем
  END IF;

  -- Тир: сколько уже начислено этому рефереру
  SELECT count(*) INTO v_prev_count
    FROM referral_events WHERE referrer_id = v_owner;

  v_tier := LEAST(v_prev_count + 1, 4)::smallint;
  v_pct  := CASE v_tier
    WHEN 1 THEN 2.00
    WHEN 2 THEN 2.50
    WHEN 3 THEN 3.00
    ELSE        3.50
  END;
  v_bonus := round(coalesce(NEW.total, 0) * v_pct / 100.0);

  -- Вставка в referral_events (UNIQUE guard — жёсткий барьер против двойного начисления)
  BEGIN
    INSERT INTO referral_events
      (referrer_id, referred_id, booking_id, booking_total, tier, pct, bonus_credited)
    VALUES
      (v_owner, NEW.client_id, NEW.id, coalesce(NEW.total, 0), v_tier, v_pct, v_bonus);
  EXCEPTION WHEN unique_violation THEN
    RETURN NEW; -- уже было начислено (race) — ничего не делаем
  END;

  -- Зачислить бонус
  UPDATE clients
    SET bonus_balance = coalesce(bonus_balance, 0) + v_bonus
    WHERE id = v_owner;

  NEW.referral_credited_at := now();
  RETURN NEW;
END;
$$;


--
-- Name: update_client_stage(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_client_stage(p_tg_chat_id text, p_stage text, p_secret text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF p_stage IS NULL THEN RETURN jsonb_build_object('ok',false,'reason','null_stage'); END IF;
  IF p_stage NOT IN ('new','interest','thinking','booking','done','cold') THEN
    RETURN jsonb_build_object('ok',false,'reason','invalid_stage','stage',p_stage);
  END IF;
  UPDATE clients SET stage = p_stage, last_contact = NOW() WHERE tg_chat_id = p_tg_chat_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'reason','client_not_found'); END IF;
  RETURN jsonb_build_object('ok',true,'stage',p_stage);
END; $$;


--
-- Name: upsert_client_memory(uuid, text[], text, text, text, text, text, integer, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_client_memory(p_client_id uuid, p_interests text[] DEFAULT NULL::text[], p_budget_level text DEFAULT NULL::text, p_travel_style text DEFAULT NULL::text, p_last_intent text DEFAULT NULL::text, p_last_tour_viewed text DEFAULT NULL::text, p_arrival_date text DEFAULT NULL::text, p_group_size integer DEFAULT NULL::integer, p_has_children boolean DEFAULT NULL::boolean, p_secret text DEFAULT ''::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  INSERT INTO client_memory (
    client_id, interests, budget_level, travel_style, last_intent,
    last_tour_viewed, tours_viewed, arrival_date, group_size, has_children, updated_at
  ) VALUES (
    p_client_id,
    COALESCE(p_interests, '{}'),
    COALESCE(p_budget_level, 'medium'),
    p_travel_style,
    p_last_intent,
    p_last_tour_viewed,
    CASE WHEN p_last_tour_viewed IS NOT NULL THEN ARRAY[p_last_tour_viewed] ELSE '{}' END,
    p_arrival_date,
    p_group_size,
    COALESCE(p_has_children, false),
    now()
  )
  ON CONFLICT (client_id) DO UPDATE SET
    interests = CASE
      WHEN p_interests IS NOT NULL
      THEN (SELECT ARRAY(SELECT DISTINCT unnest(client_memory.interests || p_interests)))
      ELSE client_memory.interests
    END,
    budget_level     = COALESCE(p_budget_level,     client_memory.budget_level),
    travel_style     = COALESCE(p_travel_style,     client_memory.travel_style),
    last_intent      = COALESCE(p_last_intent,      client_memory.last_intent),
    last_tour_viewed = COALESCE(p_last_tour_viewed, client_memory.last_tour_viewed),
    tours_viewed = CASE
      WHEN p_last_tour_viewed IS NOT NULL
      THEN (SELECT ARRAY(SELECT DISTINCT unnest(client_memory.tours_viewed || ARRAY[p_last_tour_viewed])))
      ELSE client_memory.tours_viewed
    END,
    arrival_date = COALESCE(p_arrival_date, client_memory.arrival_date),
    group_size   = COALESCE(p_group_size,   client_memory.group_size),
    has_children = CASE WHEN p_has_children IS NOT NULL THEN p_has_children ELSE client_memory.has_children END,
    updated_at   = now();
END;
$$;


--
-- Name: use_bonus(text, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.use_bonus(p_tg_chat_id text, p_booking_id uuid, p_amount integer, p_secret text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_client_id  uuid;
  v_balance    integer;
  v_bk_total   integer;
  v_bk_client  uuid;
  v_bk_applied integer;
  v_max_bonus  integer;
  v_ok         boolean := false;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''), 'sha256'), 'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT id, coalesce(bonus_balance, 0)
    INTO v_client_id, v_balance
    FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1;
  IF v_client_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'client_not_found');
  END IF;

  SELECT total, client_id, bonus_applied
    INTO v_bk_total, v_bk_client, v_bk_applied
    FROM bookings WHERE id = p_booking_id;
  IF v_bk_client IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'booking_not_found');
  END IF;

  -- 🔒 Бронь принадлежит этому клиенту
  IF v_bk_client != v_client_id THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'booking_not_yours');
  END IF;

  -- 🔒 Бонус ещё не применялся
  IF v_bk_applied > 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'bonus_already_applied', 'applied', v_bk_applied);
  END IF;

  -- 🔒 Лимит 3.5% от суммы брони
  v_max_bonus := round(coalesce(v_bk_total, 0) * 0.035);
  IF p_amount > v_max_bonus THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'exceeds_cap_3pct5', 'max_allowed', v_max_bonus);
  END IF;

  -- 🔒 Не больше баланса
  IF p_amount > v_balance THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'insufficient_balance', 'balance', v_balance);
  END IF;

  -- Атомарное списание: WHERE + проверка FOUND (защита от гонки)
  UPDATE clients
    SET bonus_balance = bonus_balance - p_amount
    WHERE id = v_client_id AND bonus_balance >= p_amount;
  GET DIAGNOSTICS v_ok = ROW_COUNT;
  IF NOT v_ok THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'race_retry');
  END IF;

  UPDATE bookings SET bonus_applied = p_amount WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'ok',           true,
    'bonus_applied', p_amount,
    'new_balance',   v_balance - p_amount
  );
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid,
    booking_id uuid,
    action text NOT NULL,
    details jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_id text,
    client_id uuid,
    tour_id uuid,
    tour_name text,
    date_start date,
    people_count integer,
    adults integer,
    children integer,
    budget integer,
    total integer,
    comment text,
    source text,
    status text DEFAULT 'Новый'::text,
    created_at timestamp with time zone DEFAULT now(),
    reminded_at timestamp with time zone,
    notified_status text,
    nudged_at timestamp with time zone,
    infants integer,
    referral_credited_at timestamp with time zone,
    bonus_applied integer DEFAULT 0 NOT NULL,
    CONSTRAINT bookings_bonus_applied_check CHECK ((bonus_applied >= 0))
);


--
-- Name: client_memory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_memory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    interests text[] DEFAULT '{}'::text[],
    budget_level text DEFAULT 'medium'::text,
    travel_style text,
    last_intent text,
    last_tour_viewed text,
    tours_viewed text[] DEFAULT '{}'::text[],
    tours_booked text[] DEFAULT '{}'::text[],
    updated_at timestamp with time zone DEFAULT now(),
    arrival_date text,
    group_size integer,
    has_children boolean DEFAULT false,
    CONSTRAINT client_memory_budget_level_check CHECK ((budget_level = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'vip'::text])))
);


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text,
    phone text,
    email text,
    telegram text,
    tg_chat_id text,
    whatsapp text,
    instagram text,
    vk text,
    source text,
    status text DEFAULT 'Новый'::text,
    notes text,
    first_contact timestamp with time zone DEFAULT now(),
    last_contact timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    country text,
    language text DEFAULT 'ru'::text,
    stage text DEFAULT 'new'::text,
    market text,
    currency text DEFAULT 'RUB'::text,
    discount_pct numeric(4,2) DEFAULT 0,
    ref_code text DEFAULT upper(substr(md5((gen_random_uuid())::text), 1, 8)),
    referred_by text,
    bonus_balance numeric(12,2) DEFAULT 0,
    birthday date,
    allow_email boolean DEFAULT true,
    allow_sms boolean DEFAULT true,
    allow_messenger boolean DEFAULT true,
    tags text[],
    consent_given boolean DEFAULT false,
    consent_at timestamp with time zone,
    CONSTRAINT clients_stage_check CHECK ((stage = ANY (ARRAY['new'::text, 'interest'::text, 'thinking'::text, 'booking'::text, 'done'::text, 'cold'::text])))
);


--
-- Name: COLUMN clients.market; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.clients.market IS 'Выбранный рынок клиента (markets.id: phuket|pattaya|...). Единая точка входа со всех туннелей: сайт, приложение, ВК, бот.';


--
-- Name: COLUMN clients.currency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.clients.currency IS 'Валюта счёта клиента: RUB | KZT. Базовые цены туров — в THB (батах), конвертируются при выставлении счёта.';


--
-- Name: COLUMN clients.discount_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.clients.discount_pct IS 'Скидка клиента в %: 1.5 обычная (по запросу), 3.5 максимальная (секретная фраза). Применяется сервером, потолок 3.5.';


--
-- Name: COLUMN clients.ref_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.clients.ref_code IS 'Персональный реф-код клиента для СБП (ссылка ?start=ref_<code>)';


--
-- Name: COLUMN clients.referred_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.clients.referred_by IS 'ref_code пригласившего (кто получает 1.5% с покупок)';


--
-- Name: COLUMN clients.bonus_balance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.clients.bonus_balance IS 'Бонусный баланс в БАТАХ (СБП), тратится на экскурсии';


--
-- Name: COLUMN clients.consent_given; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.clients.consent_given IS 'Клиент согласился на сбор/обработку данных (кнопка ДАЛЕЕ в боте или форма сайта/приложения)';


--
-- Name: content_plan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_plan (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    city text DEFAULT 'Пхукет'::text,
    week integer,
    date date,
    type text,
    title text NOT NULL,
    body text,
    status text DEFAULT 'draft'::text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT content_plan_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'ready'::text, 'published'::text])))
);


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    message text NOT NULL,
    response text,
    intent text,
    source text DEFAULT 'telegram'::text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT conversations_source_check CHECK ((source = ANY (ARRAY['telegram'::text, 'site'::text, 'app'::text])))
);


--
-- Name: gift_certificates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gift_certificates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    package_slug text,
    amount_thb numeric(12,2),
    buyer_client_id uuid,
    recipient_name text,
    gift_message text,
    status text DEFAULT 'issued'::text NOT NULL,
    redeemed_by_client_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    redeemed_at timestamp with time zone,
    booking_id uuid,
    CONSTRAINT gift_certificates_status_check CHECK ((status = ANY (ARRAY['issued'::text, 'paid'::text, 'redeemed'::text, 'expired'::text])))
);


--
-- Name: knowledge; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.knowledge (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category text NOT NULL,
    city text DEFAULT 'Пхукет'::text NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    area text,
    price_info text,
    tags text[] DEFAULT '{}'::text[],
    best_time text,
    insider_tip text,
    related_tour_slug text,
    source text DEFAULT 'manual'::text,
    active boolean DEFAULT true,
    priority integer DEFAULT 50,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT knowledge_category_check CHECK ((category = ANY (ARRAY['place'::text, 'beach'::text, 'food'::text, 'shopping'::text, 'lifehack'::text, 'transport'::text, 'price'::text, 'safety'::text, 'event'::text, 'faq'::text]))),
    CONSTRAINT knowledge_city_check CHECK ((city = ANY (ARRAY['Пхукет'::text, 'Паттайя'::text, 'Вьетнам'::text, 'Бали'::text, 'Дубай'::text, 'Общее'::text])))
);


--
-- Name: markets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.markets (
    id text NOT NULL,
    name text NOT NULL,
    name_en text,
    country text NOT NULL,
    country_code text DEFAULT 'TH'::text NOT NULL,
    accent_color text DEFAULT '#B8FF3C'::text NOT NULL,
    timezone text DEFAULT 'Asia/Bangkok'::text NOT NULL,
    currency text DEFAULT 'THB'::text NOT NULL,
    active boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 99 NOT NULL,
    tagline text,
    description text,
    season_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: packages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.packages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    description text,
    market_id text,
    city text,
    kind text DEFAULT 'constructor'::text NOT NULL,
    price_adult integer,
    price_child integer,
    tour_slugs text[],
    is_giftable boolean DEFAULT true,
    image_url text,
    active boolean DEFAULT true,
    sort_order integer DEFAULT 100,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT packages_kind_check CHECK ((kind = ANY (ARRAY['constructor'::text, 'fixed'::text])))
);


--
-- Name: partner_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.partner_stats AS
SELECT
    NULL::uuid AS id,
    NULL::text AS name,
    NULL::text AS promo,
    NULL::smallint AS level,
    NULL::numeric(4,2) AS commission,
    NULL::numeric(10,2) AS balance_thb,
    NULL::integer AS total_sales,
    NULL::text AS telegram,
    NULL::text AS phone,
    NULL::boolean AS active,
    NULL::bigint AS referral_count,
    NULL::numeric AS total_earned,
    NULL::numeric AS total_paid_out;


--
-- Name: partners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.partners (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    type text,
    contact text,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    promo text,
    level smallint DEFAULT 1 NOT NULL,
    commission numeric(4,2) DEFAULT 1.5 NOT NULL,
    balance_thb numeric(10,2) DEFAULT 0 NOT NULL,
    telegram text,
    phone text,
    total_sales integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT partners_level_check CHECK (((level >= 1) AND (level <= 3)))
);


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid,
    provider text DEFAULT 'yookassa'::text,
    payment_id text,
    amount integer,
    currency text DEFAULT 'RUB'::text,
    status text DEFAULT 'pending'::text,
    confirmation_url text,
    created_at timestamp with time zone DEFAULT now(),
    paid_at timestamp with time zone
);


--
-- Name: referral_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referral_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    referrer_id uuid NOT NULL,
    referred_id uuid NOT NULL,
    booking_id uuid NOT NULL,
    booking_total integer NOT NULL,
    tier smallint NOT NULL,
    pct numeric(4,2) NOT NULL,
    bonus_credited integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT referral_events_bonus_credited_check CHECK ((bonus_credited >= 0)),
    CONSTRAINT referral_events_pct_check CHECK (((pct >= (0)::numeric) AND (pct <= 3.50))),
    CONSTRAINT referral_events_tier_check CHECK (((tier >= 1) AND (tier <= 4)))
);


--
-- Name: referrals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referrals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    client_id uuid,
    booking_id uuid,
    booking_total numeric(10,2) DEFAULT 0 NOT NULL,
    commission_pct numeric(4,2) NOT NULL,
    earned_thb numeric(10,2) DEFAULT 0 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    paid_at timestamp with time zone,
    CONSTRAINT referrals_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'cancelled'::text])))
);


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid,
    tour_id uuid,
    booking_id uuid,
    rating integer,
    text text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: tours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tours (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    city text,
    category text,
    price_adult integer,
    price_child integer,
    duration text,
    description text,
    active boolean DEFAULT true,
    supplier text,
    created_at timestamp with time zone DEFAULT now(),
    image_url text,
    tags text[] DEFAULT '{}'::text[],
    included text[] DEFAULT '{}'::text[],
    not_included text[] DEFAULT '{}'::text[],
    what_to_bring text[] DEFAULT '{}'::text[],
    program text,
    sort_order integer DEFAULT 99,
    min_people integer DEFAULT 1,
    max_people integer DEFAULT 20,
    season_note text,
    market_id text,
    show_on_site boolean DEFAULT false NOT NULL
);


--
-- Name: v_clients; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_clients WITH (security_invoker='true') AS
 SELECT id,
    name,
    phone,
    email,
    birthday,
    telegram,
    tg_chat_id,
    whatsapp,
    instagram,
    vk,
    country,
    language,
    market,
    currency,
    source,
    status,
    stage,
    discount_pct,
    bonus_balance,
    ref_code,
    referred_by,
    tags,
    notes,
    allow_email,
    allow_sms,
    allow_messenger,
    first_contact,
    last_contact,
    created_at,
    ( SELECT count(*) AS count
           FROM public.bookings b
          WHERE ((b.client_id = c.id) AND (b.status = 'Оплачено'::text))) AS trips,
    ( SELECT COALESCE(sum(b.total), (0)::bigint) AS "coalesce"
           FROM public.bookings b
          WHERE ((b.client_id = c.id) AND (b.status = 'Оплачено'::text))) AS spent_thb,
    ( SELECT max(b.created_at) AS max
           FROM public.bookings b
          WHERE ((b.client_id = c.id) AND (b.status = 'Оплачено'::text))) AS last_trip_at,
    ( SELECT string_agg(DISTINCT b.tour_name, ', '::text) AS string_agg
           FROM public.bookings b
          WHERE ((b.client_id = c.id) AND (b.status = 'Оплачено'::text))) AS tours_taken,
    ( SELECT count(*) AS count
           FROM public.reviews r
          WHERE (r.client_id = c.id)) AS reviews_count,
    ( SELECT round(avg(r.rating), 1) AS round
           FROM public.reviews r
          WHERE (r.client_id = c.id)) AS avg_rating,
    ( SELECT count(*) AS count
           FROM public.clients cc
          WHERE (cc.referred_by = c.ref_code)) AS invited
   FROM public.clients c;


--
-- Name: v_gifts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_gifts WITH (security_invoker='true') AS
 SELECT g.code,
    g.package_slug,
    p.title AS package_title,
    g.amount_thb,
    g.status,
    g.recipient_name AS recipient_intended,
    bc.name AS buyer_name,
    bc.tg_chat_id AS buyer_tg,
    rc.name AS recipient_name,
    rc.tg_chat_id AS recipient_tg,
    g.gift_message,
    g.created_at,
    g.redeemed_at,
    ( SELECT count(*) AS count
           FROM public.bookings b
          WHERE ((b.client_id = g.redeemed_by_client_id) AND (b.status = 'Оплачено'::text))) AS recipient_paid_trips,
    ( SELECT round(avg(r.rating), 1) AS round
           FROM public.reviews r
          WHERE (r.client_id = g.redeemed_by_client_id)) AS recipient_avg_rating,
    ( SELECT string_agg(b.tour_name, ', '::text) AS string_agg
           FROM public.bookings b
          WHERE ((b.client_id = g.redeemed_by_client_id) AND (b.status = 'Оплачено'::text))) AS recipient_trips
   FROM (((public.gift_certificates g
     LEFT JOIN public.clients bc ON ((bc.id = g.buyer_client_id)))
     LEFT JOIN public.clients rc ON ((rc.id = g.redeemed_by_client_id)))
     LEFT JOIN public.packages p ON ((p.slug = g.package_slug)))
  ORDER BY g.created_at DESC;


--
-- Name: action_history action_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_history
    ADD CONSTRAINT action_history_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_external_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_external_id_key UNIQUE (external_id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: client_memory client_memory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_memory
    ADD CONSTRAINT client_memory_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: content_plan content_plan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_plan
    ADD CONSTRAINT content_plan_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: gift_certificates gift_certificates_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_certificates
    ADD CONSTRAINT gift_certificates_code_key UNIQUE (code);


--
-- Name: gift_certificates gift_certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_certificates
    ADD CONSTRAINT gift_certificates_pkey PRIMARY KEY (id);


--
-- Name: knowledge knowledge_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge
    ADD CONSTRAINT knowledge_pkey PRIMARY KEY (id);


--
-- Name: markets markets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT markets_pkey PRIMARY KEY (id);


--
-- Name: packages packages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.packages
    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);


--
-- Name: packages packages_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.packages
    ADD CONSTRAINT packages_slug_key UNIQUE (slug);


--
-- Name: partners partners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_pkey PRIMARY KEY (id);


--
-- Name: partners partners_promo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_promo_key UNIQUE (promo);


--
-- Name: payments payments_payment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_payment_id_key UNIQUE (payment_id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: referral_events referral_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_events
    ADD CONSTRAINT referral_events_pkey PRIMARY KEY (id);


--
-- Name: referrals referrals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: tours tours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT tours_pkey PRIMARY KEY (id);


--
-- Name: tours tours_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT tours_slug_key UNIQUE (slug);


--
-- Name: action_history_client_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX action_history_client_idx ON public.action_history USING btree (client_id);


--
-- Name: bookings_client_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bookings_client_idx ON public.bookings USING btree (client_id);


--
-- Name: bookings_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bookings_status_idx ON public.bookings USING btree (status);


--
-- Name: client_memory_client_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX client_memory_client_id_key ON public.client_memory USING btree (client_id);


--
-- Name: clients_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX clients_email_idx ON public.clients USING btree (lower(email));


--
-- Name: clients_email_uq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX clients_email_uq ON public.clients USING btree (lower(email)) WHERE (email IS NOT NULL);


--
-- Name: clients_phone_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX clients_phone_key ON public.clients USING btree (phone) WHERE (phone IS NOT NULL);


--
-- Name: clients_tg_chat_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX clients_tg_chat_id_key ON public.clients USING btree (tg_chat_id) WHERE (tg_chat_id IS NOT NULL);


--
-- Name: conv_client_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conv_client_idx ON public.conversations USING btree (client_id);


--
-- Name: conv_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conv_created_idx ON public.conversations USING btree (created_at DESC);


--
-- Name: idx_action_history_booking_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_action_history_booking_id ON public.action_history USING btree (booking_id);


--
-- Name: idx_action_history_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_action_history_created_at ON public.action_history USING btree (created_at DESC);


--
-- Name: idx_bookings_date_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_date_start ON public.bookings USING btree (date_start);


--
-- Name: idx_bookings_reminded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_reminded_at ON public.bookings USING btree (reminded_at);


--
-- Name: idx_bookings_tour_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_tour_id ON public.bookings USING btree (tour_id);


--
-- Name: idx_clients_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clients_created_at ON public.clients USING btree (created_at);


--
-- Name: idx_clients_market; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clients_market ON public.clients USING btree (market);


--
-- Name: idx_clients_ref_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_clients_ref_code ON public.clients USING btree (ref_code) WHERE (ref_code IS NOT NULL);


--
-- Name: idx_clients_referred_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clients_referred_by ON public.clients USING btree (referred_by);


--
-- Name: idx_clients_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clients_source ON public.clients USING btree (source);


--
-- Name: idx_clients_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clients_stage ON public.clients USING btree (stage);


--
-- Name: idx_gift_certificates_booking_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gift_certificates_booking_id ON public.gift_certificates USING btree (booking_id);


--
-- Name: idx_gift_certificates_buyer_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gift_certificates_buyer_client_id ON public.gift_certificates USING btree (buyer_client_id);


--
-- Name: idx_gift_certificates_redeemed_by_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gift_certificates_redeemed_by_client_id ON public.gift_certificates USING btree (redeemed_by_client_id);


--
-- Name: idx_knowledge_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_knowledge_category ON public.knowledge USING btree (category) WHERE active;


--
-- Name: idx_knowledge_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_knowledge_city ON public.knowledge USING btree (city) WHERE active;


--
-- Name: idx_knowledge_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_knowledge_search ON public.knowledge USING gin (to_tsvector('russian'::regconfig, ((title || ' '::text) || content)));


--
-- Name: idx_knowledge_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_knowledge_tags ON public.knowledge USING gin (tags);


--
-- Name: idx_reviews_booking_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_booking_id ON public.reviews USING btree (booking_id);


--
-- Name: idx_reviews_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_client_id ON public.reviews USING btree (client_id);


--
-- Name: idx_reviews_tour_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_tour_id ON public.reviews USING btree (tour_id);


--
-- Name: idx_tours_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tours_active ON public.tours USING btree (active);


--
-- Name: idx_tours_active_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tours_active_sort ON public.tours USING btree (active, sort_order);


--
-- Name: idx_tours_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tours_category ON public.tours USING btree (category);


--
-- Name: idx_tours_market_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tours_market_active ON public.tours USING btree (market_id, active, sort_order);


--
-- Name: idx_tours_market_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tours_market_id ON public.tours USING btree (market_id);


--
-- Name: ix_referral_events_referred_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_referral_events_referred_id ON public.referral_events USING btree (referred_id);


--
-- Name: ix_referrals_booking_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_referrals_booking_id ON public.referrals USING btree (booking_id);


--
-- Name: ix_referrals_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_referrals_client_id ON public.referrals USING btree (client_id);


--
-- Name: ix_referrals_partner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_referrals_partner_id ON public.referrals USING btree (partner_id);


--
-- Name: payments_booking_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_booking_idx ON public.payments USING btree (booking_id);


--
-- Name: referral_events_booking_uq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX referral_events_booking_uq ON public.referral_events USING btree (booking_id);


--
-- Name: referral_events_referrer_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX referral_events_referrer_idx ON public.referral_events USING btree (referrer_id);


--
-- Name: partner_stats _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.partner_stats WITH (security_invoker='on') AS
 SELECT p.id,
    p.name,
    p.promo,
    p.level,
    p.commission,
    p.balance_thb,
    p.total_sales,
    p.telegram,
    p.phone,
    p.active,
    count(r.id) AS referral_count,
    COALESCE(sum(r.earned_thb), (0)::numeric) AS total_earned,
    COALESCE(sum(
        CASE
            WHEN (r.status = 'paid'::text) THEN r.earned_thb
            ELSE NULL::numeric
        END), (0)::numeric) AS total_paid_out
   FROM (public.partners p
     LEFT JOIN public.referrals r ON ((r.partner_id = p.id)))
  GROUP BY p.id;


--
-- Name: bookings booking_status_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER booking_status_history AFTER UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.trg_booking_status_history();


--
-- Name: bookings client_stage_from_booking; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_stage_from_booking AFTER INSERT OR UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.trg_client_stage_from_booking();


--
-- Name: payments payment_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payment_history AFTER INSERT OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.trg_payment_history();


--
-- Name: bookings referral_bonus; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER referral_bonus BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.trg_referral_bonus();


--
-- Name: bookings trg_bookings_referral; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_bookings_referral AFTER UPDATE OF status ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.bookings_credit_referral_trigger();


--
-- Name: partners trg_partners_commission; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_partners_commission BEFORE INSERT OR UPDATE OF level ON public.partners FOR EACH ROW EXECUTE FUNCTION public.partners_set_commission();


--
-- Name: action_history action_history_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_history
    ADD CONSTRAINT action_history_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE SET NULL;


--
-- Name: action_history action_history_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_history
    ADD CONSTRAINT action_history_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: bookings bookings_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: bookings bookings_tour_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_tour_id_fkey FOREIGN KEY (tour_id) REFERENCES public.tours(id) ON DELETE SET NULL;


--
-- Name: client_memory client_memory_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_memory
    ADD CONSTRAINT client_memory_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: gift_certificates gift_certificates_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_certificates
    ADD CONSTRAINT gift_certificates_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id);


--
-- Name: gift_certificates gift_certificates_buyer_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_certificates
    ADD CONSTRAINT gift_certificates_buyer_client_id_fkey FOREIGN KEY (buyer_client_id) REFERENCES public.clients(id);


--
-- Name: gift_certificates gift_certificates_redeemed_by_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_certificates
    ADD CONSTRAINT gift_certificates_redeemed_by_client_id_fkey FOREIGN KEY (redeemed_by_client_id) REFERENCES public.clients(id);


--
-- Name: payments payments_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: referral_events referral_events_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_events
    ADD CONSTRAINT referral_events_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id);


--
-- Name: referral_events referral_events_referred_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_events
    ADD CONSTRAINT referral_events_referred_id_fkey FOREIGN KEY (referred_id) REFERENCES public.clients(id);


--
-- Name: referral_events referral_events_referrer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_events
    ADD CONSTRAINT referral_events_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES public.clients(id);


--
-- Name: referrals referrals_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE SET NULL;


--
-- Name: referrals referrals_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: referrals referrals_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE SET NULL;


--
-- Name: reviews reviews_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: reviews reviews_tour_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_tour_id_fkey FOREIGN KEY (tour_id) REFERENCES public.tours(id) ON DELETE SET NULL;


--
-- Name: tours tours_market_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT tours_market_id_fkey FOREIGN KEY (market_id) REFERENCES public.markets(id);


--
-- Name: action_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.action_history ENABLE ROW LEVEL SECURITY;

--
-- Name: bookings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

--
-- Name: bookings bookings_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_admin_insert ON public.bookings FOR INSERT TO authenticated WITH CHECK (public.is_admin());


--
-- Name: bookings bookings_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_admin_select ON public.bookings FOR SELECT TO authenticated USING (public.is_admin());


--
-- Name: bookings bookings_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_admin_update ON public.bookings FOR UPDATE TO authenticated USING (public.is_admin());


--
-- Name: bookings bookings_anon_insert_new_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bookings_anon_insert_new_only ON public.bookings FOR INSERT TO anon WITH CHECK (((status = 'Новый'::text) AND (total IS NULL)));


--
-- Name: client_memory; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.client_memory ENABLE ROW LEVEL SECURITY;

--
-- Name: client_memory client_memory_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY client_memory_admin_select ON public.client_memory FOR SELECT TO authenticated USING (public.is_admin());


--
-- Name: bookings client_self_bookings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY client_self_bookings_read ON public.bookings FOR SELECT TO authenticated USING ((client_id IN ( SELECT clients.id
   FROM public.clients
  WHERE (clients.email = (auth.jwt() ->> 'email'::text)))));


--
-- Name: clients client_self_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY client_self_read ON public.clients FOR SELECT TO authenticated USING ((email = (auth.jwt() ->> 'email'::text)));


--
-- Name: clients client_self_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY client_self_update ON public.clients FOR UPDATE TO authenticated USING ((email = (auth.jwt() ->> 'email'::text))) WITH CHECK ((email = (auth.jwt() ->> 'email'::text)));


--
-- Name: clients; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

--
-- Name: clients clients_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clients_admin_insert ON public.clients FOR INSERT TO authenticated WITH CHECK (public.is_admin());


--
-- Name: clients clients_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clients_admin_select ON public.clients FOR SELECT TO authenticated USING (public.is_admin());


--
-- Name: clients clients_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clients_admin_update ON public.clients FOR UPDATE TO authenticated USING (public.is_admin());


--
-- Name: clients clients_anon_insert_new; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clients_anon_insert_new ON public.clients FOR INSERT TO anon WITH CHECK (((status = 'Новый'::text) AND (stage = 'new'::text)));


--
-- Name: content_plan content_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY content_admin_all ON public.content_plan TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: content_plan; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.content_plan ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations conversations_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY conversations_admin_select ON public.conversations FOR SELECT TO authenticated USING (public.is_admin());


--
-- Name: conversations conversations_anon_insert_site; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY conversations_anon_insert_site ON public.conversations FOR INSERT TO anon WITH CHECK ((source = ANY (ARRAY['telegram'::text, 'site'::text, 'app'::text])));


--
-- Name: gift_certificates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gift_certificates ENABLE ROW LEVEL SECURITY;

--
-- Name: gift_certificates gifts_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY gifts_admin_select ON public.gift_certificates FOR SELECT USING (public.is_admin());


--
-- Name: gift_certificates gifts_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY gifts_admin_update ON public.gift_certificates FOR UPDATE USING (public.is_admin());


--
-- Name: knowledge; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.knowledge ENABLE ROW LEVEL SECURITY;

--
-- Name: knowledge knowledge_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY knowledge_read_all ON public.knowledge FOR SELECT USING ((active = true));


--
-- Name: markets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.markets ENABLE ROW LEVEL SECURITY;

--
-- Name: packages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.packages ENABLE ROW LEVEL SECURITY;

--
-- Name: packages packages_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY packages_public_read ON public.packages FOR SELECT USING ((active = true));


--
-- Name: partners; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;

--
-- Name: payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

--
-- Name: payments payments_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payments_admin_select ON public.payments FOR SELECT TO authenticated USING (public.is_admin());


--
-- Name: markets public_read_markets; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_read_markets ON public.markets FOR SELECT TO anon USING (true);


--
-- Name: referral_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.referral_events ENABLE ROW LEVEL SECURITY;

--
-- Name: referrals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

--
-- Name: referrals referrals_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY referrals_admin ON public.referrals USING (((auth.jwt() ->> 'email'::text) = 'ibetekhtin@gmail.com'::text));


--
-- Name: reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

--
-- Name: reviews reviews_public_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reviews_public_insert ON public.reviews FOR INSERT WITH CHECK (((rating IS NOT NULL) AND ((rating >= 1) AND (rating <= 5)) AND (char_length(COALESCE(text, ''::text)) <= 2000)));


--
-- Name: reviews reviews_public_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reviews_public_select ON public.reviews FOR SELECT USING (true);


--
-- Name: tours; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tours ENABLE ROW LEVEL SECURITY;

--
-- Name: tours tours_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tours_public_read ON public.tours FOR SELECT USING ((active = true));


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION app_mark_paid(p_external_id text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.app_mark_paid(p_external_id text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.app_mark_paid(p_external_id text, p_secret text) TO service_role;


--
-- Name: FUNCTION app_set_booking_status(p_external_id text, p_status text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.app_set_booking_status(p_external_id text, p_status text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.app_set_booking_status(p_external_id text, p_status text, p_secret text) TO service_role;


--
-- Name: FUNCTION app_upsert_lead(p_external_id text, p_source text, p_name text, p_phone text, p_email text, p_telegram text, p_tg_chat_id text, p_whatsapp text, p_instagram text, p_vk text, p_tour_name text, p_tour_slug text, p_date_start date, p_people integer, p_budget integer, p_total integer, p_comment text, p_status text, p_adults integer, p_children integer, p_infants integer, p_ref_code text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.app_upsert_lead(p_external_id text, p_source text, p_name text, p_phone text, p_email text, p_telegram text, p_tg_chat_id text, p_whatsapp text, p_instagram text, p_vk text, p_tour_name text, p_tour_slug text, p_date_start date, p_people integer, p_budget integer, p_total integer, p_comment text, p_status text, p_adults integer, p_children integer, p_infants integer, p_ref_code text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.app_upsert_lead(p_external_id text, p_source text, p_name text, p_phone text, p_email text, p_telegram text, p_tg_chat_id text, p_whatsapp text, p_instagram text, p_vk text, p_tour_name text, p_tour_slug text, p_date_start date, p_people integer, p_budget integer, p_total integer, p_comment text, p_status text, p_adults integer, p_children integer, p_infants integer, p_ref_code text, p_secret text) TO service_role;


--
-- Name: FUNCTION apply_referral(p_tg_chat_id text, p_ref_code text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.apply_referral(p_tg_chat_id text, p_ref_code text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.apply_referral(p_tg_chat_id text, p_ref_code text, p_secret text) TO service_role;


--
-- Name: FUNCTION bookings_credit_referral_trigger(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.bookings_credit_referral_trigger() FROM PUBLIC;
GRANT ALL ON FUNCTION public.bookings_credit_referral_trigger() TO service_role;


--
-- Name: FUNCTION bot_abandoned_bookings(p_secret text, p_hours integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.bot_abandoned_bookings(p_secret text, p_hours integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.bot_abandoned_bookings(p_secret text, p_hours integer) TO service_role;


--
-- Name: FUNCTION bot_booking_status_changes(p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.bot_booking_status_changes(p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.bot_booking_status_changes(p_secret text) TO service_role;


--
-- Name: FUNCTION bot_upsert_client(p_tg_chat_id text, p_name text, p_source text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.bot_upsert_client(p_tg_chat_id text, p_name text, p_source text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.bot_upsert_client(p_tg_chat_id text, p_name text, p_source text, p_secret text) TO service_role;


--
-- Name: FUNCTION credit_referral(p_booking_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.credit_referral(p_booking_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.credit_referral(p_booking_id uuid) TO service_role;


--
-- Name: FUNCTION get_bookings_by_phone(p_phone text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_bookings_by_phone(p_phone text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_bookings_by_phone(p_phone text) TO service_role;


--
-- Name: FUNCTION get_funnel_stats(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_funnel_stats() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_funnel_stats() TO service_role;


--
-- Name: FUNCTION get_kote_context(p_tg_chat_id text, p_query text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_kote_context(p_tg_chat_id text, p_query text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_kote_context(p_tg_chat_id text, p_query text, p_secret text) TO service_role;


--
-- Name: FUNCTION get_new_leads(p_minutes integer, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_new_leads(p_minutes integer, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_new_leads(p_minutes integer, p_secret text) TO service_role;


--
-- Name: FUNCTION get_referral_stats(p_tg_chat_id text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_referral_stats(p_tg_chat_id text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_referral_stats(p_tg_chat_id text, p_secret text) TO service_role;


--
-- Name: FUNCTION get_review_requests(p_days_ago integer, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_review_requests(p_days_ago integer, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_review_requests(p_days_ago integer, p_secret text) TO service_role;


--
-- Name: FUNCTION get_tour_reminders(p_days_ahead integer, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_tour_reminders(p_days_ahead integer, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_tour_reminders(p_days_ahead integer, p_secret text) TO service_role;


--
-- Name: FUNCTION is_admin(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.is_admin() TO anon;
GRANT ALL ON FUNCTION public.is_admin() TO authenticated;
GRANT ALL ON FUNCTION public.is_admin() TO service_role;


--
-- Name: FUNCTION partners_set_commission(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.partners_set_commission() FROM PUBLIC;
GRANT ALL ON FUNCTION public.partners_set_commission() TO service_role;


--
-- Name: FUNCTION pay_stuck_report(p_secret text, p_hours integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.pay_stuck_report(p_secret text, p_hours integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pay_stuck_report(p_secret text, p_hours integer) TO service_role;


--
-- Name: FUNCTION redeem_gift(p_code text, p_tg_chat_id text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.redeem_gift(p_code text, p_tg_chat_id text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.redeem_gift(p_code text, p_tg_chat_id text, p_secret text) TO service_role;


--
-- Name: FUNCTION search_knowledge(p_query text, p_category text, p_city text, p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.search_knowledge(p_query text, p_category text, p_city text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.search_knowledge(p_query text, p_category text, p_city text, p_limit integer) TO service_role;


--
-- Name: FUNCTION spend_bonus(p_tg_chat_id text, p_amount_thb numeric, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.spend_bonus(p_tg_chat_id text, p_amount_thb numeric, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.spend_bonus(p_tg_chat_id text, p_amount_thb numeric, p_secret text) TO service_role;


--
-- Name: FUNCTION trg_booking_status_history(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.trg_booking_status_history() FROM PUBLIC;
GRANT ALL ON FUNCTION public.trg_booking_status_history() TO service_role;


--
-- Name: FUNCTION trg_client_stage_from_booking(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.trg_client_stage_from_booking() FROM PUBLIC;
GRANT ALL ON FUNCTION public.trg_client_stage_from_booking() TO service_role;


--
-- Name: FUNCTION trg_payment_history(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.trg_payment_history() FROM PUBLIC;
GRANT ALL ON FUNCTION public.trg_payment_history() TO service_role;


--
-- Name: FUNCTION trg_referral_bonus(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.trg_referral_bonus() FROM PUBLIC;
GRANT ALL ON FUNCTION public.trg_referral_bonus() TO service_role;


--
-- Name: FUNCTION update_client_stage(p_tg_chat_id text, p_stage text, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.update_client_stage(p_tg_chat_id text, p_stage text, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.update_client_stage(p_tg_chat_id text, p_stage text, p_secret text) TO service_role;


--
-- Name: FUNCTION upsert_client_memory(p_client_id uuid, p_interests text[], p_budget_level text, p_travel_style text, p_last_intent text, p_last_tour_viewed text, p_arrival_date text, p_group_size integer, p_has_children boolean, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.upsert_client_memory(p_client_id uuid, p_interests text[], p_budget_level text, p_travel_style text, p_last_intent text, p_last_tour_viewed text, p_arrival_date text, p_group_size integer, p_has_children boolean, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.upsert_client_memory(p_client_id uuid, p_interests text[], p_budget_level text, p_travel_style text, p_last_intent text, p_last_tour_viewed text, p_arrival_date text, p_group_size integer, p_has_children boolean, p_secret text) TO service_role;


--
-- Name: FUNCTION use_bonus(p_tg_chat_id text, p_booking_id uuid, p_amount integer, p_secret text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.use_bonus(p_tg_chat_id text, p_booking_id uuid, p_amount integer, p_secret text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.use_bonus(p_tg_chat_id text, p_booking_id uuid, p_amount integer, p_secret text) TO service_role;


--
-- Name: TABLE action_history; Type: ACL; Schema: public; Owner: -
--

GRANT REFERENCES,TRIGGER,MAINTAIN ON TABLE public.action_history TO anon;
GRANT ALL ON TABLE public.action_history TO authenticated;
GRANT ALL ON TABLE public.action_history TO service_role;


--
-- Name: TABLE bookings; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.bookings TO anon;
GRANT ALL ON TABLE public.bookings TO authenticated;
GRANT ALL ON TABLE public.bookings TO service_role;


--
-- Name: TABLE client_memory; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.client_memory TO anon;
GRANT ALL ON TABLE public.client_memory TO authenticated;
GRANT ALL ON TABLE public.client_memory TO service_role;


--
-- Name: TABLE clients; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.clients TO anon;
GRANT ALL ON TABLE public.clients TO authenticated;
GRANT ALL ON TABLE public.clients TO service_role;


--
-- Name: TABLE content_plan; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.content_plan TO anon;
GRANT ALL ON TABLE public.content_plan TO authenticated;
GRANT ALL ON TABLE public.content_plan TO service_role;


--
-- Name: TABLE conversations; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.conversations TO anon;
GRANT ALL ON TABLE public.conversations TO authenticated;
GRANT ALL ON TABLE public.conversations TO service_role;


--
-- Name: TABLE gift_certificates; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.gift_certificates TO anon;
GRANT ALL ON TABLE public.gift_certificates TO authenticated;
GRANT ALL ON TABLE public.gift_certificates TO service_role;


--
-- Name: TABLE knowledge; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.knowledge TO anon;
GRANT ALL ON TABLE public.knowledge TO authenticated;
GRANT ALL ON TABLE public.knowledge TO service_role;


--
-- Name: TABLE markets; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.markets TO anon;
GRANT ALL ON TABLE public.markets TO authenticated;
GRANT ALL ON TABLE public.markets TO service_role;


--
-- Name: TABLE packages; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.packages TO anon;
GRANT ALL ON TABLE public.packages TO authenticated;
GRANT ALL ON TABLE public.packages TO service_role;


--
-- Name: TABLE partner_stats; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE public.partner_stats TO anon;
GRANT ALL ON TABLE public.partner_stats TO authenticated;
GRANT ALL ON TABLE public.partner_stats TO service_role;


--
-- Name: TABLE partners; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.partners TO anon;
GRANT ALL ON TABLE public.partners TO authenticated;
GRANT ALL ON TABLE public.partners TO service_role;


--
-- Name: TABLE payments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.payments TO authenticated;
GRANT ALL ON TABLE public.payments TO service_role;


--
-- Name: TABLE referral_events; Type: ACL; Schema: public; Owner: -
--

GRANT REFERENCES,TRIGGER,MAINTAIN ON TABLE public.referral_events TO anon;
GRANT ALL ON TABLE public.referral_events TO authenticated;
GRANT ALL ON TABLE public.referral_events TO service_role;


--
-- Name: TABLE referrals; Type: ACL; Schema: public; Owner: -
--

GRANT INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.referrals TO anon;
GRANT ALL ON TABLE public.referrals TO authenticated;
GRANT ALL ON TABLE public.referrals TO service_role;


--
-- Name: TABLE reviews; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.reviews TO anon;
GRANT ALL ON TABLE public.reviews TO authenticated;
GRANT ALL ON TABLE public.reviews TO service_role;


--
-- Name: TABLE tours; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,REFERENCES,TRIGGER,MAINTAIN ON TABLE public.tours TO anon;
GRANT ALL ON TABLE public.tours TO authenticated;
GRANT ALL ON TABLE public.tours TO service_role;


--
-- Name: TABLE v_clients; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_clients TO authenticated;
GRANT ALL ON TABLE public.v_clients TO service_role;


--
-- Name: TABLE v_gifts; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_gifts TO authenticated;
GRANT ALL ON TABLE public.v_gifts TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict rApyPbbkodbm9xWOnsXWnscBxZIpbZLhQLsspiIUCx54ZQNQJdHJ6cGDUaxe1GI

