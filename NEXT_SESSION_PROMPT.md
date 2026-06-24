# СЕССИОННЫЙ ПРОМПТ — NestanDaRt-20
> Это исполнительный промпт. Читай и выполняй без вопросов.

---

Ты — Claude Code в проекте **«Нестандартный Отдых»** (Пхукет/Паттайя/Вьетнам).
**Единственный KPI: КПТ = Количество Проданных Туров.**

Сначала прочитай `/Users/soloplayer/Desktop/NestanDaRt-20/CLAUDE.md` и `/Users/soloplayer/Desktop/NestanDaRt-20/MASTER_PROMPT.md` — там полный контекст архитектуры.

---

## ЗАДАЧА

Выполнить три фазы по порядку. Не пропускать фазы. Не задавать вопросов — принимать решения самостоятельно исходя из CLAUDE.md. Коммитить после каждой фазы.

---

## ФАЗА 1 — Пхукет: закрыть безопасность (не требует кода — инструкция для пользователя)

**KOTE_RPC_SECRET** сейчас пустой (`""`). Это значит `/ai/chat`, `/pay/create`, `/bookings` работают без авторизации — любой может их вызвать.

Перед тем как начать Фазу 2 — скажи пользователю:

> "Прежде чем продолжать: нужно защитить n8n. Зайди в n8n UI (n8n.nestandart.online), найди workflow КотЭ (`doCUKEZQpLQjDmxP`), открой HTTP-ноды **«🤖 Gemini»** и **«💳 Создать оплату»**, добавь в каждую заголовок:
> - Key: `X-Kote-Secret`
> - Value: `{{ $env.KOTE_SECRET }}`
>
> После этого добавь в `.env` на VPS:
> ```
> KOTE_RPC_SECRET=<придумай сильный секрет, совпадающий с KOTE_SECRET в n8n>
> ```
> И перезапусти backend: `docker compose up -d --force-recreate nestandart-backend`
>
> Когда сделаешь — скажи мне, я продолжу."

Жди подтверждения пользователя. После подтверждения (или если он скажет «пропустить») — переходи к Фазе 2.

---

## ФАЗА 2 — Паттайя: +53 тура в продажу

### 2а. PWA — убрать заглушку Паттайи

**Файл:** `/Users/soloplayer/Desktop/NestanDaRt-20/platform/app.html`

В нём сейчас:
- Блок `id="pattayaSoon"` со стилем `display:none` и текстом «Паттайя — скоро!»
- При выборе «Паттайя» в splash-экране показывается этот блок вместо реального каталога

**Что сделать:**
1. Найди логику splash-выбора города (функция `choose('pattaya')` или аналог)
2. Убедись что при выборе Паттайи загружаются реальные туры из Supabase с `market_id='pattaya'` — точно так же как для Пхукета
3. Убери заглушку `pattayaSoon` или сделай её невидимой навсегда
4. Инвалидируй кеш если нужно (ищи константу типа `nop_tours_v12` — увеличь версию)
5. Проверь что в PWA правильно отображается акцент-цвет Паттайи (`#FF5C1F`) и туры фильтруются по `market_id=pattaya`

### 2б. Посадочная страница /pattaya/

**Образец:** `/var/www/nestandart/phuket/index.html` (на VPS) или структура папки `nestandart.online/phuket/`

**Задача:** Создать файл `platform/pattaya/index.html` — полноценная SEO-страница для Паттайи.

Структура аналогична Пхукету:
- `<title>Экскурсии в Паттайе — Нестандартный Отдых®</title>`
- Мета-теги OG, description, keywords под Паттайю
- Hero-секция: «Паттайя — нестандартные экскурсии»
- Каталог туров (минимум 7 карточек как на главной для Пхукета) — можно статические с data-атрибутами или динамические из Supabase
- CTA кнопка «Написать КотЭ» → `https://t.me/phuket_nestandart_bot`
- CTA кнопка «Открыть каталог» → `https://app.nestandart.online/?city=pattaya`
- Стиль: акцент-цвет Паттайи `#FF5C1F`, структура как на главной
- Геомета: город Паттайя, Таиланд
- Sitemap: добавь `/pattaya/` в `sitemap.xml` если он есть

### 2в. База знаний КотЭ (Supabase)

Через Supabase MCP (инструмент `mcp__claude_ai_Supabase__execute_sql`) добавь 15 записей в таблицу `knowledge` для Паттайи.

Проект Supabase: `cmmdrhususjuadqzyssc`

Сначала проверь текущий constraint на поле `city`:
```sql
SELECT constraint_name, check_clause 
FROM information_schema.check_constraints 
WHERE constraint_name LIKE 'knowledge%';
```

Если 'Паттайя' уже в constraint — добавляй записи сразу. Если нет — сначала расширь constraint:
```sql
ALTER TABLE knowledge DROP CONSTRAINT IF EXISTS knowledge_city_check;
ALTER TABLE knowledge ADD CONSTRAINT knowledge_city_check
  CHECK (city IN ('Пхукет','Паттайя','Вьетнам','Общее'));
```

Затем добавь минимум 15 записей через `INSERT INTO knowledge`:
- Категории: `place`, `logistics`, `tips`, `faq`
- Примеры тем: лучшие пляжи Паттайи, сезонность, как добраться из Бангкока, шоу (Альказар, Нонг Ноч), острова (Ко Лан), ночная жизнь, семьи с детьми, безопасность, транспорт (байк, тук-тук), рестораны, отели районы
- `active = true`, `priority` 70-90, `city = 'Паттайя'`

