FROM python:3.12-slim
WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Контекст сборки = корень репо (см. docker-compose.yml), поэтому пути с префиксом
COPY platform/bot/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Весь код бота (main.py, intent.py, supabase_client.py, admin_notify.py, tools_knowledge.py)
COPY platform/bot/ .
# Общий AI-слой (fallback chain) из корня репо — нужен для `from providers import ask`
COPY providers/ ./providers/

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1
CMD ["python", "main.py"]
