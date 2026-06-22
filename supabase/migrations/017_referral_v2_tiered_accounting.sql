-- 017 — Рефералка v2: тиры 2/2.5/3/3.5%, антикруговая защита, полный учёт, use_bonus.
-- Применено 2026-06-22 (Supabase MCP). Тест-драйв пройден: все 9 тестов ✅
--
-- Тиры: 1й друг=2%, 2й=2.5%, 3й=3%, 4й+=3.5%. Максимум везде: 3.5%.
-- Дыры закрыты:
--   ① Самореферал: apply_referral → id <> v_client → bad_code
--   ② Кругловая пара (A→B, B→A): антикруговой check в apply_referral + в триггере
--   ③ Двойное начисление: referral_events UNIQUE(booking_id) + OLD.referral_credited_at IS NOT NULL
--   ④ Тиры: count(*) FROM referral_events WHERE referrer_id = v_owner (не from trigger state)
--   ⑤ use_bonus: атомарное списание, cap 3.5% от суммы брони, idempotency (bonus_applied=0 guard)
--   ⑥ Чужая бронь: use_bonus проверяет booking.client_id = caller client_id
--   ⑦ Гонка при списании: WHERE bonus_balance >= p_amount + GET DIAGNOSTICS ROW_COUNT

-- ── 1. Таблица аудит-трейла реферальных начислений ───────────────────────
CREATE TABLE IF NOT EXISTS public.referral_events (
  id             uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id    uuid         NOT NULL REFERENCES public.clients(id),
  referred_id    uuid         NOT NULL REFERENCES public.clients(id),
  booking_id     uuid         NOT NULL REFERENCES public.bookings(id),
  booking_total  integer      NOT NULL,
  tier           smallint     NOT NULL CHECK (tier BETWEEN 1 AND 4),
  pct            numeric(4,2) NOT NULL CHECK (pct BETWEEN 0 AND 3.50),
  bonus_credited integer      NOT NULL CHECK (bonus_credited >= 0),
  created_at     timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS referral_events_booking_uq  ON public.referral_events(booking_id);
CREATE        INDEX IF NOT EXISTS referral_events_referrer_idx ON public.referral_events(referrer_id);
GRANT SELECT ON public.referral_events TO authenticated;

-- ── 2. bookings.bonus_applied — учёт потраченных бонусов ─────────────────
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS bonus_applied integer NOT NULL DEFAULT 0
    CHECK (bonus_applied >= 0);

-- ── 3. apply_referral v2: антикруговая защита ─────────────────────────────
CREATE OR REPLACE FUNCTION public.apply_referral(
  p_tg_chat_id text,
  p_ref_code   text,
  p_secret     text DEFAULT ''
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_client     uuid;
  v_client_ref text;
  v_owner      uuid;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''), 'sha256'), 'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT id, ref_code INTO v_client, v_client_ref
    FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1;
  IF v_client IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'client_not_found');
  END IF;

  SELECT id INTO v_owner
    FROM clients WHERE ref_code = upper(p_ref_code) AND id <> v_client LIMIT 1;
  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'bad_code');
  END IF;

  -- 🔒 Антикруговая: если рефер уже привязан по коду клиента — запрещаем
  IF EXISTS (
    SELECT 1 FROM clients
    WHERE id = v_owner
      AND referred_by IS NOT NULL AND referred_by != ''
      AND referred_by = v_client_ref
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'circular_referral');
  END IF;

  UPDATE clients SET referred_by = upper(p_ref_code)
    WHERE id = v_client AND (referred_by IS NULL OR referred_by = '');

  RETURN jsonb_build_object('ok', true, 'referrer', v_owner);
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.apply_referral(text, text, text) TO anon, authenticated, service_role;

-- ── 4. trg_referral_bonus v2: тиры 2/2.5/3/3.5% + referral_events ────────
CREATE OR REPLACE FUNCTION public.trg_referral_bonus()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_ref_code   text;
  v_owner      uuid;
  v_client_ref text;
  v_prev_count bigint;
  v_tier       smallint;
  v_pct        numeric(4,2);
  v_bonus      integer;
