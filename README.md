# fnf-mono-starter

> F&F 내부 서비스 모노레포 템플릿 — K8s 기반, FastAPI/NestJS + Next.js 16

## Quick Start

```bash
# 1. 템플릿 클론
git clone https://github.com/fnf-process/fnf-mono-starter.git prcs-devtools
cd prcs-devtools

# 2. 프로젝트 초기화
./scripts/init-project.sh prcs-devtools "PRCS Internal Dev Tools"

# 3. 앱 생성 (CLI 또는 인터랙티브)
./scripts/create-app.sh s3gate fastapi --port 3100 --sso --design
# 또는 인터랙티브:
./scripts/create-app.sh

# 4. DB 초기화
docker compose -f docker-compose.dev.yml up -d
psql -U postgres -f apps/s3gate/backend/scripts/init-db.sql

# 5. 개발 시작
cd apps/s3gate/backend && uv sync  # FastAPI
cd apps/s3gate/frontend && pnpm install
pnpm dev  # (루트에서)
```

## 구조

```
fnf-mono-starter/
├── apps/                          # 앱들 (create-app.sh로 생성)
│   └── {app-name}/
│       ├── backend/               # FastAPI 또는 NestJS
│       │   ├── src/               # 소스 코드 (빌트인 RBAC 포함)
│       │   ├── scripts/init-db.sql # DBUSER 정책 DB 초기화
│       │   ├── Dockerfile         # Multi-stage production build
│       │   └── .env.example
│       ├── frontend/              # Next.js 16 (shadcn/ui)
│       │   ├── src/app/           # App Router + BFF proxy
│       │   ├── src/widgets/sidebar/ # 동적 사이드바
│       │   ├── src/lib/auth.ts    # 인증 (SSO 또는 No-Auth)
│       │   ├── Dockerfile
│       │   └── .env.example
│       ├── DESIGN.md              # AI 디자인 시스템 (선택)
│       └── CLAUDE.md              # 앱별 에이전트 가이드
├── charts/{app-name}/             # Helm chart (Deploy/Service/Ingress/HPA)
├── templates/                     # 앱 템플릿 원본
│   ├── fastapi/                   # Python backend
│   ├── nestjs/                    # TypeScript backend
│   └── nextjs/                    # Next.js frontend
├── .claude/                       # AI 에이전트 시스템 (44 agents + squads)
├── .mcp.json                      # DB MCP 서버 (앱별 자동 추가)
├── docker-compose.dev.yml         # 로컬 PostgreSQL (pgvector)
└── docs/DBUSER-POLICY.md
```

## 인증 모드

`create-app.sh`에서 선택:

| 모드 | 옵션 | 로그인 | 사이드바 | 용도 |
|------|------|--------|---------|------|
| **No-Auth** | (기본) | 없음 — 바로 진입 | 전체 메뉴 표시 | 초기 개발, 프로토타입 |
| **SSO** | `--sso` | MS Entra ID | 역할 기반 필터링 | 사내 운영 서비스 |

### No-Auth → SSO 전환 (나중에 켤 때)

```bash
# 1. auth.ts 교체
cp src/lib/auth-modes/auth-sso.ts src/lib/auth.ts

# 2. .env 설정
AZURE_AD_CLIENT_ID=your-client-id
AZURE_AD_CLIENT_SECRET=your-client-secret
AZURE_AD_TENANT_ID=your-tenant-id
AUTH_SECRET=$(openssl rand -base64 32)

# 3. middleware.ts 복원 (라우트 보호)
# create-app.sh --sso로 생성한 앱에서 복사하거나 직접 생성:
echo 'export { auth as middleware } from "@/lib/auth";
export const config = { matcher: ["/((?!api|_next|favicon.ico|login|auth).*)"] };' > src/middleware.ts
```

### SSO 상세 (MS Entra ID)

```
Browser → /login → signIn('microsoft-entra-id')
  → MS Entra ID 인증 (MFA/조건부 액세스는 Entra 정책이 처리)
  → /api/auth/callback → NextAuth JWT 세션 생성
  → /api/v1/* → Bearer token → Backend
```

- **무료**: MS 365 포함 Entra ID Free로 충분
- **외부 사용자**: Entra Guest (B2B) 초대 또는 향후 Authentik 추가
- **토큰 갱신**: auth.ts에서 자동 refresh (만료 1분 전)

## 백엔드 선택

| | FastAPI | NestJS |
|--|---------|--------|
| **언어** | Python 3.11+ | TypeScript |
| **ORM** | SQLAlchemy + Alembic | Prisma (custom output + sync-client) |
| **DI 패턴** | `Depends(get_current_user)` | `@CurrentUser()` + Guard |
| **RBAC** | `require_admin`, `require_role()` | `AdminGuard`, `RolesGuard`, `@Roles()` |
| **패키지** | uv | pnpm |
| **적합** | ML/Data, AWS SDK 집약 | REST API, 타입 안전성 |

## 빌트인 기능 (모든 앱에 포함)

### RBAC (User + Role + Menu)

| 모듈 | API | 설명 |
|------|-----|------|
| **User** | `GET /users/me`, `GET /users` | SSO 자동등록, 관리자 목록 |
| **Role** | `CRUD /roles` | 역할 생성/수정/삭제 (AdminGuard) |
| **Menu** | `GET /menus/tree`, `CRUD /menus` | 역할 기반 동적 메뉴 |
| **Auth** | 글로벌 Guard | JWT 인증 + Admin/Roles 가드 |

