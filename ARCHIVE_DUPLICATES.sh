#!/bin/bash
# Архивируем дублирующиеся и устаревшие MD файлы из корня
# Оставляем: README.md, CHANGELOG.md
# НЕ ТРОГАЕМ: app/, platform/supabase/, platform/bot/, nestandart-phuket/

mkdir -p archive-docs

mv МАСТЕР_ФАЙЛ_ПРОЕКТА.md archive-docs/ 2>/dev/null || true
mv ПОЛНАЯ_СВОДКА.md archive-docs/ 2>/dev/null || true
mv AUDIT_REPORT.md archive-docs/ 2>/dev/null || true
mv DEEP_AUDIT_2026-06-18.md archive-docs/ 2>/dev/null || true
mv FINAL_REPORT.md archive-docs/ 2>/dev/null || true
mv INFRASTRUCTURE.md archive-docs/ 2>/dev/null || true
mv MIGRATION_PLAN.md archive-docs/ 2>/dev/null || true
mv N8N_AUDIT.md archive-docs/ 2>/dev/null || true
mv PLAN.md archive-docs/ 2>/dev/null || true
mv PROJECT.md archive-docs/ 2>/dev/null || true
mv PROMPT.md archive-docs/ 2>/dev/null || true
mv ROADMAP.md archive-docs/ 2>/dev/null || true
mv TO_GPT.md archive-docs/ 2>/dev/null || true
mv CLAUDE.md archive-docs/ 2>/dev/null || true

# Повреждённые имена (UTF-8 escape)
mv "\321\203\321\202\320\260\320\275\320\276\320\262\320\273\320\265\320\275\320\275\321\213\320\265_\321\204\320\260\320\271\320\273\321\213" archive-docs/ 2>/dev/null || true

echo "Архивация завершена. Критические файлы сохранены."