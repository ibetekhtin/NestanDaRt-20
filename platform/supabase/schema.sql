-- ============================================================
-- Нестандартный Отдых — Supabase Schema
-- Single source of truth for all markets
-- ============================================================

-- Markets
create table if not exists markets (
  id         text primary key,          -- 'phuket', 'pattaya', 'bali', 'dubai'
  name       text not null,
  active     boolean default false,
  tg_bot     text,
  wa_phone   text,
  domain     text,
  created_at timestamptz default now()
);

insert into markets (id, name, active, tg_bot, wa_phone, domain) values
  ('phuket',  'Пхукет',  true,  'nestandart_phuket', '66804894595', 'nestandart-phuket.ru'),
  ('pattaya', 'Паттайя', false, 'nestandart_phuket', '66804894595', 'nestandart-pattaya.ru'),
  ('bali',    'Бали',    false, 'nestandart_phuket', '66804894595', 'nestandart-bali.ru'),
  ('dubai',   'Дубай',   false, 'nestandart_phuket', '66804894595', 'nestandart-dubai.ru')
on conflict do nothing;

-- Clients
create table if not exists clients (
  id         uuid primary key default gen_random_uuid(),
  market_id  text references markets(id) not null,
  name       text not null,
  phone      text,
  telegram   text,
  source     text,                      -- 'Telegram', 'Бот', 'ВКонтакте', etc.
  notes      text,
  created_at timestamptz default now()
);

-- Tours
create table if not exists tours (
  id         uuid primary key default gen_random_uuid(),
  market_id  text references markets(id) not null,
  name       text not null,
  type       text,
  price      numeric not null,
  active     boolean default true,
  created_at timestamptz default now()
);

-- Bookings
create table if not exists bookings (
  id         uuid primary key default gen_random_uuid(),
  market_id  text references markets(id) not null,
  client_id  uuid references clients(id),
  tour_id    uuid references tours(id),
  status     text default 'new',        -- 'new', 'deposit', 'active', 'done', 'cancelled'
  date       date,
  amount     numeric,
  created_at timestamptz default now()
);

-- Transactions
create table if not exists transactions (
  id          uuid primary key default gen_random_uuid(),
  market_id   text references markets(id) not null,
  type        text not null,            -- 'income', 'expense'
  category    text,
  amount      numeric not null,
  description text,
  date        date default current_date,
  created_at  timestamptz default now()
);

-- Content plan
create table if not exists content_plan (
  id         uuid primary key default gen_random_uuid(),
  market_id  text references markets(id) not null,
  week       int,
  date       date,
  type       text,
  title      text not null,
  body       text,
  status     text default 'draft',     -- 'draft', 'ready', 'published'
  created_at timestamptz default now()
);

-- KotE: client memory (one row per client)
create table if not exists client_memory (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid references clients(id) unique,
  market_id   text references markets(id),
  name        text,
  travel_dates text,
  group_size  int,
  interests   text[],
  past_tours  text[],
  notes       text,
  updated_at  timestamptz default now()
);

-- KotE: AI interactions log
create table if not exists ai_interactions (
  id          uuid primary key default gen_random_uuid(),
  market_id   text references markets(id),
  client_id   uuid references clients(id),
  role        text not null,            -- 'user', 'assistant'
  message     text not null,
  created_at  timestamptz default now()
);

-- RLS: enable row level security on all tables
alter table markets          enable row level security;
alter table clients          enable row level security;
alter table tours            enable row level security;
alter table bookings         enable row level security;
alter table transactions     enable row level security;
alter table content_plan     enable row level security;
alter table client_memory    enable row level security;
alter table ai_interactions  enable row level security;
