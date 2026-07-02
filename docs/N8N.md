# n8n — автоматизации КотЭ

> Актуализировано 2026-07-02. Живые воркфлоу: **n8n/live/** (10 шт., экспортированы без секретов).

## Воркфлоу (все active, error-workflow: error-monitor)

| Файл | Что делает | Триггер |
|---|---|---|
| main-bot-ai-agent | Бот КотЭ: контекст → KOTE_SOUL → Gemini → ответ; интент → рукава | Telegram webhook |
| booking-flow | Рукав «Бронь»: лид в CRM → pay/create → ссылка клиенту; при ошибке — алерт менеджеру | executeWorkflow |
| memory-stage | Рукав «Память/Стадия»: upsert память + стадия клиента | executeWorkflow |
| new-leads-notify | Уведомление менеджеру о новых лидах | cron 5 мин |
| booking-status-notify | Смена статуса брони → сообщение клиенту | cron 5 мин |
| abandoned-nudge | Дожим зависших броней | cron ежедневно |
| tour-reminder | Напоминание о туре за день | cron |
| review-request | Запрос отзыва после тура | cron |
| pay-reconcile | Сверка платежей (внутренний kote-backend:8000) | cron |
| error-monitor | Алерт менеджеру при падении любого флоу | error trigger |

## Правила
- Supabase-ключ в нодах — ТОЛЬКО `{{ $env.SUPABASE_SERVICE_KEY }}` (env контейнера). Литералы ключей запрещены (docs/SECURITY.md).
- HTTP-ноды: timeout 15с (AI 60с); критические записи — retryOnFail; Telegram-рассылки в циклах — onError: continue.
- Личность бота = **KOTE_SOUL** в ноде «✍️ Собрать промпт» (main-bot-ai-agent). Только Пхукет.

## Как редактировать (n8n исполняет ВЕРСИОНИРОВАННЫЙ снимок!)
```bash
docker exec kote-n8n n8n export:workflow --all --separate --output=/tmp/wf/
# правка JSON → docker cp → import:workflow → publish:workflow --id=<id> → docker restart kote-n8n (×2)
```
После правки — обновить экспорт в n8n/live/ (без секретов!).
