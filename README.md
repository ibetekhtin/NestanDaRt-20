# Нестандартный Отдых® — сайт + Telegram Mini App

Brutalist editorial дизайн, глитч-эффекты, параллакс. Чёрный (#0A0A0A) с акцентами кислотно-салатовый (#C0FF00) и кислотно-оранжевый (#FF6B00). Тот же HTML работает как обычный сайт и как Telegram Web App.

## Деплой

Прод — Vercel: https://nestandart-phuket.ru
Конфигурация — `vercel.json` (cache headers + security + редиректы www→naked и vercel.app→nestandart-phuket.ru).

### Деплой

Push в `main` — Vercel разворачивает автоматически. Превью на каждый PR.

## 📁 Структура

```
.
├── index.html              ← Главная, 20 туров, Schema.org, FAQ
├── roadmap.html            ← Внутренний трекер до 2030 (noindex)
├── 404.html
├── vercel.json             ← Headers + редиректы
├── sitemap.xml             ← 12 URL
├── robots.txt
├── og-image.png
├── package.json            ← @vercel/analytics
├── css/
│   ├── style.css           ← Глитч + параллакс + brutalist
│   └── blog.css            ← Стили статей
├── js/
│   └── app.js              ← Загрузчик, city-chooser, фильтры, drag, modal, TG Mini App
├── blog/                   ← 10 SEO-статей
└── tours/
    └── mototour.html       ← Лендинг авторского мототура
```

## 🎨 20 услуг в каталоге

Категории фильтра: `sea` / `land` / `signature` / `shows`

Морские: Джеймс Бонд, Пхи-Пхи+Бамбу, Пхи-Пхи+Кхай, Симиланы.
Сухопутные: Као Лак, Као Сок (1д/2д), Путь Аватара, Рафтинг+Слоны+ATV, Прыжок Гиббона.
Вечерние шоу: Фаер-шоу, Свадьбы, Фотосессии, Организация мероприятий, Аренда байков/машин, Недвижимость.
Авторские (★): МотоТур, АвтоТур, Аренда яхты, VIP-сопровождение.

## 💰 Цены (источник правды)

Цены продублированы в HTML FAQ + Schema FAQPage + Schema OfferCatalog. **При любом изменении синхронизируй все три места**:

- Дневные морские экскурсии (Джеймс Бонд, Пхи-Пхи, Симиланы): **2 500 – 4 500 ₽** с человека
- Активные туры (рафтинг+ATV, Прыжок Гиббона): **3 600 – 4 200 ₽**
- МотоТур авторский: **от 7 500 ₽**
- VIP-сопровождение: **от 12 000 ₽/день**
- АвтоТур: **от 15 000 ₽**
- Аренда яхты с экипажем: **от 25 000 ₽**

## 🤖 Telegram Mini App

`index.html` детектит запуск внутри Telegram (`window.Telegram.WebApp.initData`) и переключается в режим Mini App:

- `tg.expand()` — на весь экран
- `MainButton` — нативная зелёная кнопка «Написать в Telegram»
- `BackButton` — появляется при скролле >400px, ведёт наверх
- `HapticFeedback` — на тапах CTA и карточек
- `setHeaderColor` / `setBackgroundColor` — #0A0A0A
- `disableVerticalSwipes` — чтобы не закрывался на скролле

CSS-таргетинг внутри TG: `body.tg-app { ... }`.

## ✨ Эффекты

- Загрузочный экран «НЕСТАНДАРТ» с глитч-аурой и счётчиком
- Drag-каталог 20 туров, прогресс-бар, инерция, скролл колесом
- 5 фильтров категорий
- Ротатор городов Пхукет/Паттайя (CSS variable color theming)
- 2 бегущие строки (салатовая сверху, оранжевая снизу)
- Glitch на hero, hover-glitch на заголовках секций
- Mouse-параллакс на десктопе (отключён на mobile + `prefers-reduced-motion`)
- Scroll reveal через IntersectionObserver
- Модалка бронирования при клике на карточку

## 🔍 SEO

- JSON-LD: Organization+LocalBusiness, WebSite+WebPage, ItemList (20 туров), FAQPage, OfferCatalog, BreadcrumbList
- Полная мета (title, description, keywords, OG, Twitter, geo, canonical, hreflang)
- sitemap.xml (12 URL), robots.txt с Host для Яндекса
- 10 SEO-статей под популярные запросы
- 1 лендинг тура (MotoTour) — стартовая модель, под расширение

### Следующие шаги по SEO

- Подключить Google Search Console + Яндекс.Вебмастер к домену `nestandart-phuket.ru`
- Отправить sitemap.xml
- Расширить tours/ ещё 19 страницами под каждый тур (отдельные SEO-запросы)

## 🗺️ Roadmap

Внутренний трекер до 30.10.2030: [`/roadmap.html`](./roadmap.html). 9 фаз, 65+ задач, прогресс в localStorage. Скрыт от индексации.

## ➕ Изменить цвета

`css/style.css` → `:root`:
```css
--bg:           #0A0A0A;
--acid-green:   #C0FF00;
--acid-orange:  #FF6B00;
```

---

©2026 Нестандартный Отдых® · Phuket / Pattaya
