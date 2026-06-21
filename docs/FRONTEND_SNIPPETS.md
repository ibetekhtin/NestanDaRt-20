# 🎨 FRONTEND_SNIPPETS — готовые блоки под вставку (сайт + приложение)

On-brand куски под текущую палитру (золото `#FFD25E`, циан `#5DC8F5`, розовый `#FF6B9D`,
тёмный `#1A1A2E`). Данные/бот уже готовы под них — формы просто шлют `app_upsert_lead`.
Размещай где удобно в `nestandart-phuket/index.html` и `platform/app.html`.

---

## 1. 🐾 КотЭ как УТП (item 3) — гордый блок «Вот он!»

```html
<section class="kote-utp" style="margin:48px auto;max-width:920px;padding:36px 28px;border-radius:28px;
  background:linear-gradient(135deg,#1A1A2E 0%,#0A2A4D 100%);color:#fff;text-align:center;
  box-shadow:0 20px 60px rgba(10,40,90,.35);position:relative;overflow:hidden">
  <div style="font-size:64px;line-height:1">🐾</div>
  <h2 style="font-size:30px;margin:10px 0 6px;font-weight:800">Познакомьтесь — это КотЭ</h2>
  <p style="font-size:17px;color:#FFD25E;font-weight:600;margin:0 0 14px">Ваш кот-консьерж на Пхукете 24/7</p>
  <p style="font-size:16px;line-height:1.6;max-width:640px;margin:0 auto 22px;color:#dfe7f5">
    Сначала поможет — потом подскажет. Спросите его о чём угодно: погода, виза, район, еда,
    байк, куда сходить. Он добрый, живой и всегда на связи. И да — он реально кот. 😺
  </p>
  <div style="display:flex;gap:12px;justify-content:center;flex-wrap:wrap">
    <a href="https://t.me/phuket_nestandart_bot" target="_blank" rel="noopener"
       style="background:#5DC8F5;color:#08243f;font-weight:800;padding:14px 28px;border-radius:14px;
       text-decoration:none;font-size:16px">💬 Спросить КотЭ</a>
    <a href="https://t.me/phuket_nestandart_bot" target="_blank" rel="noopener"
       style="background:transparent;color:#FFD25E;border:2px solid #FFD25E;font-weight:700;
       padding:12px 24px;border-radius:14px;text-decoration:none;font-size:16px">🏝 Подобрать экскурсию</a>
  </div>
</section>
```

> Поставь этот блок сразу под hero и продублируй мягким CTA внизу страницы. В приложении — на
> главном экране и в шапке (кнопка «Чат с КотЭ»). Это наша гордость — пусть её видят первой.

---

## 2. 👨‍👩‍👧 Состав группы в форме брони (item 1) — младенцы до 4 бесплатно

```html
<div class="pax" style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px">
  <label>Взрослых<input type="number" id="paxAdults" min="1" value="2" inputmode="numeric"></label>
  <label>Детей (4–11)<input type="number" id="paxChildren" min="0" value="0" inputmode="numeric"></label>
  <label>Малышей до 4<input type="number" id="paxInfants" min="0" value="0" inputmode="numeric">
    <small style="color:#1F8A8A">бесплатно 🐣</small></label>
</div>
```

И при отправке заявки (тот же `app_upsert_lead`, что уже используется):

```js
const adults  = +document.getElementById('paxAdults').value || 1;
const children= +document.getElementById('paxChildren').value || 0;
const infants = +document.getElementById('paxInfants').value || 0;

await fetch(`${SB_URL}/rest/v1/rpc/app_upsert_lead`, {
  method: 'POST',
  headers: { apikey: SB_ANON, Authorization: `Bearer ${SB_ANON}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    p_external_id: orderId,            // твой идемпотентный ключ
    p_source: 'Сайт',                  // или 'Приложение'
    p_name: name, p_phone: phone,
    p_tour_name: tourName, p_tour_slug: tourSlug,
    p_date_start: dateISO,             // 'YYYY-MM-DD'
    p_people: adults + children + infants,
    p_adults: adults, p_children: children, p_infants: infants,
    p_status: 'Новый'
  })
});
```

> Колонки `bookings.adults/children/infants` уже есть (миграции 011–012). Менеджер и Воронка
> видят состав сразу. Младенцы (груднички/малыши до 4) — бесплатно, отдельной строкой.

---

## 3. 🏍 Отдел экскурсий (item 6)

На сайте каталог уже есть (фильтры + карточки). Для приложения мирроль ту же сетку из
`tours` (по `market_id`), сортируй мототур (`slug=moto`) первым — это флагман и главный заработок.
Карточка: фото (`image_url`), `title`, цена `price_adult`฿ (+ `price_child`), кнопка «Забронировать»
и «Спросить КотЭ». Стиль — те же золото/циан/тёмный, скругления 20–28px, мягкие тени.
