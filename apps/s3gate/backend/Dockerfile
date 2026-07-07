# s3gate Backend (Python FastAPI + SQLAlchemy + Alembic)
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
COPY apps/s3gate/backend/pyproject.toml apps/s3gate/backend/uv.lock* ./
RUN uv sync --frozen --no-dev --no-install-project

# Cache bust ARG
ARG CACHEBUST=1

# Source code
COPY apps/s3gate/backend/src ./src
COPY apps/s3gate/backend/migrations ./migrations
COPY apps/s3gate/backend/alembic.ini ./

# Install project package (모듈 import 가능하게)
RUN uv sync --frozen --no-dev

# Non-root user
RUN useradd --create-home appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uv", "run", "--no-sync", "uvicorn", "s3gate.main:app", "--host", "0.0.0.0", "--port", "8000"]
