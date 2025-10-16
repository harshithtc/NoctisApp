FROM python:3.11-slim

# Python/runtime safety and speed
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=on

WORKDIR /app

# System deps (minimal). Keep ffmpeg only if you actually use it.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates \
    postgresql-client \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps first for better layer caching
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements.txt

# Copy only the app (your .dockerignore excludes secrets and junk)
COPY app /app/app
COPY alembic.ini /app/alembic.ini
COPY alembic /app/alembic

# Create non-root user and set ownership
RUN addgroup --system app && adduser --system --ingroup app app && \
    chown -R app:app /app
USER app

EXPOSE 8000

# Healthcheck (ensure /health exists or adjust to a lightweight endpoint)
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://localhost:8000/health || exit 1

# Note: WebSockets + multiple workers can cause issues without sticky sessions.
# Prefer a single worker unless you're sure about session affinity in front.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
