FROM python:3.11-slim AS base

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Dependencies
COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen --no-dev

# Source
COPY src/ ./src/
COPY migrations/ ./migrations/
COPY alembic.ini ./

EXPOSE 8000

CMD ["uv", "run", "uvicorn", "{{APP_NAME_SNAKE}}.main:app", "--host", "0.0.0.0", "--port", "8000"]
