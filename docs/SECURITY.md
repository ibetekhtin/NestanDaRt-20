# SECURITY — модель безопасности Nestandart

> Канон с 2026-07-02 (после lockdown-миграции). При изменении модели — обновить этот файл, README §Безопасность и CLAUDE.md §Безопасность БД.

## Слои

```
Браузер (сайт/PWA/БАЗА)          Сервер (backend/n8n)
  anon-ключ: только SELECT         service_role: полный доступ
  витрины (tours/packages/          ко всем RPC и таблицам
  knowledge/markets)                      │
        │                                 ▼
        ▼                        RPC SECURITY DEFINER
   RLS-политики                  + sha256-гейт KOTE_SECRET
                                 (второй рубеж внутри функции)
```

## Правила

1. **RPC**: все бизнес-функции — `REVOKE EXECUTE FROM PUBLIC, anon, authenticated; GRANT TO service_role`. Новую функцию создавать сразу с этим. `ALTER DEFAULT PRIVILEGES` уже отзывает EXECUTE у новых функций по умолчанию. Исключение — `is_admin()` (нужна RLS-политикам).
2. **Ключи**: `SUPABASE_SERVICE_KEY` живёт только в `.env` (gitignore) и env контейнеров. В n8n-нодах — только выражение `{{ $env.SUPABASE_SERVICE_KEY }}`, никогда литерал. anon/publishable-ключ допустим только в клиентском коде (catalog.js, app.html, baza).
3. **Backend**: приватные эндпоинты — `Depends(require_secret)` (X-Kote-Secret, fail-closed, `hmac.compare_digest`). Тексты ошибок БД клиенту не отдаются.
4. **nginx**: 8000/5678 слушают только 127.0.0.1; rate-limit зоны `api`/`leads`; security-заголовки на всех vhost.
5. **Платежи**: вебхук ЮKassa не доверяет payload — статус перепроверяется у API, сумма/валюта сверяются с нашей записью; неизвестные payment_id игнорируются.
6. **RLS**: включён на всех таблицах. `authenticated` видит свои данные (`auth.jwt()->>'email'`), админ — через `is_admin()`.

## Если утёк ключ

1. Supabase Dashboard → Settings → API → ротация ключа.
2. Обновить `.env` → `docker compose up -d` (backend и n8n подхватят из env).
3. Проверить: `curl -s http://127.0.0.1:8000/health`, исполнения n8n, git-историю на предмет закоммиченного ключа.

## Известные ручные настройки

- **Leaked-password protection** (Auth → Settings) — включается в дашборде, MCP-доступа нет.
