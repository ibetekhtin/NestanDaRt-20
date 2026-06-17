# SUPABASE

Проект: **NON-STANDART** (`cmmdrhususjuadqzyssc`)

## Переменные окружения

```
VITE_SUPABASE_URL=https://cmmdrhususjuadqzyssc.supabase.co
VITE_SUPABASE_ANON_KEY=<anon key из Dashboard → Settings → API>
```

Где лежат:
- `hq/.env` — для HQ-панели (в gitignore, не коммитится)
- n8n Credentials — для воркфлоу КотЭ

## Таблицы

| Таблица | Описание |
|---------|---------|
| `tours` | Туры по городам (Пхукет, Паттайя) |
| `clients` | Клиенты + воронка (`stage`) |
| `bookings` | Заявки на туры |
| `payments` | Платежи YooKassa |
| `reviews` | Отзывы |
| `partners` | Партнёры-поставщики |
| `knowledge` | База знаний КотЭ (места, пляжи, лайфхаки) |
| `client_memory` | Память КотЭ о клиенте |
| `conversations` | История диалогов с КотЭ |
| `action_history` | Лог действий |
| `content_plan` | Контент-план («Контент-завод» в HQ) |

Актуальная схема: [`platform/supabase/schema.sql`](../supabase/schema.sql)

## Безопасность (RLS)

- **anon** (сайт, бот): читает туры/знания/отзывы; создаёт заявки и лиды со статусом «Новый». Персональные данные не читает.
- **authenticated** (HQ): полный доступ только если email в JWT = админский (`public.is_admin()`). Просто зарегистрироваться недостаточно.
- **КотЭ / n8n**: через SECURITY DEFINER RPC — `get_kote_context`, `upsert_client_memory`, `update_client_stage`.

## Пример запроса

```js
import { supabase } from './supabase.js';

const { data } = await supabase
  .from('tours')
  .select('*')
  .eq('city', 'Пхукет')
  .order('sort_order');
```
