# 🚀 Команды для VPS (77.42.93.187)

## 1. SSL сертификат (пока не настроен)
```bash
ssh root@77.42.93.187
sudo certbot --nginx -d nestandart.online -d www.nestandart.online
# После подтверждения certbot сам настроит HTTPS редирект
```

## 2. Crontab — автоматические бэкапы и healthcheck
```bash
ssh root@77.42.93.187

# Редактируем crontab
crontab -e

# Добавить строки:
0 3 * * * /opt/kote/deploy/backup-supabase.sh >> /var/log/kote-backup.log 2>&1
*/5 * * * * /opt/kote/deploy/healthcheck.sh >> /var/log/kote-health.log 2>&1

# Проверить:
crontab -l
```

## 3. Развернуть FastAPI backend (если ещё не запущен)
```bash
ssh root@77.42.93.187

# Текущий docker-compose уже содержит kote-backend
# Просто перезапускаем:
cd /opt/kote
docker compose up -d kote-backend

# Проверить:
docker logs kote-backend
docker compose ps
```

## 4. Применить миграцию Паттайя
```bash
# В Supabase SQL Editor (https://supabase.com/dashboard/project/cmmdrhususjuadqzyssc/editor) выполнить:
\i supabase/migrations/006_enable_pattaya.sql
```

## 5. Туры без фото (нужно скачать и загрузить)
```bash
# Найти все tours.html без image_url в базе:
# SELECT slug FROM tours WHERE image_url IS NULL;

# Потом для каждого:
# 1. Скачать фото из открытых источников (Unsplash, Pexels)
# 2. Загрузить в Supabase Storage или указать внешний URL
# 3. Обновить image_url в таблице tours

# Быстрый fix — placeholder (не влияет на конверсию):
# UPDATE tours SET image_url = 'https://nestandart.online/assets/hero.png' WHERE image_url IS NULL;
```

## 6. Проверить, что всё работает
```bash
# API
curl https://nestandart.online/api/v1/tours
curl https://nestandart.online/api/v1/markets

# Site
curl -I https://nestandart.online

# Docker
docker compose ps

# Nginx
sudo nginx -t && sudo systemctl reload nginx