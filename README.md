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
│       └── frontend/            # Next.js 16
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

## AI 에이전트 시스템

이 템플릿에는 Claude Code / Cursor 등 AI 코딩 에이전트를 위한 전체 인프라가 포함됩니다:

```
.claude/
├── agents/          # 44개 에이전트 (epic→story→task→code-writer→validator)
├── skills/          # 스킬/커맨드 시스템
├── squads/          # 스쿼드 편성 (EPIC/STORY/BUG 등 규모별 자동 편성)
├── hooks/           # Hook 자동 트리거 (빌드/커밋/에러 감지)
├── rules/           # 품질/워크플로우 규칙
├── guides/          # 기술 가이드 문서
└── CLAUDE.md        # 에이전트 기본 규칙
```

## AI로 프로젝트 시작하기 (Prompts)

### 1. 프로젝트 초기화 (Claude Code / Cursor에 붙여넣기)

```
fnf-mono-starter 템플릿을 사용해서 새 프로젝트를 만들어줘.
- 프로젝트명: prcs-devtools
- 설명: PRCS 내부 개발 도구

./scripts/init-project.sh prcs-devtools "PRCS Internal Dev Tools" 실행해줘.
```

### 2. 새 앱 추가

```
새 앱을 추가해줘.
- 앱 이름: s3gate
- 백엔드: FastAPI
- MS SSO 인증 포함
- DESIGN.md 포함
- PRD: /Users/yun/Downloads/s3gate-prd.md 참고

./scripts/create-app.sh 인터랙티브 모드로 실행하거나
./scripts/create-app.sh s3gate fastapi --port 3100 --sso --design 실행해줘.
```

### 3. 기능 구현 (Epic 단위)

```
s3gate PRD를 기반으로 Phase 1 (MVP)을 구현해줘.
- PRD: apps/s3gate/CLAUDE.md + /Downloads/s3gate-prd.md 참고
- MS SSO 로그인 + 사용자 자동 등록
- 역할/권한 CRUD (관리자 페이지)
- Storage Browser 읽기 전용

Epic을 생성하고 Story로 분해해서 순차 구현해줘.
```

### 4. 기존 앱에 기능 추가

```
{앱이름}에 {기능}을 추가해줘.
- apps/{앱이름}/CLAUDE.md 참고
- Backend + BFF + Frontend 전부 구현 (한쪽만 금지)
- DBUSER 정책 준수 (public 스키마 금지)
- OpenAPI 타입 재생성 포함
```

### 5. 버그 수정

```
{앱이름}에서 {증상} 버그가 발생해.
- 코드 변경 전에 근본 원인부터 파악해줘
- /diagnose 모드로 진단 먼저
```
