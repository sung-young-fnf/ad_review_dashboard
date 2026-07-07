# s3gate

## Tech Stack
| Layer | Tech |
|-------|------|
| Backend | Python 3.11+ FastAPI + SQLAlchemy + Alembic |
| Frontend | Next.js 16 React 19 TypeScript |
| DB Schema | `s3gate.*` (PostgreSQL, DBUSER 정책) |
| Auth | Microsoft Entra ID SSO (OIDC) |

## DB 작업 시 필수
- public 스키마 금지 → `s3gate` 스키마만 사용
- 앱 런타임: `s3gate_svc` 계정 (DML 전용)
- 마이그레이션: `s3gate_alembic_ops` 계정

## BFF 패턴 (필수)
```
Browser → Next.js API Route → fastapi Backend
```
