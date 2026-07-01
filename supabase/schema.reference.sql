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


-- get_kote_context(p_tg_chat_id, p_query, p_secret) — SECURITY DEFINER
-- Память клиента (имя, стадия, диалоги) отдаётся ТОЛЬКО при верном p_secret
-- (sha256-хеш в теле функции; сам секрет — в n8n .env как KOTE_RPC_SECRET).
-- Без секрета: каталог туров и знания отдаются (публичны), личные поля = null.
-- Защита от перебора tg_chat_id анонимами.


-- ============================================================
-- ОБНОВЛЕНИЕ СХЕМЫ (добавлено 2026-06-17)
-- ============================================================

-- Рынки (Пхукет, Паттайя, Бали, Дубай, Вьетнам, Шри-Ланка)
-- market_id — ключ мультирыночности. Новый рынок = новая строка.
create table if not exists markets (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,        -- 'phuket' | 'pattaya' | ...
  name         text not null,               -- 'Пхукет'
  name_en      text,                        -- 'Phuket'
  accent_color text default '#B8FF3C',      -- CSS цвет акцента
  active       boolean default false,
  sort_order   integer default 99,
  tagline      text,
  created_at   timestamptz default now()
);

-- Начальные данные рынков
insert into markets (slug, name, name_en, accent_color, active, sort_order, tagline) values
  ('phuket',    'Пхукет',    'Phuket',    '#B8FF3C', true,  1, 'Авторские туры и экскурсии'),
  ('pattaya',   'Паттайя',   'Pattaya',   '#FF5C1F', true,  2, 'Тайланд на полную'),
  ('bali',      'Бали',      'Bali',      '#B8FF3C', false, 3, 'Скоро'),
  ('dubai',     'Дубай',     'Dubai',     '#FFD700', false, 4, 'Скоро'),
  ('vietnam',   'Вьетнам',   'Vietnam',   '#B8FF3C', false, 5, 'Скоро'),
  ('srilanka',  'Шри-Ланка', 'Sri Lanka', '#B8FF3C', false, 6, 'Скоро')
on conflict (slug) do nothing;

-- Добавляем market_id в tours (если ещё нет поля)
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name='tours' and column_name='market_id'
  ) then
    alter table tours add column market_id uuid references markets(id);
    -- Заполняем существующие туры: city='Пхукет' → markets.slug='phuket'
    update tours t
    set market_id = m.id
    from markets m
    where t.city = m.name and m.id is not null;
  end if;
end $$;


-- ── RPC: get_bookings_by_phone ────────────────────────────────
-- Возвращает брони клиента по номеру телефона
-- Используется мобильным приложением и HQ

create or replace function public.get_bookings_by_phone(p_phone text)
returns table (
  booking_id   uuid,
  tour_name    text,
  date_start   date,
  people_count integer,
  total        integer,
  status       text,
  created_at   timestamptz
)
language sql stable security definer
set search_path = ''
as $$
  select
    b.id,
    b.tour_name,
    b.date_start,
    b.people_count,
    b.total,
    b.status,
    b.created_at
  from public.bookings b
  join public.clients c on c.id = b.client_id
  where c.phone = p_phone
  order by b.created_at desc
  limit 20;
$$;


-- ── RPC: app_upsert_lead (документация — функция уже в базе) ──
-- Единая точка входа для лидов: сайт + бот + приложение
-- create or replace function public.app_upsert_lead(
--   p_name text, p_phone text, p_telegram text,
--   p_tg_chat_id text, p_source text, p_market_id uuid
-- ) returns uuid ...
-- (полный код в реальной базе, здесь для справки)


-- ── RLS: markets (публичное чтение) ──────────────────────────
alter table markets enable row level security;

create policy "anon читает активные рынки"
  on markets for select
  to anon
  using (active = true);

create policy "authenticated видит все рынки"
  on markets for all
  to authenticated
  using (public.is_admin());
