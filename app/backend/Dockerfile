# ═══════════════════════════════════════════════
# kote-backend — FastAPI REST API
# для мобильного приложения «ПХУКЕТИК»
# ═══════════════════════════════════════════════
FROM python:3.12-slim

WORKDIR /app

# Зависимости — слой кэшируется отдельно
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Код
COPY . .

# Uvicorn: 0.0.0.0 — чтобы Docker пробрасывал порт
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
