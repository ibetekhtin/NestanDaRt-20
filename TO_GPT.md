орий ги# ПРОМПТ ДЛЯ GPT — KOTЭ SYSTEM

## КТО МЫ
Проект **«Нестандартный Отдых / KOTЭ SYSTEM»** — Telegram-бот + AI + Supabase + n8n платформа для автоматизации туристического бизнеса на нескольких рынках (Пхукет, Паттайя, Бали, Дубай).

**Основатель:** Солоплейер (мистер Бетехтин)  
**Текущая дата:** 10 июня 2026  
**Git:** `12b4a83` — v2.0.0, 50 файлов  
**VPS (Hetzner):**
- IPv4: `178.105.195.178`
- IPv6: `2a01:4f8:c015:8bed::/64`
- User: `root`
- Password: `cwwM7ERpPRJrqjHJsmNF`
- Старый IP: `178.105.29.120` (там n8n на :5678, но это другой сервер)

## ПРОБЛЕМА
SSH к VPS **не работает** (operation timed out). Сервер только что создан в Hetzner Cloud.
- Ping 100% loss
- SSH порт 22 не отвечает
- IPv6 тоже timeout

**Вероятные причины:**
1. Сервер выключен — нужно Power ON через https://console.hetzner.cloud
2. Firewall блокирует порт 22 — нужно добавить SSH rule
3. Ещё инициализируется

## ПРОЕКТ (ГОТОВ К ДЕПЛОЮ)

```
/
├── bot/               Node.js + Telegraf (6 файлов)
├── app/backend/       Python + FastAPI (11 файлов, 8 routers, 14 endpoints)
├── supabase/          SQL schema + migration (13 таблиц, 6 RPC, RLS, triggers)
├── n8n/flows/         8 JSON workflows
├── deploy/            6 скриптов (setup, deploy, backup, healthcheck, nginx, systemd)
├── docs/              9 файлов документации
├── ai/                kote_prompt.txt
├── website/           index.html
├── docker-compose.yml 3 сервиса (bot, backend, n8n)
├── Makefile
└── PROJECT.md         Roadmap до 2030
```

**Технологии:**
| Компонент | Технология |
|-----------|-----------|
| Bot | Node.js 20 + Telegraf 4.16 |
| Backend | Python 3.12 + FastAPI |
| AI | Gemini 2.0 Flash |
| Database | Supabase PostgreSQL 15 |
| Automation | n8n |
| Mobile | Expo / React Native |
| Deploy | Docker Compose |
| VPS | Hetzner CPX21 |

**Supabase:** https://asurrubnbvetkvnskcdu.supabase.co  
**Bot:** @phuket_nestandart_bot (Telegram)

## СЦЕНАРИЙ ДЕПЛОЯ
1. https://console.hetzner.cloud → включить сервер
2. Firewall → SSH порт 22
3. `bash deploy.sh "cwwM7ERpPRJrqjHJsmNF"`
4. На VPS: `cd /opt/kote && nano .env && docker compose up -d`
5. Настроить n8n: импорт workflow из n8n/flows/
6. Тест бота @phuket_nestandart_bot

## РОУДМАП
- 2026 H2 — BASE: $500 MRR, 50 клиентов
- 2027 — GROWTH: $10K MRR, 10 рынков
- 2028 — EMPIRE: $80K MRR, 30 рынков
- 2029 — WORLD TOUR: $500K MRR, 80 рынков
- 2030 — КОРОЛЬ МИРА: $2M MRR, 150+ стран

**Ключевые даты:**
- ✅ 9 июня 2026 — VPS куплен
- ✅ Все 50 файлов созданы и проверены
- ❌ SSH не подключается — главная проблема