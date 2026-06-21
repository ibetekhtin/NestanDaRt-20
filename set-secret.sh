#!/usr/bin/env bash
# Безопасно записать секрет в /opt/kote/.env — без засветки в экране/истории.
# Использование: bash set-secret.sh VARNAME [service_для_пересоздания]
set -euo pipefail
ENVFILE=/opt/kote/.env
VAR="${1:?Укажи имя переменной, напр.: bash set-secret.sh AITUNNEL_API_KEY kote-backend}"
SVC="${2:-}"
touch "$ENVFILE"; chmod 600 "$ENVFILE"
printf "Вставь значение для %s и нажми Enter (ввод СКРЫТ): " "$VAR"
read -rs VALUE; echo
[ -z "${VALUE:-}" ] && { echo "Пусто — отмена."; exit 1; }
# заменяем строку (или добавляем), без проблем со спецсимволами
grep -v "^${VAR}=" "$ENVFILE" > "$ENVFILE.tmp" || true
printf "%s=%s\n" "$VAR" "$VALUE" >> "$ENVFILE.tmp"
mv "$ENVFILE.tmp" "$ENVFILE"; chmod 600 "$ENVFILE"
echo "OK: ${VAR} записан (длина ${#VALUE} симв.)"
unset VALUE
if [ -n "$SVC" ]; then
  echo "Пересоздаю контейнер $SVC, чтобы подхватил ключ..."
  cd /opt/kote && docker compose up -d "$SVC" 2>&1 | tail -3
fi