### 프론트엔드 UI

| 페이지 | 경로 | 설명 |
|--------|------|------|
| 로그인 | `/login` | MS SSO 버튼 (No-Auth: 자동 redirect) |
| 동적 사이드바 | 전체 | 역할 기반 메뉴 + Lucide 아이콘 + 활성 표시 |
| 사용자 관리 | `/admin/users` | 통계 카드 + 테이블 + Admin 토글 |
| 메뉴 관리 | `/admin/menus` | 트리 테이블 + CRUD 폼 + 권한 배지 |

## DB 정책 (DBUSER)

모든 앱은 F&F DBUSER 정책을 따릅니다:
- **public 스키마 금지** → 서비스 전용 스키마 (`{app_name}`)
- **Owner 3단 분리**: `_adm` / `_object_owner_role` / `_dml_role`
- **앱 런타임**: `_svc` 계정 (DML 전용)
- **마이그레이션**: `_ops` 계정 (DDL, SET ROLE object_owner_role)

상세: [docs/DBUSER-POLICY.md](docs/DBUSER-POLICY.md)

## create-app.sh 옵션

```bash
# CLI 모드
./scripts/create-app.sh <name> <fastapi|nestjs> [options]

# 옵션
--port <N>     프론트엔드 포트 (기본: 3100, 사용 중이면 자동 추천)
--sso          MS Entra ID SSO 인증 포함
--design       DESIGN.md (AI 디자인 시스템) 포함

# 인터랙티브 모드 (옵션 없이 실행)
./scripts/create-app.sh
```

### 생성되는 것

| 항목 | 설명 |
|------|------|
| `apps/{name}/backend/` | FastAPI 또는 NestJS (빌트인 RBAC + Example 모듈) |
| `apps/{name}/frontend/` | Next.js 16 (shadcn/ui + BFF proxy + 사이드바 + Admin) |
| `apps/{name}/CLAUDE.md` | 앱별 에이전트 가이드 (자동 생성) |
| `apps/{name}/DESIGN.md` | AI 디자인 시스템 (--design 선택 시) |
| `charts/{name}/` | Helm chart (Deployment + Service + Ingress + HPA) |
| `.github/workflows/{name}-backend-dev.yml` | Backend 배포 (ECR push + Buildx) |
| `.github/workflows/{name}-frontend-dev.yml` | Frontend 배포 (ECR push + Buildx) |
| `.mcp.json` | PostgreSQL MCP 서버 (앱별 누적 추가) |

## 배포 전략

### Dev 환경 (자동)

```
코드 변경 → PR 머지 → GitHub Actions 자동 빌드 → ECR 푸시 → ArgoCD 감지 → EKS 배포
```

- Backend 변경 시 `{app}-backend-dev.yml`만 실행 (Frontend 무영향)
- Frontend 변경 시 `{app}-frontend-dev.yml`만 실행 (Backend 무영향)
- 이미지 태그: `{short-sha}-{timestamp}` + `dev-latest`

### Prd 환경 (태그 프로모션)

```
Dev 검증 완료 → Helm values에 이미지 태그 변경 → ArgoCD Sync → Prd 배포
```

- **별도 CI/CD 워크플로우 없음** — Dev 이미지를 그대로 사용
- Helm `values-prd.yaml`에서 이미지 태그만 변경 (dev-latest → 특정 버전)
- ArgoCD가 Git 변경 감지 → 자동 또는 수동 Sync

### 필요한 GitHub 설정

| Variable (environment: dev) | 설명 |
|---|---|
| `ECR_URL_BACKEND` | Backend ECR 레포 URL |
| `ECR_URL_FRONTEND` | Frontend ECR 레포 URL |
| `ROLE_ARN` | AWS OIDC 인증 Role ARN |
| `AWS_REGION` | `ap-northeast-2` |

## AI 에이전트 시스템

```
.claude/
├── agents/          # 44개 에이전트 (epic→story→task→code-writer→validator)
├── skills/          # 스킬/커맨드 시스템
├── squads/          # 스쿼드 편성 (EPIC/STORY/BUG 등 규모별 자동 편성)
├── hooks/           # Hook 자동 트리거 (빌드/커밋/에러 감지)
├── rules/           # 품질/워크플로우 규칙
└── guides/          # 기술 가이드 문서
```

## AI로 프로젝트 시작하기 (Prompts)

### 1. 프로젝트 초기화

```
fnf-mono-starter로 새 프로젝트를 만들어줘.
- 프로젝트명: prcs-devtools
- 설명: PRCS 내부 개발 도구
./scripts/init-project.sh prcs-devtools "PRCS Internal Dev Tools"
```

### 2. 앱 추가

```
새 앱을 추가해줘.
- 앱 이름: s3gate
- 백엔드: FastAPI
- 인증: MS SSO
- DESIGN.md 포함
./scripts/create-app.sh s3gate fastapi --port 3100 --sso --design
```

### 3. 기능 구현 (Epic)

```
s3gate PRD 기반 Phase 1 구현해줘.
- PRD: apps/s3gate/CLAUDE.md 참고
- Epic 생성 → Story 분해 → 순차 구현
```

### 4. 인증 모드 전환

```
s3gate를 No-Auth에서 SSO 모드로 전환해줘.
- auth-modes/auth-sso.ts → auth.ts 복사
- .env에 Azure AD 설정 추가
- middleware.ts 생성
```

### 5. 버그 수정

```
{앱}에서 {증상} 버그 발생.
- /diagnose 모드로 진단 먼저
```
