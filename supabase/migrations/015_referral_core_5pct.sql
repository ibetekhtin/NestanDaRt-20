-- 015 — Рефералка (ядро БД). Применено 2026-06-22 (Supabase MCP). Протестировано на откате:
-- друг оплатил 10000฿ → реферер получил +500฿ (5%) в bonus_balance.
-- Правило: реферер получает 5% от ОПЛАЧЕННЫХ покупок приведённого друга.
-- Колонки уже были: clients.ref_code, referred_by, bonus_balance (฿).
--
-- ✅ Сделано здесь (БД):
--   1. ref_code у каждого клиента (бэкафилл + DEFAULT для новых).
--   2. apply_referral(tg_chat_id, ref_code, secret) — привязать друга к рефереру (бот/app зовёт по реф-ссылке).
--   3. триггер referral_bonus — при переходе брони в 'Оплачено' авто-начисляет рефереру 5% (идемпотентно).
--
-- ⏳ Осталось (фронт/бот — зона владельца):
--   • Бот: на /start с параметром ref_<CODE> вызвать apply_referral. Показывать клиенту его реф-ссылку
--     (t.me/phuket_nestandart_bot?start=ref_<его ref_code>) и баланс бонусов.
--   • Приложение/сайт: ?ref=<CODE> при заявке → apply_referral; на чек-ауте применять bonus_balance как скидку.

UPDATE clients SET ref_code = upper(substr(md5(gen_random_uuid()::text),1,8))
  WHERE ref_code IS NULL OR ref_code = '';
ALTER TABLE clients ALTER COLUMN ref_code SET DEFAULT upper(substr(md5(gen_random_uuid()::text),1,8));

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS referral_credited_at timestamptz;

CREATE OR REPLACE FUNCTION public.apply_referral(p_tg_chat_id text, p_ref_code text, p_secret text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_client uuid; v_owner uuid;
BEGIN
  IF encode(extensions.digest(coalesce(p_secret,''),'sha256'),'hex')
     != '60a5314f6077c3cea81aef7dc9bd27321f57f7127d4999e0584fdcea65895eda' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT id INTO v_client FROM clients WHERE tg_chat_id = p_tg_chat_id LIMIT 1;
  IF v_client IS NULL THEN RETURN jsonb_build_object('ok',false,'reason','client_not_found'); END IF;
  SELECT id INTO v_owner FROM clients WHERE ref_code = upper(p_ref_code) AND id <> v_client LIMIT 1;
  IF v_owner IS NULL THEN RETURN jsonb_build_object('ok',false,'reason','bad_code'); END IF;
  UPDATE clients SET referred_by = upper(p_ref_code)
    WHERE id = v_client AND (referred_by IS NULL OR referred_by = '');
  RETURN jsonb_build_object('ok',true,'referrer',v_owner);
END; $function$;
GRANT EXECUTE ON FUNCTION public.apply_referral(text,text,text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.trg_referral_bonus()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_ref_code text; v_owner uuid; v_bonus int;
BEGIN
  IF NEW.status = 'Оплачено' AND OLD.status IS DISTINCT FROM 'Оплачено' AND NEW.referral_credited_at IS NULL THEN
    SELECT referred_by INTO v_ref_code FROM clients WHERE id = NEW.client_id;
    IF v_ref_code IS NOT NULL AND v_ref_code <> '' THEN
      SELECT id INTO v_owner FROM clients WHERE ref_code = v_ref_code AND id <> NEW.client_id LIMIT 1;
      IF v_owner IS NOT NULL THEN
        v_bonus := round(coalesce(NEW.total,0) * 0.05);
        UPDATE clients SET bonus_balance = coalesce(bonus_balance,0) + v_bonus WHERE id = v_owner;
        NEW.referral_credited_at := now();
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END; $function$;

DROP TRIGGER IF EXISTS referral_bonus ON public.bookings;
CREATE TRIGGER referral_bonus BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.trg_referral_bonus();
