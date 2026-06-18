# ═══════════════════════════════════════════════
# kote-backend — FastAPI REST API
# для мобильного приложения «ПХУКЕТИК»
# ═══════════════════════════════════════════════
FROM python:3.12-slim

WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Зависимости — слой кэшируется отдельно
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Код
COPY . .

# Uvicorn: 0.0.0.0 — чтобы Docker пробрасывал порт
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
