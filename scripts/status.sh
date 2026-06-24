#!/usr/bin/env bash
# NestanDaRt-20 — сходятся ли GitHub ↔ VPS ↔ локаль + здоровье контейнеров (read-only)
set -uo pipefail
VPS="${NESTANDART_VPS:-root@77.42.93.187}"

echo "═══════════ NestanDaRt-20 status ═══════════"
GH=$(git ls-remote origin main 2>/dev/null | cut -c1-7)
LOC=$(git rev-parse --short HEAD 2>/dev/null)
VPSH=$(ssh "$VPS" 'cd /opt/NestanDaRt-20 && git rev-parse --short HEAD' 2>/dev/null)
printf "GitHub origin/main : %s\n" "${GH:-?}"
printf "Local  HEAD        : %s\n" "${LOC:-?}"
printf "VPS    HEAD        : %s\n" "${VPSH:-?}"
if [ -n "$GH" ] && [ "$GH" = "$LOC" ] && [ "$GH" = "$VPSH" ]; then
  echo "✅ всё сведено на $GH"
else
  echo "⚠️  расхождение — см. SHA выше"
fi
echo "─────────── контейнеры ───────────"
ssh "$VPS" 'cd /opt/NestanDaRt-20 && docker compose ps --format "{{.Name}}\t{{.Status}}"' 2>/dev/null || echo "(не удалось получить статус контейнеров)"
