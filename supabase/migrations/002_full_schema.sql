-- ============================================================================
-- ⚠️  УСТАРЕВШИЙ / ИСТОРИЧЕСКИЙ ФАЙЛ — НЕ ПРИМЕНЯТЬ К PRODUCTION  ⚠️
-- ============================================================================
-- Описывает модель `leads`/`ai_interactions` и сигнатуру app_upsert_lead
-- (p_market_id/p_telegram_id/p_email/p_notes), которой НЕТ в боевой БД.
-- Боевой app_upsert_lead имеет 18 параметров (p_external_id..p_status, без
-- p_market_id), пишет в clients/bookings, а не в leads. Источник правды — БД
-- cmmdrhususjuadqzyssc. См. также комментарий в 005_*. Оставлен как история.
-- Применение поверх прода СЛОМАЕТ запись лидов.
-- ============================================================================
-- Migration 002 — Full Schema (Leads, Memory, Reviews, Partners, AI, Audit) (LEGACY)
-- ============================================================================
-- Зависимости: schema.sql (002 рассчитан на применение ПОСЛЕ schema.sql)
-- Все таблицы multi-market (market_id) для горизонтального масштабирования.
-- ============================================================================

-- ============================================================================
-- LEADS — лиды до бронирования (потенциальные клиенты)
-- ============================================================================
CREATE TABLE IF NOT EXISTS leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  telegram_id TEXT,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  source TEXT NOT NULL DEFAULT 'telegram' CHECK (source IN ('telegram', 'website', 'mobile', 'manual', 'partner')),
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'qualified', 'converted', 'lost')),
  notes TEXT,
  assigned_to TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_leads_market ON leads(market_id);
CREATE INDEX IF NOT EXISTS idx_leads_telegram ON leads(telegram_id);
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_source ON leads(source);
CREATE INDEX IF NOT EXISTS idx_leads_created ON leads(created_at DESC);

-- ============================================================================
-- AI_INTERACTIONS — полный лог AI-общения (аналитика, обучение, debugging)
-- ============================================================================
CREATE TABLE IF NOT EXISTS ai_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
  session_id TEXT NOT NULL,
  user_message TEXT NOT NULL,
  ai_response TEXT NOT NULL,
  model TEXT NOT NULL DEFAULT 'gemini-2.0-flash',
  tokens_used INTEGER,
  latency_ms INTEGER,
  intent TEXT, -- question, recommendation, booking, sos, other
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_market ON ai_interactions(market_id);
CREATE INDEX IF NOT EXISTS idx_ai_client ON ai_interactions(client_id);
CREATE INDEX IF NOT EXISTS idx_ai_session ON ai_interactions(session_id);
CREATE INDEX IF NOT EXISTS idx_ai_intent ON ai_interactions(intent);
CREATE INDEX IF NOT EXISTS idx_ai_created ON ai_interactions(created_at DESC);

-- ============================================================================
-- CLIENT_MEMORY — долгосрочная память клиента (предпочтения, история)
-- ============================================================================
CREATE TABLE IF NOT EXISTS client_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  market_id TEXT NOT NULL REFERENCES markets(id),
  key TEXT NOT NULL,                  -- 'prefers_pool', 'allergic_seafood', 'anniversary_2024'
  value TEXT NOT NULL,                -- JSON-string или plain text
  importance SMALLINT NOT NULL DEFAULT 5 CHECK (importance BETWEEN 1 AND 10),
  expires_at TIMESTAMPTZ,             -- NULL = постоянная
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (client_id, market_id, key)
);

CREATE INDEX IF NOT EXISTS idx_memory_client ON client_memory(client_id);
CREATE INDEX IF NOT EXISTS idx_memory_market ON client_memory(market_id);
CREATE INDEX IF NOT EXISTS idx_memory_key ON client_memory(key);
CREATE INDEX IF NOT EXISTS idx_memory_active ON client_memory(client_id, market_id) WHERE expires_at IS NULL OR expires_at > now();

