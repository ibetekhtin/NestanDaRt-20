-- ============================================================
-- Нестандартный Отдых — Supabase Schema (REFERENCE)
-- Проект: cmmdrhususjuadqzyssc (NON-STANDART)
-- Это документация реальной схемы. Источник истины — сама база.
-- Изменения вносить миграциями, затем обновлять этот файл.
-- ============================================================

-- Туры (35 записей: Пхукет + Паттайя)
create table tours (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  city text,                      -- 'Пхукет' | 'Паттайя'
  category text,
  price_adult integer,
  price_child integer,
  duration text,
  description text,
  program text,
  image_url text,
  tags text[],
  included text[],
  not_included text[],
  what_to_bring text[],
  min_people integer default 1,
  max_people integer default 20,
  sort_order integer default 99,
  supplier text,
  active boolean default true,
  created_at timestamptz default now()
);

-- Клиенты
create table clients (
  id uuid primary key default gen_random_uuid(),
  name text,
  phone text,
  email text,
  telegram text,
  tg_chat_id text,
  whatsapp text,
  instagram text,
  vk text,
  source text,
  status text default 'Новый',
  stage text default 'new'        -- new|interest|thinking|booking|done|cold
    check (stage in ('new','interest','thinking','booking','done','cold')),
  country text,
  language text default 'ru',
  notes text,
  first_contact timestamptz default now(),
  last_contact timestamptz default now(),
  created_at timestamptz default now()
);

-- Заявки
create table bookings (
  id uuid primary key default gen_random_uuid(),
  external_id text unique,
  client_id uuid references clients(id),
  tour_id uuid references tours(id),
  tour_name text,
  date_start date,
  people_count integer,
  adults integer,
  children integer,
  budget integer,
  total integer,
  comment text,
  source text,
  status text default 'Новый',
  created_at timestamptz default now()
);

-- Платежи (YooKassa)
create table payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id),
  provider text default 'yookassa',
  payment_id text unique,
  amount integer,
  currency text default 'RUB',
  status text default 'pending', -- pending|succeeded|canceled
  confirmation_url text,
  created_at timestamptz default now(),
  paid_at timestamptz
);

-- Отзывы
create table reviews (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id),
  tour_id uuid references tours(id),
  booking_id uuid references bookings(id),
  rating integer check (rating >= 1 and rating <= 5),
  text text,
  created_at timestamptz default now()
);

-- Партнёры
create table partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text,
  contact text,
  notes text,
  created_at timestamptz default now()
);

-- История действий
create table action_history (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id),
  booking_id uuid references bookings(id),
  action text not null,
  details jsonb,
  created_at timestamptz default now()
);

-- КотЭ: память о клиенте
create table client_memory (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) not null,
  interests text[],
  budget_level text default 'medium' check (budget_level in ('low','medium','high','vip')),
  travel_style text,
  last_intent text,
  last_tour_viewed text,
  tours_viewed text[],
  tours_booked text[],
  arrival_date text,
  group_size integer,
  has_children boolean default false,
  updated_at timestamptz default now()
);

-- КотЭ: история диалогов
create table conversations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) not null,
  message text not null,
  response text,
  intent text,
  source text default 'telegram' check (source in ('telegram','site','app')),
  created_at timestamptz default now()
);

-- КотЭ: база знаний (26+ записей о Пхукете)
create table knowledge (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in
    ('place','beach','food','shopping','lifehack','transport','price','safety','event','faq')),
  city text not null default 'Пхукет' check (city in ('Пхукет','Паттайя','Общее')),
  title text not null,
  content text not null,
  area text,
  price_info text,
  tags text[],
  best_time text,
  insider_tip text,
  related_tour_slug text,
  source text default 'manual',
  active boolean default true,
  priority integer default 50,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Контент-план (вкладка «Контент-завод» в HQ)
create table content_plan (
  id uuid primary key default gen_random_uuid(),
  city text default 'Пхукет',
  week integer,
  date date,
  type text,
  title text not null,
  body text,
  status text default 'draft' check (status in ('draft','ready','published')),
  created_at timestamptz default now()
);

-- ============================================================
-- БЕЗОПАСНОСТЬ (RLS)
-- ============================================================
-- Принципы:
--   anon (сайт, бот):
--     * читает tours (active), knowledge (active), reviews
--     * вставляет clients (только status='Новый'), bookings (только 'Новый'),
--       conversations (source='site'), reviews (с валидным rating)
--     * НЕ читает clients/bookings/payments/conversations/client_memory
--   authenticated (HQ): доступ только через public.is_admin() —
--     email в JWT должен совпадать с админским.
--   КотЭ (n8n): работает через SECURITY DEFINER RPC:
--     get_kote_context, upsert_client_memory, update_client_stage, app_upsert_lead
--
-- Полный список политик: select * from pg_policies where schemaname='public';

-- Админ-проверка для политик HQ
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce(auth.jwt()->>'email', '') = 'ibetekhtin@gmail.com' $$;
