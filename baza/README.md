# БАЗА (Штаб) — админ-панель Nestandart

React + Vite. Живёт на **baza.nestandart.online** (nginx → статика `baza-dist/`).

## Что внутри
- DashboardView — КПТ (Количество Проданных Туров) + KPI
- WikiView — база знаний (live Supabase)
- KoteView — диалоги КотЭ
- ReferralsView — 3-уровневые рефералы

## Данные
Supabase JS-клиент под **anon-ключом + Supabase Auth** (magic link). Доступ к данным — через RLS
(админ-политики `is_admin()`); RPC панель не вызывает. Env: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`.

## Разработка и деплой
```bash
cd baza && npm install && npm run dev     # локально
npm run build                             # → dist/
cp -r dist/* ../baza-dist/                # baza-dist/ трекается в git и деплоится git pull'ом
```
