# {{PROJECT_NAME}}

> Always Answer Korean. Think carefully. Minimal code changes.

## Mission
K8s 기반 내부 개발 도구 모노레포

## Tech Stack (앱별 상이)

| Layer | Tech |
|-------|------|
| Frontend (공통) | Next.js 16+ React 19 TypeScript (shadcn/ui) |
| Backend (선택) | FastAPI (Python) 또는 NestJS (TypeScript) |
| Auth | MS Entra ID SSO (NextAuth v5) 또는 No-Auth |
| DB | PostgreSQL 15+ (pgvector, DBUSER 정책) |
| Infra | K8s (EKS), Helm, ArgoCD, GitHub Actions |
| Package | uv (Python) / pnpm (TypeScript) |

## 앱별 스택 감지
- `apps/{app}/backend/pyproject.toml` → FastAPI (SQLAlchemy + Alembic)
- `apps/{app}/backend/nest-cli.json` → NestJS (Prisma)
- `apps/{app}/CLAUDE.md` → 앱별 상세 규칙

## Commands
```bash
pnpm dev            # 전체 dev
pnpm build          # 전체 빌드
./scripts/create-app.sh  # 새 앱 생성 (인터랙티브)
```

## Core Rules

### BFF 필수
```
Browser → Next.js /api/v1/[...path] → Backend
```
- ❌ 브라우저에서 Backend 직접 호출 금지
- ✅ BFF proxy가 session.accessToken → Bearer 토큰으로 전달

### DB 정책 (DBUSER)
- ❌ public 스키마 금지 → `{서비스명}` 전용 스키마
- ✅ Owner 3단 분리: `_adm` / `_object_owner_role` / `_dml_role`
- ✅ 앱 런타임: `_svc` 계정 (DML 전용)
- ✅ 마이그레이션: `_ops` 계정만 DDL 실행

### 인증 모드
- **No-Auth** (기본): 로그인 없이 바로 사용 (개발용)
- **SSO** (--sso): MS Entra ID → NextAuth → JWT 세션
- 전환: `cp src/lib/auth-modes/auth-sso.ts src/lib/auth.ts` + `.env` 설정

### 빌트인 RBAC
- User: SSO 자동등록, Admin 토글
- Role: CRUD (AdminGuard)
- Menu: 동적 사이드바 (역할 기반 필터링)
- Guard: JwtAuthGuard (글로벌), AdminGuard, RolesGuard, @Roles()

### 배포 전략
- **Dev**: 코드 머지 → GitHub Actions 자동 빌드 → ECR → ArgoCD → EKS
- **Prd**: Dev 이미지 태그를 Helm values에 프로모션 → ArgoCD Sync
- Backend/Frontend 배포 워크플로우 분리 (독립 빌드)
- 워크플로우: `.github/workflows/{app}-backend-dev.yml`, `{app}-frontend-dev.yml`

### OpenAPI 타입 동기화
- Backend DTO 변경 후 반드시:
  - FastAPI: `uv run python scripts/export-openapi.py`
  - NestJS: `./scripts/export-openapi.sh` (서버 실행 중)
  - Frontend: `pnpm generate:api`

### Datadog APM (자동 주입)
- 본 템플릿으로 생성된 서비스는 Datadog Admission Controller 자동 주입으로 APM 수집 (`charts/{app}/values.yaml` 의 `backend.apm` / `frontend.apm`).
- 전제: cluster 측 `datadog.apm.instrumentation.enabled=true` + `admissionController.enabled=true`.
- ddtrace 라이브러리 버전은 Helm annotation (`admission.datadoghq.com/<lang>-lib.version`) 으로 관리 — **Dockerfile / requirements.txt / package.json 에 ddtrace 추가 금지**.
- `language` 기본값: FastAPI → `python`, NestJS → `js` (create-app.sh 가 backend 스택에 맞춰 자동 설정).
- 비활성화: `backend.apm.enabled=false` 또는 `frontend.apm.enabled=false`.

## Post-Change Checklist
1. `pnpm tsc --noEmit` (TypeScript 체크)
2. Backend DTO 변경 시 → OpenAPI 재생성
3. 커밋 전 사용자 확인

## Absolute Rules
YAGNI | DRY | NO PARTIAL | NO DEAD CODE

## Guides
- `.claude/guides/` — 기술 가이드
- `.claude/rules/` — 품질/워크플로우 규칙
- `docs/DBUSER-POLICY.md` — DB 계정 정책
