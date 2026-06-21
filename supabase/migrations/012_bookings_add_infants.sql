-- 012 — Младенцы (дети до 4 лет — бесплатно: младенцы/малыши/груднички) как ЯВНАЯ колонка.
-- Применено в боевой базе 2026-06-22 через Supabase MCP.
-- Добавляет bookings.infants + p_infants в app_upsert_lead (trailing DEFAULT NULL →
-- старые вызовы целы). Сайт/приложение/бот передают p_infants. Тест на откате пройден.

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS infants integer;

DROP FUNCTION IF EXISTS public.app_upsert_lead(text,text,text,text,text,text,text,text,text,text,text,text,date,integer,integer,integer,text,text,integer,integer);

CREATE OR REPLACE FUNCTION public.app_upsert_lead(
  p_external_id text, p_source text DEFAULT 'Сайт'::text, p_name text DEFAULT NULL::text,
  p_phone text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_telegram text DEFAULT NULL::text,
  p_tg_chat_id text DEFAULT NULL::text, p_whatsapp text DEFAULT NULL::text, p_instagram text DEFAULT NULL::text,
  p_vk text DEFAULT NULL::text, p_tour_name text DEFAULT NULL::text, p_tour_slug text DEFAULT NULL::text,
  p_date_start date DEFAULT NULL::date, p_people integer DEFAULT NULL::integer, p_budget integer DEFAULT NULL::integer,
  p_total integer DEFAULT NULL::integer, p_comment text DEFAULT NULL::text, p_status text DEFAULT 'Новый'::text,
  p_adults integer DEFAULT NULL::integer, p_children integer DEFAULT NULL::integer, p_infants integer DEFAULT NULL::integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_client_id uuid; v_booking_id uuid; v_tour_id uuid;
  v_is_new_client boolean := false; v_is_new_booking boolean := false;
  v_email text := lower(nullif(trim(p_email), ''));
BEGIN
  IF p_phone IS NOT NULL THEN SELECT id INTO v_client_id FROM clients WHERE phone = p_phone LIMIT 1; END IF;
  IF v_client_id IS NULL AND p_tg_chat_id IS NOT NULL THEN SELECT id INTO v_client_id FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1; END IF;
  IF v_client_id IS NULL AND v_email IS NOT NULL THEN SELECT id INTO v_client_id FROM clients WHERE lower(email) = v_email LIMIT 1; END IF;

  IF v_client_id IS NULL THEN
    INSERT INTO clients (name, phone, email, telegram, tg_chat_id, whatsapp, instagram, vk, source, status, first_contact, last_contact)
    VALUES (COALESCE(p_name,'Без имени'), p_phone, v_email, p_telegram, p_tg_chat_id, p_whatsapp, p_instagram, p_vk, p_source, 'Новый', now(), now())
    RETURNING id INTO v_client_id;
    v_is_new_client := true;
  ELSE
    UPDATE clients SET name=COALESCE(p_name,name), phone=COALESCE(p_phone,phone), email=COALESCE(v_email,email),
      telegram=COALESCE(p_telegram,telegram), tg_chat_id=COALESCE(p_tg_chat_id,tg_chat_id), whatsapp=COALESCE(p_whatsapp,whatsapp),
      instagram=COALESCE(p_instagram,instagram), vk=COALESCE(p_vk,vk), last_contact=now()
    WHERE id=v_client_id;
  END IF;

  IF p_tour_slug IS NOT NULL THEN SELECT id INTO v_tour_id FROM tours WHERE slug=p_tour_slug LIMIT 1; END IF;
  IF p_external_id IS NOT NULL THEN SELECT id INTO v_booking_id FROM bookings WHERE external_id=p_external_id LIMIT 1; END IF;

  IF v_booking_id IS NULL THEN
    INSERT INTO bookings (external_id, client_id, tour_id, tour_name, date_start, people_count, adults, children, infants, budget, total, comment, source, status)
    VALUES (p_external_id, v_client_id, v_tour_id, p_tour_name, p_date_start, p_people, p_adults, p_children, p_infants, p_budget, p_total, p_comment, p_source, p_status)
    RETURNING id INTO v_booking_id;
    v_is_new_booking := true;
  ELSE
    UPDATE bookings SET client_id=COALESCE(v_client_id,client_id), tour_id=COALESCE(v_tour_id,tour_id),
      tour_name=COALESCE(p_tour_name,tour_name), date_start=COALESCE(p_date_start,date_start),
      people_count=COALESCE(p_people,people_count), adults=COALESCE(p_adults,adults), children=COALESCE(p_children,children),
      infants=COALESCE(p_infants,infants), budget=COALESCE(p_budget,budget), total=COALESCE(p_total,total), comment=COALESCE(p_comment,comment)
    WHERE id=v_booking_id;
  END IF;

  INSERT INTO action_history (client_id, booking_id, action, details)
  VALUES (v_client_id, v_booking_id, CASE WHEN v_is_new_booking THEN 'lead_created' ELSE 'lead_updated' END,
          jsonb_build_object('source',p_source,'external_id',p_external_id,'tour',p_tour_name,'status',p_status));

  RETURN jsonb_build_object('client_id',v_client_id,'booking_id',v_booking_id,'is_new_client',v_is_new_client,'is_new_booking',v_is_new_booking);
END; $function$;

GRANT EXECUTE ON FUNCTION public.app_upsert_lead(text,text,text,text,text,text,text,text,text,text,text,text,date,integer,integer,integer,text,text,integer,integer,integer) TO anon, authenticated, service_role;
