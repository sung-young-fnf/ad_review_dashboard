# fnf-mono-starter

> F&F 내부 서비스 모노레포 템플릿 — K8s 기반, FastAPI/NestJS + Next.js

## Quick Start

```bash
# 1. 템플릿 클론
git clone https://github.com/hihenen/fnf-mono-starter.git prcs-devtool
cd prcs-devtool

# 2. 프로젝트 초기화
./scripts/init-project.sh prcs-devtool "PRCS Internal Dev Tools"

# 3. 앱 생성
./scripts/create-app.sh s3gate fastapi --port 3100
./scripts/create-app.sh user-portal nestjs --port 3200

# 4. DB 초기화 (DBUSER 정책 자동 적용)
docker compose -f docker-compose.dev.yml up -d
psql -U postgres -f apps/s3gate/backend/scripts/init-db.sql

# 5. 개발 시작
pnpm dev
```

## 구조

```
fnf-mono-starter/
├── apps/                        # 앱들 (create-app.sh로 생성)
│   └── {app-name}/
│       ├── backend/             # FastAPI 또는 NestJS
│       │   ├── src/             # 소스 코드
│       │   ├── scripts/
│       │   │   └── init-db.sql  # DBUSER 정책 기반 DB 초기화
│       │   ├── migrations/      # Alembic (FastAPI) / prisma/ (NestJS)
│       │   ├── Dockerfile
│       │   └── .env.example
│       └── frontend/            # Next.js 15
│           ├── src/app/         # App Router
│           ├── Dockerfile
│           └── .env.example
├── charts/                      # Helm charts
│   └── {app-name}/
├── templates/                   # 앱 템플릿 (create-app.sh가 사용)
│   ├── fastapi/                 # FastAPI 백엔드 템플릿
│   ├── nestjs/                  # NestJS 백엔드 템플릿
│   └── nextjs/                  # Next.js 프론트엔드 템플릿
├── scripts/
│   ├── init-project.sh          # 프로젝트 초기화
│   └── create-app.sh            # 앱 스캐폴딩
├── packages/                    # 공유 패키지 (선택)
├── .github/workflows/           # CI/CD
├── docker-compose.dev.yml       # 로컬 PostgreSQL
├── CLAUDE.md                    # Agent 가이드
└── docs/
    └── DBUSER-POLICY.md         # DB 계정 정책 문서
```

## 백엔드 선택

| | FastAPI | NestJS |
|--|---------|--------|
| **언어** | Python 3.11+ | TypeScript |
| **ORM** | SQLAlchemy + Alembic | Prisma |
| **패키지** | uv | pnpm |
| **DB 계정** | `_alembic_ops` (마이그레이션) | `_prisma_ops` (마이그레이션) |
| **적합** | ML/Data, AWS SDK 집약 | REST API, 타입 안전성 |

## DB 정책 (DBUSER)

모든 앱은 F&F DBUSER 정책을 따릅니다:
- **public 스키마 금지** → 서비스 전용 스키마
- **Owner 3단 분리**: `_adm` / `_object_owner_role` / `_dml_role`
- **앱 런타임**: `_svc` 계정 (DML 전용)
- **마이그레이션**: `_ops` 계정 (DDL, SET ROLE object_owner_role)

상세: [docs/DBUSER-POLICY.md](docs/DBUSER-POLICY.md)
