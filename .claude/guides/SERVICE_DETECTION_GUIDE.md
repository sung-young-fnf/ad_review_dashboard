# Service Detection Guide

## 경로 기반 자동 감지

| 경로 패턴 | 서비스 | Backend |
|-----------|--------|---------|
| `apps/{app}/backend/pyproject.toml` | FastAPI 앱 | Python + SQLAlchemy + Alembic |
| `apps/{app}/backend/nest-cli.json` | NestJS 앱 | TypeScript + Prisma |

## 파일 패턴 기반

| 파일 패턴 | Backend | 모델 위치 |
|-----------|---------|----------|
| `*.py`, `alembic`, `schemas/*.py` | FastAPI | `models/*.py` (SQLAlchemy) |
| `*.module.ts`, `*.controller.ts` | NestJS | `prisma/schema.prisma` |
| `dto/*.dto.ts` (class-validator) | NestJS | `modules/*/dto/*.dto.ts` |
| `schemas/*.py` (Pydantic) | FastAPI | `schemas/*.py` |

## 새 앱 추가 시
```bash
./scripts/create-app.sh {app-name} {fastapi|nestjs} [--port N] [--sso] [--design]
```
