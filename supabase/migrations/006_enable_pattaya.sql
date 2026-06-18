-- Включить рынок Паттайя
update markets 
set active = true, tagline = 'Авторские туры и экскурсии' 
where slug = 'pattaya';

-- Заполняем market_id у туров Паттайи
do $$ begin
  if exists (select 1 from information_schema.columns where table_name='tours' and column_name='city') then
    -- markets.url Активен
    update tours t
    set city = 'Паттайя'
    where t.city is null or t.city = '';
  end if;
end $$;