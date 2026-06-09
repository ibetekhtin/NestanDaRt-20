# План рефакторинга — Нестандартный Отдых / КотЭ

## Аудит (что было не так)

| # | Было | Стало |
|---|------|-------|
| 1 | `n8n/flows/payment.json` начинался с мусора `ы{` — сломанный JSON | Удалён, объединён с `booking-confirm` |
| 2 | `n8n/flows/booking-confirm.json` начинался с `всттавить везде{` | Перезаписан, чистый JSON |
| 3 | `reminder.json` искал брони на `today`, а нужен `tomorrow` | Добавлен Code-узел, считает завтра |
| 4 | `bot/index.js` хардкодил emoji для phuket/pattaya/bali | `marketEmoji(name)` берёт первый emoji-символ из названия |
| 5 | Дублирование рендера услуг в `/services` и `type:` | Одна функция `renderServices` |
| 6 | AI получал `market = 'unknown'` | Без выбора рынка — просим `/start`, в БД не пишем мусор |
| 7 | `website/index.html` — `{{ SUPABASE_URL }}` без билда | Fallback `window.SITE_*` / `localStorage` / `prompt` |
| 8 | PLAN.md описывал уже решённые проблемы | Обновлён под реальность |

## Итог

- **n8n**: 5 → 4 flows (`payment` объединён в `booking-confirm`)
- **bot/index.js**: −30 строк дублирования, −1 хардкод
- **website**: работает локально без билда, чистый fallback
- **БД**: защищена от мусорных записей (`unknown`)

## Что осталось делать вручную владельцу

1. `cp .env.example .env` и заполнить ключи
2. `npm install`
3. Запустить `psql`/Supabase SQL editor → выполнить `supabase/schema.sql`
4. Импортировать 4 n8n flows из `n8n/flows/`
5. `npm run bot` — бот в Telegram
6. Открыть `website/index.html` — фронт

## Новые рынки

1. Добавить запись в `markets` (Supabase)
2. Добавить `services` с `market_id`
3. Никакого кода.

## Известные ограничения

- 1 n8n flow на "подтверждение" — если бизнес разделит "оплата" и "подтверждение менеджером" на 2 разных статуса (`paid` vs `confirmed`), нужно будет разделить обратно.
- `createPayment` в `supabase.js` есть, но бот её не вызывает — это делает n8n.
