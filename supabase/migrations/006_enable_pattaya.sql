-- Включение рынка Паттайя
-- Под реальную схему: markets.id = text, нет slug, tours.market_id = text

-- 1. Добавляем slug в markets (для совместимости с кодом)
alter table markets add column if not exists slug text unique;

-- 2. Заполняем slug для существующих рынков
update markets set slug = 'phuket' where name = 'Пхукет' and slug is null;
update markets set slug = 'pattaya' where name = 'Паттайя' and slug is null;
update markets set slug = 'bali' where name = 'Бали' and slug is null;
update markets set slug = 'dubai' where name = 'Дубай' and slug is null;

-- 3. Создаём/включаем Паттайю (id = 'pattaya' как text)
insert into markets (id, name, slug, active, sort_order, tagline)
values (
  'pattaya',
  'Паттайя',
  'pattaya',
  true,
  2,
  'Авторские туры и экскурсии'
)
on conflict (id) do update set
  active = true,
  tagline = excluded.tagline;

-- 4. market_id в tours — если нет, добавляем как text
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name='tours' and column_name='market_id'
  ) then
    alter table tours add column market_id text references markets(id);
  end if;
end $$;

-- 5. Связываем туры Паттайи с market_id = 'pattaya'
update tours t
set market_id = 'pattaya'
where t.city = 'Паттайя'
  and t.market_id is null;
