# 🎯 ПОШАГОВЫЙ ПЛАН — СЛЕДУЮЩИЕ ДЕЙСТВИЯ

## ✅ УЖЕ ГОТОВО (запушено в main)
- [x] Аудит всей системы
- [x] Исправления P0-P1 (security, booking-flow, markets)
- [x] VPS_SETUP.md с инструкциями
- [x] Migration 006 для Паттайи
- [x] Nginx конфиг → nestandart.online

## 🔴 СЕЙЧАС (10-15 минут)

### 1. SSL сертификат на VPS
```bash
ssh root@77.42.93.187
sudo certbot --nginx -d nestandart.online -d www.nestandart.online
# Следуйте инструкциям, введите email, согласие с Terms
```

### 2. Миграция Паттайя (включить рынок)
Откройте в браузере: https://supabase.com/dashboard/project/cmmdrhususjuadqzyssc/editor

SQL Editor → вставьте:
```sql
-- Включить Паттайю
update markets set active = true where slug = 'pattaya';

-- Связать туры с market_id
do $$ begin
  if exists (select 1 from information_schema.columns where table_name='tours' and column_name='market_id') then
    update tours t
    set market_id = m.id
    from markets m
    where t.city = m.name and m.slug = 'pattaya' and t.market_id is null;
  end if;
end $$;
```

### 3. Кrontab на VPS
```bash
ssh root@77.42.93.187
crontab -e
# Добавьте:
0 3 * * * /opt/kote/deploy/backup-supabase.sh >> /var/log/kote-backup.log 2>&1
*/5 * * * * /opt/kote/deploy/healthcheck.sh >> /var/log/kote-health.log 2>&1
# Ctrl+O, Enter, Ctrl+X
```

## 🟡 БЛИЖАЙШИЕ ЧАСЫ (1-2 часа)

### 4. Поставить placeholder для 17 туров без фото
В Supabase SQL Editor:
```sql
UPDATE tours 
SET image_url = 'https://images.unsplash.com/photo-1552733407-5d5c46c3bb3b?w=800' 
WHERE image_url IS NULL OR image_url = '';
```
Это временное изображение пляжа. После замените на реальные фото туров.

### 5. Список туров без фото (для скачивания)
```sql
SELECT slug, title, city FROM tours WHERE image_url IS NULL OR image_url = '';
```
Затем для каждого тура:
1. Найдите фото на Unsplash (https://unsplash.com/s/photos/phuket-tours)
2. Скачайте или используйте прямой URL
3. Обновите в Supabase:
```sql
UPDATE tours SET image_url = 'ВАШ_URL' WHERE slug = 'tur-slug';
```

## 🟢 БЛИЖАЙШИЕ ДНИ (1-3 дня)

### 6. Подключить YooKassa (онлайн-оплата)
Документация: https://yookassa.ru/developers

Нужно:
1. Зарегистрировать юрлицо/ИП в YooKassa
2. Получить Shop ID и Secret Key
3. Добавить в Supabase таблицу `payment_methods` или в .env
4. Создать webhook на `/api/v1/webhook/yookassa` в backend
5. Протестировать тестовый платёж

**Эффект:** конверсия из заявки в оплату вырастет с 8% до 30-50%.

### 7. Проверить работу бота
```bash
# На VPS проверить, что n8n Cloud workflow активен
# Или переключиться на локальный n8n:
# docker compose --profile bot up -d kote-bot
```

### 8. Проверить API
```bash
curl https://nestandart.online/api/v1/tours
curl https://nestandart.online/api/v1/markets
# Должны вернуться JSON-массивы
```

## 📋 КОНТРОЛЬНЫЙ СПИСОК

- [ ] SSL cert активирован (https://nestandart.online открывается с замком)
- [ ] Crontab добавлен (crontab -l показывает 2 строки)
- [ ] Паттайя включена (в админке появляется)
- [ ] Фото туров стоят (placeholders или реальные)
- [ ] API отвечает (curl /api/v1/tours возвращает данные)
- [ ] YooKassa подключена (тестовый платёж проходит)

---

## 📞 КОГДА ЗАСТРЯЛИ

Если на каком-то шаге ошибка:
1. Скопируйте текст ошибки
2. Сделайте скриншот
3. Напишите мне — разберёмся

Следующий звонок: после выполнения п.1-3 (SSL + Паттайя + Crontab).