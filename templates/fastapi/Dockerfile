# {{APP_NAME}} Backend (Python FastAPI + SQLAlchemy + Alembic)
# Production Dockerfile

FROM python:3.11-slim

WORKDIR /app

# Install uv (fast Python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Dependencies first (better layer caching)
COPY apps/{{APP_NAME}}/backend/pyproject.toml apps/{{APP_NAME}}/backend/uv.lock* ./
RUN uv sync --frozen --no-dev

# Cache bust ARG
ARG CACHEBUST=1

# Source code
COPY apps/{{APP_NAME}}/backend/src ./src
COPY apps/{{APP_NAME}}/backend/migrations ./migrations
COPY apps/{{APP_NAME}}/backend/alembic.ini ./

# Install project package (모듈 import 가능하게)
RUN uv sync --frozen --no-dev

# Non-root user
RUN useradd --create-home appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uv", "run", "--no-sync", "uvicorn", "{{APP_NAME_SNAKE}}.main:app", "--host", "0.0.0.0", "--port", "8000"]
