# Use official slim Python image for smaller image size
FROM python:3.11-slim

# Environment variables to improve python runtime behavior
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=on

WORKDIR /app

# Install minimal system dependencies, keep ffmpeg if actually used, clean apt cache
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    postgresql-client \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install python dependencies first for docker layer caching
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /app/requirements.txt

# Copy application code and migrations
COPY app /app/app
COPY alembic.ini /app/alembic.ini
COPY alembic /app/alembic

# Create a non-root user and set proper permissions
RUN addgroup --system app && adduser --system --ingroup app app \
    && chown -R app:app /app

USER app

EXPOSE 8000

# Healthcheck: checks /health endpoint every 30 seconds
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://localhost:8000/api/v1/health || exit 1

# Note about WebSocket support:
# Sticky sessions are recommended for multiple workers to avoid connection issues.
# Default to single worker to ensure connection stability.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
