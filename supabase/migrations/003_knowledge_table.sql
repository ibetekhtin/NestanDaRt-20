-- 003: Таблица knowledge для инструмента search_knowledge
-- Запустить в Supabase Dashboard → SQL Editor

CREATE TABLE IF NOT EXISTS knowledge (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  market TEXT NOT NULL DEFAULT 'phuket',
  category TEXT NOT NULL DEFAULT 'general',
  insider_tip TEXT,
  related_tour_slug TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_knowledge_market ON knowledge(market);
CREATE INDEX IF NOT EXISTS idx_knowledge_category ON knowledge(category);

-- Full-text search index
CREATE INDEX IF NOT EXISTS idx_knowledge_search ON knowledge
  USING GIN (to_tsvector('simple', title || ' ' || content));

-- RLS: читать могут все, писать только service_role
ALTER TABLE knowledge ENABLE ROW LEVEL SECURITY;

CREATE POLICY "knowledge_select_all" ON knowledge
  FOR SELECT USING (true);

CREATE POLICY "knowledge_insert_service" ON knowledge
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "knowledge_update_service" ON knowledge
  FOR UPDATE USING (auth.role() = 'service_role');

CREATE POLICY "knowledge_delete_service" ON knowledge
  FOR DELETE USING (auth.role() = 'service_role');

-- Примеры данных для Пхукета
INSERT INTO knowledge (title, content, market, category, insider_tip, related_tour_slug) VALUES
(
  'Где поесть на Пхукете — лучшие рестораны',
  'На Пхукете стоит попробовать: 1) Bangla Road — уличная еда, 2) Kata Beach — морепродукты, 3) Old Town — тайская кухня. Средний чек 200-500 бат.',
  'phuket', 'food',
  'locals ходят в restaurants на Soi Romanee — дешевле и вкуснее tourist spots',
  NULL
),
(
  'Безопасность на Пхукете',
  'Пхукет безопасен для туристов. Главное: не оставлять вещи без присмотра на пляже, беречь от солнца, пить бутилированную воду. Экстренные номера: полиция 191, скорая 1669.',
  'phuket', 'safety',
  'в Phuket Town есть русскоязычные врачи — спрашивайте в отеле',
  NULL
),
(
  'Лучшие экскурсии на Пхукете',
  'Популярные экскурсии: 1) James Bond Island (4500 бат), 2) Phi Phi Islands (1500 бат), 3)大象保护中心 (2500 бат). Бронируйте через проверенных операторов.',
  'phuket', 'attraction',
  'заказывайте экскурсии через locals — дешевле на 30-40% чем через отель',
  'mototour'
),
(
  'Виза в Таиланд для россиян',
  'Россияне получают бесплатную визу на 60 дней по прибытии. Нужен загранпаспорт (6+ месяцев), обратный билет и бронь отеля. Продление возможно на 30 дней в иммиграционном офисе.',
  'phuket', 'visa',
  NULL,
  NULL
),
(
  'Как добраться из аэропорта Пхукета',
  'Из аэропорта Пхукета: 1) Такси — 800-1500 бат (зависит от района), 2) Airport bus — 100 бат, 3) Аренда мотобайка — 250 бат/день. Букинг трансфера заранее экономит время.',
  'phuket', 'transport',
  'pre-book transfer через нас — дешевле и без ожидания в очереди',
  NULL
);