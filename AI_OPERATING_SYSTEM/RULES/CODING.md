# CODING.md — ПРАВИЛА НАПИСАНИЯ КОДА
> Версия: 1.0

---

## НАЗНАЧЕНИЕ

Стандарты кода для всего проекта.

Не для красоты.  
Для простоты поддержки.  
Для уменьшения ошибок.

---

## ОБЩИЕ ПРИНЦИПЫ

| Принцип | Описание |
|---------|----------|
| **KISS** | Проще лучше |
| **YAGNI** | Не добавлять то, что может понадобиться |
| **DRY** | Не повторяться, но не переусложнять |
| **Readability** | Код читается чаще, чем пишется |

---

## PYTHON (FastAPI Backend)

### Стиль
- [ ] PEP 8 (flake8)
- [ ] Type hints (обязательно)
- [ ] Docstrings только для публичных функций
- [ ] Имена: `snake_case` для функций/переменных, `PascalCase` для классов

### Структура файла
```python
# 1. Импорты (стандартная библиотека →сторонние → локальные)
import os
from fastapi import APIRouter
from app.db import supabase

# 2. Константы
ROUTER = APIRouter(prefix="/api/v1/tours", tags=["tours"])

# 3. Функции/классы
@ROUTER.get("/")
def get_tours(market_id: str):
    ...

# 4. Точка входа (если main.py)
if __name__ == "__main__":
    uvicorn.run("main:app", reload=True)
```

### Запрещено
- Создавать классы "для красоты"
- Использовать `*` в импортах
- Создавать файлы > 500 строк (разбить)
- Создавать функции > 50 строк (разбить)
- Использовать глобальные переменные (кроме констант)

---

## JAVASCRIPT/REACT (БАЗА)

### Стиль
- [ ] ESLint (проектные правила)
- [ ] Functional components + hooks
- [ ] Имена: `camelCase` для переменных/функций, `PascalCase` для компонентов
- [ ] Props: деструктуризация

### Структура компонента
```jsx
// 1. Импорты
import { useState } from 'react'
import { supabase } from '../context/AppContext'

// 2. Компонент
export default function MyComponent({ prop1, prop2 }) {
  // 3. State
  const [data, setData] = useState(null)
  
  // 4. Effects
  useEffect(() => { ... }, [])
  
  // 5. Handlers
  const handleClick = () => { ... }
  
  // 6. Render
  return <div>...</div>
}
```

### Запрещено
- Создавать классовые компоненты (если не нужно)
- Использовать `any` в TypeScript
- Создавать компоненты > 200 строк (разбить)
- Создавать хуки "на будущее"
- Использовать пропсы drilling (использовать Context)

---

## HTML/CSS/JS (Сайт, PWA)

### HTML
- [ ] Семантические теги (`<header>`, `<main>`, `<article>`)
- [ ] Валидный HTML5
- [ ] Минимум вложенности
- [ ] Атрибуты в кавычках

### CSS
- [ ] Mobile-first
- [ ] BEM или utility-first (как в проекте)
- [ ] CSS-переменные для цветов/размеров
- [ ] Анимации только для UX (не для красоты)

### JavaScript
- [ ] Vanilla JS (не jQuery, не frameworks)
- [ ] Функции < 30 строк
- [ ] Имена: `camelCase`
- [ ] Константы: `UPPER_SNAKE_CASE`

### Запрещено
- Создавать CSS > 1000 строк (разбить на модули)
- Создавать JS > 500 строк (разбить на модули)
- Использовать inline styles (кроме динамических)
- Создавать функции "на будущее"

---

## SQL (Supabase)

### Стиль
- [ ] Заглавные ключевые слова (`SELECT`, `FROM`, `WHERE`)
- [ ] Lowercase для таблиц/колонок
- [ ] Параметризованные запросы (никогда не конкатенировать)

### Пример
```sql
-- ✅ Хорошо
SELECT id, title, price_adult
FROM tours
WHERE market_id = $1 AND active = true
ORDER BY created_at DESC;

-- ❌ Плохо
SELECT * FROM tours WHERE market_id = '" + market_id + "'
```

### Запрещено
- `SELECT *` (указывать колонки)
- Конкатенация строк в запросах (SQL Injection)
- Создавать индексы "на будущее"
- Менять схему без миграции

---

## ИМЕНА

### Файлы
- `snake_case` для Python
- `kebab-case` для HTML/CSS
- `PascalCase` для React компонентов
- `camelCase` для JS утилит

### Переменные/Функции
- `snake_case` в Python
- `camelCase` в JS/React
- `PascalCase` для классов

### Константы
- `UPPER_SNAKE_CASE` везде

---

## КОММЕНТАРИИ

### Запрещено
- Комментировать очевидное (`# increment i`)
- Комментировать удалённый код
- Создавать блоки `/* === SECTION === */`

### Обязательно
- Комментировать только сложную логику
- Объяснять "почему", а не "что"
- Docstrings для публичных API функций

---

## ОБРАБОТКА ОШИБОК

### Python
```python
try:
    result = supabase.table('tours').select('*').execute()
except Exception as e:
    logger.error(f"Failed to get tours: {e}")
    raise HTTPException(status_code=500, detail="Internal error")
```

### JavaScript
```javascript
try {
  const { data } = await supabase.from('tours').select('*')
  setTours(data)
} catch (error) {
  console.error('Failed to get tours:', error)
  setError('Не удалось загрузить туры')
}
```

### Запрещено
- `except: pass` (тихие ошибки)
- `console.log` в продакшене (только `console.error`)
- Показывать пользователю технические ошибки

---

## КОНТРОЛЬНЫЕ ВОПРОСЫ

Перед каждым изменением:
1. **Это следует существующим паттернам?** (не изобретает)
2. **Это минимальная реализация?** (не "идеальная")
3. **Это читаемо?** (новый разработчик поймёт)
4. **Это не усложняет?** (не добавляет абстракций)
5. **Это можно откатить?** (`git revert` работает)

Если хотя бы один ответ «нет» — **НЕ ВЫПОЛНЯТЬ**.

---

*КОД ДОЛЖЕН БЫТЬ ПРОСТЫМ. ВСЕГДА.*