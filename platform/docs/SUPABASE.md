# SUPABASE

## Настройка

1. Создать проект на [supabase.com](https://supabase.com)
2. Запустить схему: `platform/supabase/schema.sql`
3. Получить ключи: Settings → API

## Переменные окружения

```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

Добавить в:
- `hq/.env` — для HQ-панели
- Vercel Dashboard → Environment Variables — для сайта (если нужен)
- n8n Credentials — для автоматизаций

## Таблицы

| Таблица | Описание |
|---------|---------|
| `markets` | Все рынки (Пхукет, Паттайя, Бали, Дубай) |
| `clients` | Клиенты по рынкам |
| `tours` | Туры по рынкам |
| `bookings` | Заявки на туры |
| `transactions` | Финансовые операции |
| `content_plan` | Контент-план |
| `client_memory` | Память КотЭ о клиенте |
| `ai_interactions` | История диалогов с КотЭ |

## Supabase клиент

```js
import { supabase, isSupabaseConfigured } from './supabase.js';

if (isSupabaseConfigured) {
  const { data } = await supabase
    .from('clients')
    .select('*')
    .eq('market_id', 'phuket');
}
```
