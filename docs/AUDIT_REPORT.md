# AUDIT_REPORT.md — Аудит проекта «Нестандартный Отдых»
> Дата: 2026-06-20 · Аудитор: AI-агент (Cline)

---

## 📊 Сводка

| Компонент | Статус | Оценка |
|-----------|--------|--------|
| Docker | ✅ Работает | Отлично |
| FastAPI Backend | ✅ Работает | Отлично |
| Nginx + SSL | ✅ Работает | Отлично |
| Supabase | ✅ Работает | Отлично |
| n8n | ✅ Работает | Хорошо |
| Telegram Bot | ✅ В n8n Cloud | Норма |
| AI Fallback Chain | ✅ Обновлён | Отлично |
| Бэкапы | ⚠️ Работают частично | Требует внимания |
| Безопасность | ✅ Усилено (2026-06-19) | Хорошо |

---

## 🐳 Docker

### Контейнеры

| Контейнер | Образ | Статус | Порты | RAM |
|-----------|-------|--------|-------|-----|
| kote-backend | kote-kote-backend:latest | ✅ Up (healthy) | 127.0.0.1:8000 | ~60 MiB |
| kote-n8n | n8nio/n8n:2.25.7 | ✅ Up (healthy) | 127.0.0.1:5678 | ~225 MiB |
| kote-bot | (отключён, profiles: bot) | ⏸️ Выключен | — | — |

### Что работает
- Оба контейнера запускаются автоматически (`unless-stopped`)
- Healthcheck настроен для обоих
- Лимиты памяти заданы (512M backend, 1.5G n8n)
- Логи ограничены (10m × 3 файла)

### Что можно упростить
- `kote-bot` контейнер можно удалить из compose — бот живёт в n8n Cloud
- Версия n8n зафиксирована на `2.25.7` — хорошо, не `latest`

### Рекомендации
- Обновить n8n до свежей стабильной версии (2.25.7 → актуальная)
- Рассмотреть обновление образа бэкенда регулярно

---

## 🌐 Nginx + SSL

### Домены

| Домен | SSL | Назначение |
|-------|-----|-----------|
| nestandart.online | ✅ Let's Encrypt | Главный сайт + API |
| www.nestandart.online | ✅ | → redirect на без www |
| n8n.nestandart.online | ✅ Let's Encrypt | n8n редактор |
| app.nestandart.online | ✅ | PWA / Mini App |
| nestandart-phuket.ru | ✅ | → redirect на nestandart.online/phuket |

### Что работает
- TLS 1.2 + 1.3 (старые версии отключены)
- Security headers (HSTS, X-Frame-Options, CSP)
- Rate limiting (leads: 5r/m, API: 20r/m)
- Блокировка .env, .git, .sql файлов по URI
- server_tokens off

### Что отлично
- fail2ban настроен с polling backend для nginx-логов
- WordPress-сканы блокируются (return 444)
- CORS whitelist для 3 доменов

---

## 🤖 Telegram Bot (КотЭ)

### Статус
- Бот @phuket_nestandart_bot работает через **n8n Cloud**
- Локальный Python-бот (`kote-bot`) отключён
- Конфликтов нет

### Архитектура
```
Telegram → n8n trigger → upsert_lead() → get_kote_context() → AI → ответ → сохранить
```

### Что работает
- 4 активных workflow в n8n
- Память клиента (client_memory)
- База знаний (84+ записи)
- Уведомления менеджеру

---

## 🗄️ Supabase

### Статус: ✅ Работает

| Таблица | Назначение |
|---------|-----------|
| markets | 2 рынка (Пхукет, Паттайя) |
| tours | 33 тура |
| clients | Растёт |
| bookings | Растёт |
| knowledge | 84+ записи |
| conversations | История диалогов |
| client_memory | Память о клиентах |

### RPC-функции
- `app_upsert_lead()` — создание/обновление клиентов и броней
- `get_kote_context()` — контекст для AI (туры + знания + память)
- `get_bookings_by_phone()` — брони по телефону

### Безопасность
- RLS настроен (anon → чтение, authenticated → полный доступ)
- SECURITY DEFINER для RPC КотЭ

---

## 🤖 AI Fallback Chain

### Текущая конфигурация (обновлено 2026-06-20)

```
AITUNNEL (gemini-2.5-flash)     ← основной (российский, 600₽)
    ↓ если упал
Groq (llama-3.3-70b-versatile)  ← запасной (бесплатный, ultra-fast)
    ↓ если упал
OpenRouter (gemini-2.5-flash-lite) ← третий (международный)
    ↓ если упал
Gemini (gemini-2.0-flash)       ← аварийный (бесплатный, Google)
    ↓ если все упали
"🐾 Секунду, я немного перегрушен..."
```

### Файлы провайдеров

| Файл | Назначение |
|------|-----------|
| providers/aitunnel.py | НОВЫЙ — российский агрегатор (216+ моделей) |
| providers/groq.py | Groq — ultra-fast inference |
| providers/openrouter.py | OpenRouter — международный агрегатор |
| providers/gemini.py | Gemini — прямой API Google |
| providers/ai.py | Роутер с fallback chain |

### Что работает
- 4 независимых провайдера
- Автоматический fallback при ошибке
- Логирование latency каждого вызова
- Веб-поиск через OpenRouter (:online)

---

## 💾 Бэкапы

### Что работает
- cron 03:00 — JSON-дамп 12 таблиц Supabase через REST API
- cron 03:30 — tar.gz конфигов nginx + /opt/kote
- cron */5 мин — healthcheck + авто-рестарт

### Что НЕ работает
- `pg_dump` (полный SQL-дамп) — есть SUPABASE_DB_URL, но скрипт не настроен
- Offsite backup — всё на том же VPS (single point of failure)

### Рекомендации
- Настроить pg_dump с SUPABASE_DB_URL
- Добавить S3/Cloudflare R2 для offsite backup

---

## 🔒 Безопасность

### Что исправлено (2026-06-19)
- SSH: только ключи, запрет паролей, max 3 попытки
- TLS: только 1.2 + 1.3
- Security headers: полный набор
- Rate limiting: настроен
- fail2ban: polling backend для nginx
- Бэкапы: права 700/600
- Мёртвый код: вычищен

### Риски
- Порты 54112/54114 могут быть открыты при VS Code Remote сессии
- UptimeRobot не настроен

---

## 📝 Что лишнее

| Элемент | Статус | Рекомендация |
|---------|--------|-------------|
| kote-bot в docker-compose | profiles: bot | Можно удалить (бот в n8n) |
| ANTHROPIC_API_KEY в .env | Пустой | Убрать или заполнить |
| CLAUDE_MODEL в .env | claude-sonnet-4-6 | Не используется в production |
| daily-report.json в n8n/flows | Невалидный | Не импортировать |
| nestandart-api (PM2) | Старый Node.js API | Работает, но можно мигрировать в FastAPI |

---

## ✅ Что можно упростить

1. **Удалить kote-bot из compose** — бот живёт в n8n, контейнер не нужен
2. **Убрать ANTHROPIC_API_KEY** — не используется
3. **Кonsolidировать API** — nestandart-api (PM2) можно перенести в FastAPI
4. **Настроить pg_dump** — SUPABASE_DB_URL уже есть в .env
5. **Добавить UptimeRobot** — бесплатный мониторинг

---

*Аудит проведён 2026-06-20. Следующий аудит рекомендован через 30 дней.*