### 2г. Промпт КотЭ — добавить блок Паттайи

**Файл:** `/Users/soloplayer/Desktop/NestanDaRt-20/platform/nestandart-20/prompt.txt`

Найди раздел про Пхукет (или «рынки»). Добавь аналогичный блок про Паттайю:
- Что уникального: активности, вечерняя жизнь, Ко Лан, пляж Джомтьен для семей
- Цены, сезон (круглый год, лучший ноябрь-март)
- Чем отличается от Пхукета

---

## ФАЗА 3 — Вьетнам: Нячанг + Дананг

### 3а. PWA — третий город

**Файл:** `/Users/soloplayer/Desktop/NestanDaRt-20/platform/app.html`

В PWA сейчас только Пхукет и Паттайя. Нужно добавить Вьетнам как третий вариант.

1. Найди JavaScript-объект с городами и акцент-цветами (что-то типа `const ACC = { phuket:'#B8FF3C', pattaya:'#FF5C1F' }`)
2. Добавь `vietnam: '#E8D44D'` (золотой — цвет Вьетнама, можно предложить другой если есть в БД)
3. Найди splash-экран (два вопроса «Пхукет?» / «Паттайя?») — добавь третью кнопку «Вьетнам?»
4. Добавь логику `choose('vietnam')` — фильтрация туров по `market_id='vietnam'`
5. Обнови title/description страницы, кеш-версию
6. Убедись что 12 туров Вьетнама отображаются корректно при фильтрации

### 3б. Supabase — активировать рынок

Через Supabase MCP выполни:

```sql
-- Сначала проверь состояние
SELECT id, slug, name, active FROM markets WHERE slug = 'vietnam';
SELECT count(*) FROM tours WHERE market_id = (SELECT id FROM markets WHERE slug = 'vietnam');

-- Активировать рынок и туры
UPDATE markets SET active = true WHERE slug = 'vietnam';
UPDATE tours SET active = true
  WHERE market_id = (SELECT id FROM markets WHERE slug = 'vietnam');
```

Если туры имеют `market_id IS NULL` (не привязаны к рынку) — проверь по городу:
```sql
SELECT slug, title, city, market_id FROM tours 
WHERE city ILIKE ANY(ARRAY['%нячанг%','%дананг%','%вьетнам%','%ханой%','%хошимин%'])
LIMIT 10;
```
И при необходимости обнови `market_id`.

### 3в. Knowledge — база знаний по Вьетнаму

Расширь constraint (если нужно) и добавь 15+ записей для Вьетнама:
- Нячанг: пляжи (Бай-Дай, Фуктан), острова (Хон-Мун), дайвинг, Po Nagar
- Дананг: Золотой Мост, Хойан (ЮНЕСКО, 30 мин), Мраморные горы, Ми-Кхе пляж
- Логистика: виза (e-visa 90 дней), перелёт из Бангкока (2-3 ч), деньги (донг), сим-карта
- Сезон Нячанга (январь-август сухой), сезон Дананга (февраль-август)
- `city = 'Вьетнам'`, `active = true`

### 3г. Промпт КотЭ — добавить блок Вьетнама

**Файл:** `platform/nestandart-20/prompt.txt`

Добавь раздел про Вьетнам:
- Нячанг vs Дананг: чем отличаются, кому что подходит
- Ключевые активности в каждом городе
- Важные нюансы для туристов из России (виза, курс, языковой барьер)

### 3д. Посадочная страница /vietnam/

Аналогично `/pattaya/` — создать `platform/vietnam/index.html`:
- SEO под Вьетнам (Нячанг, Дананг, экскурсии)
- Hero с картой/описанием двух городов
- Акцент-цвет Вьетнама
- CTA кнопки в КотЭ и PWA

---

## ПОСЛЕ ВСЕХ ФАЗ

1. Сделать `npm run check` или `python3 -m py_compile` на изменённые Python-файлы
2. Закоммитить с разбивкой по фазам (3 отдельных коммита)
3. Сообщить пользователю:
   - Что сделано и что задеплоить
   - Команды для деплоя на VPS
   - Какие ручные действия остались (Supabase SQL, n8n UI)

## ДЕПЛОЙ (скажи пользователю эти команды)

```bash
# Код:
ssh root@77.42.93.187 "cd /opt/NestanDaRt-20 && git pull && docker compose build nestandart-backend && docker compose up -d"

# app.html (PWA):
scp platform/app.html root@77.42.93.187:/var/www/nestandart/platform/app.html

# Паттайя посадочная:
ssh root@77.42.93.187 "mkdir -p /var/www/nestandart/pattaya"
scp platform/pattaya/index.html root@77.42.93.187:/var/www/nestandart/pattaya/index.html

# Вьетнам посадочная:
ssh root@77.42.93.187 "mkdir -p /var/www/nestandart/vietnam"
scp platform/vietnam/index.html root@77.42.93.187:/var/www/nestandart/vietnam/index.html
```

---

**ЗАПРЕТЫ (критично):**
- НЕ запускать `nestandart-bot` через Docker
- НЕ переименовывать volume `kote-n8n-data`
- НЕ ставить `KOTE_RPC_SECRET` пока n8n-ноды не обновлены
- НЕ коммитить `.env`
- НЕ менять `markets.id` (text: 'phuket', 'pattaya', 'vietnam')
