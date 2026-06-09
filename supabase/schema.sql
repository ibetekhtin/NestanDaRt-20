-- ============================================================================
-- Нестандартный Отдых — Supabase Schema
-- ============================================================================
-- Архитектура: User → Bot/Web → AI (КотЭ) → Supabase → n8n → Provider → User
-- Все данные живут в Supabase. Бот не хранит состояние.
-- ============================================================================

-- MARKETS
CREATE TABLE markets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'THB',
  timezone TEXT NOT NULL DEFAULT 'Asia/Bangkok',
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CLIENTS
CREATE TABLE clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  telegram_id TEXT UNIQUE,
  name TEXT NOT NULL,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_clients_market ON clients(market_id);
CREATE INDEX idx_clients_telegram ON clients(telegram_id);

-- SERVICES (туры, трансферы, аренда — всё в одной таблице)
CREATE TABLE services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  type TEXT NOT NULL CHECK (type IN ('tour', 'transfer', 'rental')),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price NUMERIC(10,2) NOT NULL CHECK (price > 0),
  currency TEXT NOT NULL DEFAULT 'THB',
  image TEXT,
  available BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_services_market ON services(market_id);
CREATE INDEX idx_services_type ON services(type);

-- BOOKINGS
CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  client_id UUID NOT NULL REFERENCES clients(id),
  service_id UUID NOT NULL REFERENCES services(id),
  date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'confirmed', 'completed', 'cancelled')),
  total NUMERIC(10,2) NOT NULL CHECK (total >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_bookings_market ON bookings(market_id);
CREATE INDEX idx_bookings_client ON bookings(client_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_date ON bookings(date);

-- MESSAGES (лог чата с КотЭ — единый источник для AI)
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id TEXT NOT NULL REFERENCES markets(id),
  client_id UUID REFERENCES clients(id),
  session_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_session ON messages(session_id);
CREATE INDEX idx_messages_client ON messages(client_id);
CREATE INDEX idx_messages_market ON messages(market_id);

-- PAYMENTS
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id),
  amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'THB',
  method TEXT NOT NULL DEFAULT 'cash' CHECK (method IN ('cash', 'card', 'transfer', 'crypto')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payments_booking ON payments(booking_id);

CREATE OR REPLACE VIEW booking_details AS
SELECT
  b.id,
  b.market_id,
  b.client_id,
  c.telegram_id,
  b.service_id,
  s.title AS service_title,
  s.type AS service_type,
  s.price,
  s.currency,
  b.date,
  b.status,
  b.total,
  b.created_at
FROM bookings b
JOIN clients c ON c.id = b.client_id
JOIN services s ON s.id = b.service_id;

-- Доступ к VIEW для anon (сайт) и authenticated (n8n через service key и так всё видит)
GRANT SELECT ON booking_details TO anon, authenticated;

-- ============================================================================
-- SEED: Markets
-- ============================================================================
INSERT INTO markets (id, name, currency, timezone, active) VALUES
  ('phuket', 'Пхукет', 'THB', 'Asia/Bangkok', true),
  ('pattaya', 'Паттайя', 'THB', 'Asia/Bangkok', true),
  ('bali', 'Бали', 'IDR', 'Asia/Makassar', true),
  ('dubai', 'Дубай', 'AED', 'Asia/Dubai', true)
ON CONFLICT (id) DO NOTHING;