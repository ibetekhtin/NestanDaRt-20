# MULTI-MARKET

## Принцип

Один бренд. Один код. Одна база данных. Много рынков.

Новый рынок — это данные внутри существующей системы, а не новый репозиторий.

---

## Как устроено сейчас

Рынок определяется полем **`city`** в таблицах:

- `tours.city` — 'Пхукет' | 'Паттайя'
- `knowledge.city` — 'Пхукет' | 'Паттайя' | 'Общее'
- `content_plan.city`

HQ-панель фильтрует всё по выбранному городу (переключатель в сайдбаре).
Сайт переключает города через `js/config.js` → `markets`.

---

## Как добавить новый рынок (например, Бали)

### 1. База данных

Расширить check-constraint города и добавить данные:

```sql
alter table knowledge drop constraint knowledge_city_check;
alter table knowledge add constraint knowledge_city_check
  check (city in ('Пхукет','Паттайя','Бали','Общее'));

insert into tours (slug, title, city, category, price_adult, ...)
values ('bali-volcano', 'Восход на вулкане Батур', 'Бали', ...);
```

### 2. Сайт

Добавить запись в `nestandart-phuket/js/config.js` → `markets` и в `shared/markets.js`.

### 3. HQ

Добавить город в маппинг `MARKET_CITY` (`hq/src/context/AppContext.jsx`) и в список `MARKETS` (`hq/src/App.jsx`).

### 4. КотЭ

Добавить туры рынка в промпт / базу знаний (`knowledge` с `city = 'Бали'`).

---

## Правила разработки

- Каждая контентная таблица имеет колонку `city`
- Никаких хардкодов городов в логике — только данные
- В будущем при росте: вынести города в таблицу `markets` и заменить text-поля на FK

---

## Текущие рынки

| Город | Статус |
|-------|--------|
| Пхукет | ✅ Активен (туры, знания, бот) |
| Паттайя | 🟡 Туры есть, сайт «coming soon» |
| Бали | 📋 Planned |
| Дубай | 📋 Planned |