-- ============================================================================
-- REVIEWS — отзывы клиентов (1-5 звёзд + текст)
-- ============================================================================
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  service_id UUID REFERENCES services(id) ON DELETE SET NULL,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('pending', 'published', 'hidden')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reviews_market ON reviews(market_id);
CREATE INDEX IF NOT EXISTS idx_reviews_client ON reviews(client_id);
CREATE INDEX IF NOT EXISTS idx_reviews_service ON reviews(service_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_reviews_published ON reviews(market_id, created_at DESC) WHERE status = 'published';

-- ============================================================================
-- PARTNERS — поставщики услуг (отели, трансфер-компании, гиды)
-- ============================================================================
CREATE TABLE IF NOT EXISTS partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('hotel', 'transfer', 'guide', 'rental', 'restaurant', 'other')),
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  telegram_id TEXT,
  commission_pct NUMERIC(5,2) DEFAULT 0 CHECK (commission_pct BETWEEN 0 AND 100),
  notes TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partners_market ON partners(market_id);
CREATE INDEX IF NOT EXISTS idx_partners_type ON partners(type);
CREATE INDEX IF NOT EXISTS idx_partners_active ON partners(active) WHERE active = true;

-- ============================================================================
-- ACTION_HISTORY — журнал всех значимых действий (audit log)
-- ============================================================================
CREATE TABLE IF NOT EXISTS action_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT REFERENCES markets(id),
  actor_type TEXT NOT NULL CHECK (actor_type IN ('user', 'manager', 'bot', 'system', 'n8n')),
  actor_id TEXT,                      -- telegram_id, manager_chat_id, system name
  action TEXT NOT NULL,               -- 'create_booking', 'cancel_booking', 'send_sos', etc.
  entity_type TEXT,                   -- 'booking', 'lead', 'client', etc.
  entity_id UUID,
  payload JSONB,                      -- дополнительные данные
  ip_address INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_action_market ON action_history(market_id);
CREATE INDEX IF NOT EXISTS idx_action_actor ON action_history(actor_type, actor_id);
CREATE INDEX IF NOT EXISTS idx_action_entity ON action_history(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_action_action ON action_history(action);
CREATE INDEX IF NOT EXISTS idx_action_created ON action_history(created_at DESC);

-- ============================================================================
-- TOURS — расширенная информация о турах (для AI рекомендаций)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  duration_hours NUMERIC(5,2),
  difficulty TEXT CHECK (difficulty IN ('easy', 'medium', 'hard')),
  group_size_max INTEGER,
  languages TEXT[],                   -- ['ru', 'en', 'th']
  highlights TEXT[],                  -- ['Пхи-Пхи', 'снорклинг', 'обед']
  includes TEXT[],                    -- ['трансфер', 'обед', 'снаряжение']
  not_suitable_for TEXT[],            -- ['дети до 3', 'беременные']
  best_season TEXT,                   -- 'nov-apr'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (service_id)
);

CREATE INDEX IF NOT EXISTS idx_tours_market ON tours(market_id);
CREATE INDEX IF NOT EXISTS idx_tours_difficulty ON tours(difficulty);
CREATE INDEX IF NOT EXISTS idx_tours_languages ON tours USING GIN (languages);
CREATE INDEX IF NOT EXISTS idx_tours_highlights ON tours USING GIN (highlights);

-- ============================================================================
-- TRIGGERS — автолог в action_history
-- ============================================================================

CREATE OR REPLACE FUNCTION log_action() RETURNS TRIGGER AS $$
DECLARE
  v_market_id TEXT;
  v_entity_id UUID;
  v_action TEXT;
