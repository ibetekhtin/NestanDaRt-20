# СИНХРОНИЗАЦИЯ: бот + приложение + сайт

## Принцип: один источник правды
**Supabase — единственная база.** Все три канала читают из неё. Правишь данные в Supabase (или HQ-панели) →
изменения видны ВЕЗДЕ сразу, без передеплоя.

```
                ┌──────────── Supabase (источник правды) ────────────┐
                │  tours · packages · knowledge · clients · bookings   │
                │  gift_certificates · payments · markets · reviews     │
                └───────┬───────────────┬───────────────┬─────────────┘
                        │               │               │
                   🤖 Бот КотЭ      📱 Приложение      🌐 Сайт
                  (читает через    (platform/app/    (js/catalog.js →
                   get_kote_context  index.html,       REST anon-read)
                   + REST)           REST anon-read)
```

## Где что лежит
| Канал | Файлы | Источник данных |
|-------|-------|-----------------|
| Бот | `/opt/kote/platform/bot/` (деплой Docker `kote-bot`) | Supabase RPC + REST (service key) |
| Приложение | `/var/www/nestandart/platform/app/index.html` | Supabase REST (anon) |
| Сайт | `/var/www/nestandart/nestandart-phuket/` | `js/catalog.js` → Supabase REST (anon) |

## Как редактировать (одно место → везде)
- **Туры/цены/описания** → таблица `tours` (или HQ). Поля: `slug, title, city, market_id, category, price_adult, price_child, duration, description, image_url, active, sort_order, season_note`.
- **Наборы** → таблица `packages` (фикс-цена = 3 тура − 500฿/чел, поле `is_giftable`).
- **Знания/места** → таблица `knowledge` (КотЭ сам добавляет на модерацию: `source='kote_learned', active=false`).
- Выключить позицию везде разом → `active=false`.

## Слой данных сайта — `js/catalog.js`
Подключить на странице: `<script src="js/catalog.js"></script>` и использовать:
```js
const tours = await Catalog.tours('phuket');         // активные туры Пхукета
const sea   = await Catalog.toursByCategory('phuket','Морские');
const pkgs  = await Catalog.packages('phuket');      // наборы
const t     = await Catalog.tour('ph-sup');          // один тур
Catalog.rub(t.price_adult);                          // баты → рубли
```
anon-ключ публичный, RLS пускает только чтение активного контента — безопасно.

## TODO (следующий шаг — фронтенд сайта)
Заменить статические карточки туров в `index.html`/`tours/*.html` на рендер из `Catalog.tours()`.
После этого правка в Supabase моментально отражается на сайте без правки HTML.