BEGIN
  IF NEW.status != 'Оплачено'
     OR OLD.status = 'Оплачено'
     OR OLD.referral_credited_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT referred_by, ref_code INTO v_ref_code, v_client_ref
    FROM clients WHERE id = NEW.client_id LIMIT 1;
  IF v_ref_code IS NULL OR v_ref_code = '' THEN RETURN NEW; END IF;

  SELECT id INTO v_owner
    FROM clients WHERE ref_code = v_ref_code AND id <> NEW.client_id LIMIT 1;
  IF v_owner IS NULL THEN RETURN NEW; END IF;

  -- 🔒 Антикруговая в триггере
  IF EXISTS (
    SELECT 1 FROM clients WHERE id = v_owner AND referred_by = v_client_ref
  ) THEN
    RETURN NEW;
  END IF;

  SELECT count(*) INTO v_prev_count FROM referral_events WHERE referrer_id = v_owner;

  v_tier := LEAST(v_prev_count + 1, 4)::smallint;
  v_pct  := CASE v_tier WHEN 1 THEN 2.00 WHEN 2 THEN 2.50 WHEN 3 THEN 3.00 ELSE 3.50 END;
  v_bonus := round(coalesce(NEW.total, 0) * v_pct / 100.0);

  BEGIN
    INSERT INTO referral_events
      (referrer_id, referred_id, booking_id, booking_total, tier, pct, bonus_credited)
    VALUES
      (v_owner, NEW.client_id, NEW.id, coalesce(NEW.total,0), v_tier, v_pct, v_bonus);
  EXCEPTION WHEN unique_violation THEN
    RETURN NEW;
  END;

  UPDATE clients SET bonus_balance = coalesce(bonus_balance, 0) + v_bonus WHERE id = v_owner;
  NEW.referral_credited_at := now();
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS referral_bonus ON public.bookings;
CREATE TRIGGER referral_bonus
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.trg_referral_bonus();

-- ── 5. use_bonus — атомарное списание бонусов (макс 3.5% брони) ──────────
CREATE OR REPLACE FUNCTION public.use_bonus(
  p_tg_chat_id text,
  p_booking_id uuid,
  p_amount     integer,
  p_secret     text DEFAULT ''
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
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
    INTO v_client_id, v_balance FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1;
  IF v_client_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'client_not_found');
  END IF;

  SELECT total, client_id, bonus_applied
    INTO v_bk_total, v_bk_client, v_bk_applied FROM bookings WHERE id = p_booking_id;
  IF v_bk_client IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'booking_not_found');
  END IF;
  IF v_bk_client != v_client_id THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'booking_not_yours');
  END IF;
  IF v_bk_applied > 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'bonus_already_applied', 'applied', v_bk_applied);
  END IF;

  v_max_bonus := round(coalesce(v_bk_total, 0) * 0.035);
  IF p_amount > v_max_bonus THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'exceeds_cap_3pct5', 'max_allowed', v_max_bonus);
  END IF;
  IF p_amount > v_balance THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'insufficient_balance', 'balance', v_balance);
  END IF;

  -- Атомарное списание с защитой от гонки
  UPDATE clients SET bonus_balance = bonus_balance - p_amount
    WHERE id = v_client_id AND bonus_balance >= p_amount;
  GET DIAGNOSTICS v_ok = ROW_COUNT;
  IF NOT v_ok THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'race_retry');
  END IF;

  UPDATE bookings SET bonus_applied = p_amount WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'ok', true, 'bonus_applied', p_amount, 'new_balance', v_balance - p_amount
  );
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.use_bonus(text, uuid, integer, text) TO anon, authenticated, service_role;

-- ── 6. get_referral_stats — для бота и HQ-дашборда ───────────────────────
CREATE OR REPLACE FUNCTION public.get_referral_stats(
  p_tg_chat_id text,
  p_secret     text DEFAULT ''
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_client_id  uuid;
  v_ref_code   text;
  v_balance    integer;
  v_stats      jsonb;
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
    'current_tier', LEAST(coalesce(ev.cnt, 0) + 1, 4),
    'next_tier_pct', CASE
      WHEN coalesce(ev.cnt, 0) = 0 THEN 2.00
      WHEN coalesce(ev.cnt, 0) = 1 THEN 2.50
      WHEN coalesce(ev.cnt, 0) = 2 THEN 3.00
      ELSE null  -- уже максимум 3.5%
    END,
    'events', coalesce(ev.events, '[]'::jsonb)
  ) INTO v_stats
  FROM (
    SELECT
      count(*)         AS cnt,
      sum(bonus_credited) AS total_earned,
      jsonb_agg(jsonb_build_object(
        'tier', tier, 'pct', pct, 'bonus', bonus_credited, 'at', created_at
      ) ORDER BY created_at) AS events
    FROM referral_events WHERE referrer_id = v_client_id
  ) ev;

  RETURN v_stats;
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.get_referral_stats(text, text) TO anon, authenticated, service_role;
