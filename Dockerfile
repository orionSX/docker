# Используем Python 3.11 для лучшей производительности
FROM python:3.11-slim as base

# Устанавливаем системные зависимости и очищаем кэш в одном слое
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Создаем пользователя для безопасности
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Этап сборки зависимостей
FROM base as builder

WORKDIR /app

# Устанавливаем uv для быстрой установки пакетов
RUN pip install --no-cache-dir uv

# Копируем только файл зависимостей для лучшего кэширования
COPY pyproject.toml .

# Устанавливаем зависимости в виртуальное окружение
RUN uv venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN uv pip install --no-cache -r pyproject.toml --extra test

# Финальный этап
FROM base as final

WORKDIR /app

# Копируем виртуальное окружение из builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Копируем код приложения
COPY --chown=appuser:appuser src/ ./src/
COPY --chown=appuser:appuser tests/ ./tests/

# Переключаемся на непривилегированного пользователя
USER appuser

# Указываем переменные окружения
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

EXPOSE 8022

# Healthcheck для Docker/Podman
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8022/health')" || exit 1

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8022"]