BEGIN
  -- определяем market_id
  IF TG_OP = 'DELETE' THEN
    v_market_id := OLD.market_id;
    v_entity_id := OLD.id;
  ELSE
    v_market_id := NEW.market_id;
    v_entity_id := NEW.id;
  END IF;

  v_action := lower(TG_OP) || '_' || TG_TABLE_NAME;

  INSERT INTO action_history (market_id, actor_type, actor_id, action, entity_type, entity_id, payload)
  VALUES (
    v_market_id,
    'system',
    current_setting('app.actor_id', true),
    v_action,
    TG_TABLE_NAME,
    v_entity_id,
    CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Применяем триггер к ключевым таблицам (без messages и ai_interactions — слишком шумно)
DROP TRIGGER IF EXISTS trg_log_bookings ON bookings;
CREATE TRIGGER trg_log_bookings
  AFTER INSERT OR UPDATE OR DELETE ON bookings
  FOR EACH ROW EXECUTE FUNCTION log_action();

DROP TRIGGER IF EXISTS trg_log_leads ON leads;
CREATE TRIGGER trg_log_leads
  AFTER INSERT OR UPDATE OR DELETE ON leads
  FOR EACH ROW EXECUTE FUNCTION log_action();

DROP TRIGGER IF EXISTS trg_log_payments ON payments;
CREATE TRIGGER trg_log_payments
  AFTER INSERT OR UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION log_action();

-- updated_at maintenance
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_leads ON leads;
CREATE TRIGGER trg_touch_leads BEFORE UPDATE ON leads FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_touch_memory ON client_memory;
CREATE TRIGGER trg_touch_memory BEFORE UPDATE ON client_memory FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_touch_partners ON partners;
CREATE TRIGGER trg_touch_partners BEFORE UPDATE ON partners FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS trg_touch_tours ON tours;
CREATE TRIGGER trg_touch_tours BEFORE UPDATE ON tours FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ============================================================================
-- RPC: app_upsert_lead
-- Безопасно создаёт/обновляет лид. Возвращает lead.id.
-- ============================================================================
CREATE OR REPLACE FUNCTION app_upsert_lead(
  p_market_id TEXT,
  p_telegram_id TEXT DEFAULT NULL,
  p_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_source TEXT DEFAULT 'telegram',
  p_notes TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  -- если есть лид с таким telegram_id — обновим
  IF p_telegram_id IS NOT NULL THEN
    SELECT id INTO v_id FROM leads
    WHERE market_id = p_market_id AND telegram_id = p_telegram_id
    ORDER BY created_at DESC LIMIT 1;

    IF v_id IS NOT NULL THEN
      UPDATE leads
      SET name = COALESCE(p_name, name),
          phone = COALESCE(p_phone, phone),
          email = COALESCE(p_email, email),
          notes = COALESCE(p_notes, notes)
      WHERE id = v_id;
      RETURN v_id;
    END IF;
  END IF;

  -- иначе создаём
  IF p_name IS NULL OR p_name = '' THEN
    RAISE EXCEPTION 'name is required for new lead';
  END IF;

  INSERT INTO leads (market_id, telegram_id, name, phone, email, source, notes)
  VALUES (p_market_id, p_telegram_id, p_name, p_phone, p_email, p_source, p_notes)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: app_create_booking
-- Создаёт бронь + автоматически создаёт/обновляет лид.
-- ============================================================================
CREATE OR REPLACE FUNCTION app_create_booking(
  p_market_id TEXT,
  p_telegram_id TEXT,
  p_client_name TEXT,
  p_service_id UUID,
  p_date DATE,
  p_total NUMERIC DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_client_id UUID;
  v_lead_id UUID;
  v_service RECORD;
  v_booking_id UUID;
BEGIN
  -- 1. Получаем/создаём клиента
  SELECT id INTO v_client_id FROM clients
  WHERE market_id = p_market_id AND telegram_id = p_telegram_id
  LIMIT 1;

  IF v_client_id IS NULL THEN
    INSERT INTO clients (market_id, telegram_id, name)
    VALUES (p_market_id, p_telegram_id, p_client_name)
    RETURNING id INTO v_client_id;
  END IF;

  -- 2. Получаем цену услуги если total не задан
  IF p_total IS NULL THEN
    SELECT price, currency INTO v_service FROM services WHERE id = p_service_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'service not found: %', p_service_id;
    END IF;
    p_total := v_service.price;
  END IF;

  -- 3. Создаём бронь
  INSERT INTO bookings (market_id, client_id, service_id, date, total, status)
  VALUES (p_market_id, v_client_id, p_service_id, p_date, p_total, 'draft')
  RETURNING id INTO v_booking_id;

  -- 4. Создаём/обновляем лид
  v_lead_id := app_upsert_lead(
    p_market_id, p_telegram_id, p_client_name, NULL, NULL, 'telegram',
    'Auto-created from booking ' || v_booking_id::text
  );

  -- 5. Помечаем лид как converted
  UPDATE leads SET status = 'converted' WHERE id = v_lead_id;

  RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: app_update_memory
-- Upsert в client_memory.
-- ============================================================================
CREATE OR REPLACE FUNCTION app_update_memory(
  p_client_id UUID,
  p_market_id TEXT,
  p_key TEXT,
  p_value TEXT,
  p_importance SMALLINT DEFAULT 5,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO client_memory (client_id, market_id, key, value, importance, expires_at)
  VALUES (p_client_id, p_market_id, p_key, p_value, p_importance, p_expires_at)
  ON CONFLICT (client_id, market_id, key)
  DO UPDATE SET
    value = EXCLUDED.value,
    importance = EXCLUDED.importance,
    expires_at = EXCLUDED.expires_at,
    updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: app_get_client_context
-- Возвращает активную память клиента (для подмешивания в AI контекст).
-- ============================================================================
CREATE OR REPLACE FUNCTION app_get_client_context(
  p_client_id UUID,
  p_market_id TEXT
) RETURNS TABLE (
  key TEXT,
  value TEXT,
  importance SMALLINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT cm.key, cm.value, cm.importance
  FROM client_memory cm
  WHERE cm.client_id = p_client_id
    AND cm.market_id = p_market_id
    AND (cm.expires_at IS NULL OR cm.expires_at > now())
  ORDER BY cm.importance DESC, cm.updated_at DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- RPC: app_get_market_stats
-- Статистика по рынку (для daily report).
-- ============================================================================
CREATE OR REPLACE FUNCTION app_get_market_stats(
  p_market_id TEXT,
  p_since TIMESTAMPTZ DEFAULT (now() - interval '24 hours')
) RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'new_leads', (SELECT count(*) FROM leads WHERE market_id = p_market_id AND created_at >= p_since),
    'new_bookings', (SELECT count(*) FROM bookings WHERE market_id = p_market_id AND created_at >= p_since),
    'confirmed_bookings', (SELECT count(*) FROM bookings WHERE market_id = p_market_id AND status = 'confirmed' AND created_at >= p_since),
    'revenue', (SELECT COALESCE(sum(p.amount), 0)
                FROM payments p
                JOIN bookings b ON b.id = p.booking_id
                WHERE b.market_id = p_market_id AND p.status = 'completed' AND p.created_at >= p_since),
    'ai_interactions', (SELECT count(*) FROM ai_interactions WHERE market_id = p_market_id AND created_at >= p_since),
    'avg_rating', (SELECT COALESCE(avg(rating), 0) FROM reviews WHERE market_id = p_market_id AND created_at >= p_since),
    'sos_count', (SELECT count(*) FROM ai_interactions WHERE market_id = p_market_id AND intent = 'sos' AND created_at >= p_since)
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- RPC: app_log_action
-- Универсальный логгер для ручных вызовов из приложения.
-- ============================================================================
CREATE OR REPLACE FUNCTION app_log_action(
  p_market_id TEXT,
  p_actor_type TEXT,
  p_actor_id TEXT,
  p_action TEXT,
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id UUID DEFAULT NULL,
  p_payload JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO action_history (market_id, actor_type, actor_id, action, entity_type, entity_id, payload)
  VALUES (p_market_id, p_actor_type, p_actor_id, p_action, p_entity_type, p_entity_id, p_payload)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VIEW: v_lead_stats — аналитика по лидам
-- ============================================================================
CREATE OR REPLACE VIEW v_lead_stats AS
SELECT
  l.market_id,
  m.name AS market_name,
  count(*) FILTER (WHERE l.status = 'new') AS new_count,
  count(*) FILTER (WHERE l.status = 'contacted') AS contacted_count,
  count(*) FILTER (WHERE l.status = 'qualified') AS qualified_count,
  count(*) FILTER (WHERE l.status = 'converted') AS converted_count,
  count(*) FILTER (WHERE l.status = 'lost') AS lost_count,
  count(*) AS total,
  round(100.0 * count(*) FILTER (WHERE l.status = 'converted') / NULLIF(count(*), 0), 2) AS conversion_pct
FROM leads l
JOIN markets m ON m.id = l.market_id
WHERE l.created_at >= now() - interval '30 days'
GROUP BY l.market_id, m.name;

GRANT SELECT ON v_lead_stats TO anon, authenticated;

-- ============================================================================
-- VIEW: v_booking_full — бронь + клиент + услуга + рынок
-- ============================================================================
CREATE OR REPLACE VIEW v_booking_full AS
SELECT
  b.id AS booking_id,
  b.market_id,
  m.name AS market_name,
  m.currency AS market_currency,
  b.client_id,
  c.telegram_id,
  c.name AS client_name,
  c.phone AS client_phone,
  b.service_id,
  s.title AS service_title,
  s.type AS service_type,
  s.image AS service_image,
  b.date,
  b.status,
  b.total,
  b.created_at
FROM bookings b
JOIN markets m ON m.id = b.market_id
JOIN clients c ON c.id = b.client_id
JOIN services s ON s.id = b.service_id;

GRANT SELECT ON v_booking_full TO anon, authenticated;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE tours ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- anon: только чтение справочников (read-only)
DROP POLICY IF EXISTS anon_read_markets ON markets;
CREATE POLICY anon_read_markets ON markets FOR SELECT TO anon USING (active = true);
DROP POLICY IF EXISTS anon_read_services ON services;
CREATE POLICY anon_read_services ON services FOR SELECT TO anon USING (available = true);
DROP POLICY IF EXISTS anon_read_reviews ON reviews;
CREATE POLICY anon_read_reviews ON reviews FOR SELECT TO anon USING (status = 'published');
DROP POLICY IF EXISTS anon_read_bookings ON bookings;
CREATE POLICY anon_read_bookings ON bookings FOR SELECT TO anon USING (false);

-- service_role: полный доступ (обходит RLS) — для бота и n8n
-- authenticated: полный доступ для backend API
DROP POLICY IF EXISTS auth_all_clients ON clients;
CREATE POLICY auth_all_clients ON clients FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS auth_all_bookings ON bookings;
CREATE POLICY auth_all_bookings ON bookings FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS auth_all_leads ON leads;
CREATE POLICY auth_all_leads ON leads FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS auth_all_reviews ON reviews;
CREATE POLICY auth_all_reviews ON reviews FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS auth_all_memory ON client_memory;
CREATE POLICY auth_all_memory ON client_memory FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS auth_all_partners ON partners;
CREATE POLICY auth_all_partners ON partners FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS auth_all_tours ON tours;
CREATE POLICY auth_all_tours ON tours FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS auth_all_payments ON payments;
CREATE POLICY auth_all_payments ON payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- SEED (опционально, для разработки)
-- ============================================================================
INSERT INTO partners (market_id, name, type, contact_name, phone, commission_pct, active) VALUES
  ('phuket', 'Phuket Tours Co.', 'guide', 'Somchai', '+66-90-000-0001', 15, true),
  ('phuket', 'Andaman Transfer', 'transfer', 'Niran', '+66-90-000-0002', 10, true),
  ('bali', 'Bali Scooter Rental', 'rental', 'Wayan', '+62-81-000-0001', 12, true),
  ('dubai', 'Dubai Marina Yachts', 'hotel', 'Ahmed', '+971-50-000-0001', 20, true)
ON CONFLICT DO NOTHING;
