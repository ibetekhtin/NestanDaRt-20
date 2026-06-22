-- 018 — Авторские мото-туры: 5 программ по реальным данным от владельца.
-- Применено 2026-06-22 (Supabase MCP).
-- Источник: описание из ВК-группы nestandart_phuket_tour (10 552 подписчика).
-- Цена: 3000฿/чел (уточнена владельцем). Дети = та же цена (сидят с пассажиром).
-- Пешая по Пхукет-Тауну (ph-oldtown) тоже обновлена.

-- Основной МотоТур (slug=moto): цена 2500→3000, полное описание
UPDATE tours SET
  title       = 'МотоТур по Пхукету — Авторский тур',
  price_adult = 3000,
  price_child = 3000,
  duration    = '7–9 часов',
  description = 'Индивидуальный авторский тур по острову. Вы — пассажир на нашем мотоцикле. Основные достопримечательности + дикие пляжи, водопады, буддийские храмы и обзорные площадки. Глазами тех, кто живёт здесь и любит этот остров.',
  program     = 'Начало в 07:00. Выбирайте маршрут: Юг (Karon Viewpoint, Big Buddha, Wat Chalong, Promthep Cape, слоны) или Север (Laem Sing, Banana Beach, Mai Khao, водопад Bang Pae). Возможна комбинация.',
  tags        = ARRAY['мото','авторский','индивидуальный','остров','виды'],
  included    = ARRAY['Опытный водитель-гид', 'Вода в дороге', 'Все дорожные расходы'],
  not_included= ARRAY['Вход в нацпарк (300 бат)', 'Катание на слонах (1100 бат)'],
  sort_order  = 1,
  active      = true
WHERE slug = 'moto' AND market_id = 'phuket';

-- МотоТур: Юг острова
INSERT INTO tours (slug, title, city, category, price_adult, price_child, duration, description, program, tags, included, not_included, sort_order, active, market_id)
VALUES (
  'moto-south', 'МотоТур: Юг Пхукета',
  'Пхукет', 'Авторские', 3000, 3000, '7–9 часов',
  'Авторский мото-тур по южной части острова. Самые красивые смотровые площадки, символы Пхукета и тайский быт.',
  'Начало 07:00 | Karon Viewpoint (площадка трёх пляжей) → Big Buddha Phuket → Wat Chalong → Обзорная Hai Leng Ong Statue → Promthep Cape (место закатов) → дикий пляж → Слоновья ферма + обезьянки → Windmill Viewpoint',
  ARRAY['мото','юг','авторский','Big Buddha','Promthep','слоны'],
  ARRAY['Опытный водитель-гид', 'Вода', 'Все дорожные расходы'],
  ARRAY['Катание на слонах +1100 бат', 'Вход в нацпарк +300 бат'],
  2, true, 'phuket'
)
ON CONFLICT (slug) DO UPDATE SET
  title=EXCLUDED.title, price_adult=EXCLUDED.price_adult, price_child=EXCLUDED.price_child,
  duration=EXCLUDED.duration, description=EXCLUDED.description, program=EXCLUDED.program,
  tags=EXCLUDED.tags, included=EXCLUDED.included, not_included=EXCLUDED.not_included,
  sort_order=EXCLUDED.sort_order, active=EXCLUDED.active;

