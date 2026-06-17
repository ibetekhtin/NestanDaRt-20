# STACK

## Нестандартный Отдых — технологический стек

---

## Frontend

| Слой | Технология |
|------|-----------|
| Сайт (публичный) | HTML + CSS + Vanilla JS |
| Деплой сайта | Vercel |
| HQ (внутренняя панель) | React + Vite |
| Мобильное приложение | React Native (planned) |

## Backend / Инфраструктура

| Слой | Технология |
|------|-----------|
| База данных | Supabase (PostgreSQL) |
| Auth | Supabase Auth |
| Edge functions | Supabase Edge Functions / Cloudflare Workers |
| Автоматизация | n8n |
| AI Engine | Google Gemini via n8n |
| Telegram Bot | n8n + Telegram Bot API |
| Хостинг Workers | Cloudflare Workers (`wrangler.toml`) |

## Shared

| Слой | Файл |
|------|------|
| Конфиг рынков | `shared/markets.js` |
| Бренд-константы | `shared/brand.js` |
| Схема БД | `platform/supabase/schema.sql` |

## Принцип

Supabase — единственный источник данных.  
Все сервисы (сайт, бот, HQ, мобилка) читают из одной базы.  
Новый рынок = новая строка в таблице `markets`.