-- МотоТур: Север острова
INSERT INTO tours (slug, title, city, category, price_adult, price_child, duration, description, program, tags, included, not_included, sort_order, active, market_id)
VALUES (
  'moto-north', 'МотоТур: Север Пхукета',
  'Пхукет', 'Авторские', 3000, 3000, '7–9 часов',
  'Авторский мото-тур по северной части острова. Дикие пляжи, самолёты у кромки воды, водопад и мост на материк.',
  'Начало 07:00 | Laem Sing Viewpoint → дикий Banana Beach → Wat Mongkol Wararam → Mai Khao Beach (фото с самолётами!) → мост Sarasin Bridge (граница острова) → купание у водопада Bang Pae',
  ARRAY['мото','север','авторский','Banana Beach','Mai Khao','водопад'],
  ARRAY['Опытный водитель-гид', 'Вода', 'Все дорожные расходы'],
  ARRAY['Вход в нацпарк Bang Pae +300 бат'],
  3, true, 'phuket'
)
ON CONFLICT (slug) DO UPDATE SET
  title=EXCLUDED.title, price_adult=EXCLUDED.price_adult, price_child=EXCLUDED.price_child,
  duration=EXCLUDED.duration, description=EXCLUDED.description, program=EXCLUDED.program,
  tags=EXCLUDED.tags, included=EXCLUDED.included, not_included=EXCLUDED.not_included,
  sort_order=EXCLUDED.sort_order, active=EXCLUDED.active;

-- МотоТур: Рассвет
INSERT INTO tours (slug, title, city, category, price_adult, price_child, duration, description, program, tags, sort_order, active, market_id)
VALUES (
  'moto-sunrise', 'МотоТур: Рассвет',
  'Пхукет', 'Авторские', 3000, 3000, '3–4 часа',
  'Встречаем рассвет на лучших смотровых точках острова. Ранний выезд — минимум туристов, максимум впечатлений.',
  'Старт 05:00–05:30. Лучшие точки рассвета: Promthep Cape, Karon Viewpoint или Laem Sing — в зависимости от погоды и пожеланий. Возвращение к 09:00–10:00.',
  ARRAY['мото','рассвет','sunrise','ранний','романтика','смотровая'],
  4, true, 'phuket'
)
ON CONFLICT (slug) DO UPDATE SET
  title=EXCLUDED.title, price_adult=EXCLUDED.price_adult, price_child=EXCLUDED.price_child,
  duration=EXCLUDED.duration, description=EXCLUDED.description, program=EXCLUDED.program,
  tags=EXCLUDED.tags, sort_order=EXCLUDED.sort_order, active=EXCLUDED.active;

-- МотоТур: Закат
INSERT INTO tours (slug, title, city, category, price_adult, price_child, duration, description, program, tags, sort_order, active, market_id)
VALUES (
  'moto-sunset', 'МотоТур: Закат',
  'Пхукет', 'Авторские', 3000, 3000, '3–4 часа',
  'Провожаем закат на самых красивых точках острова. Promthep Cape — лучшее место на Пхукете для заката.',
  'Старт за 3–4 часа до заката. Windmill Viewpoint → Karon Viewpoint → Promthep Cape (встречаем закат). Возможна комбинация с вечерним купанием или ужином.',
  ARRAY['мото','закат','sunset','романтика','Promthep','вечер'],
  5, true, 'phuket'
)
ON CONFLICT (slug) DO UPDATE SET
  title=EXCLUDED.title, price_adult=EXCLUDED.price_adult, price_child=EXCLUDED.price_child,
  duration=EXCLUDED.duration, description=EXCLUDED.description, program=EXCLUDED.program,
  tags=EXCLUDED.tags, sort_order=EXCLUDED.sort_order, active=EXCLUDED.active;

-- ph-oldtown: обновить с реальным описанием
UPDATE tours SET
  title       = 'Пешая прогулка: Старый Пхукет-Таун',
  description = 'Авторская пешая экскурсия по историческому центру Пхукета. Португальская шино-португальская архитектура, уличное искусство, местные кафе, рынки и атмосфера настоящего азиатского города.',
  program     = 'Улицы Thalang Rd и Dibuk Rd, шино-португальские особняки, стрит-арт, местные кофейни, рынок Sunday Walking Street (по воскресеньям). История острова от гида.',
  duration    = '2–3 часа',
  price_adult = 1500,
  price_child = 1000,
  tags        = ARRAY['пешая','Пхукет-Таун','история','архитектура','культура','старый город'],
  active      = true
WHERE slug = 'ph-oldtown' AND market_id = 'phuket';
