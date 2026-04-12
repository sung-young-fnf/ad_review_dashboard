# {{PROJECT_NAME}}

> Always Answer Korean. Think carefully. Minimal code changes.

## Mission
K8s 기반 내부 개발 도구 모노레포

## Tech Stack (앱별 상이)

| Layer | Tech |
|-------|------|
| Frontend (공통) | Next.js 16+ React 19 TypeScript |
| Backend (선택) | FastAPI (Python) 또는 NestJS (TypeScript) |
| Infra | K8s, Helm, ArgoCD, GitHub Actions |
| Package | uv (Python) / pnpm (TypeScript) |

## 앱별 스택 감지
- `apps/{app}/backend/pyproject.toml` 존재 → FastAPI
- `apps/{app}/backend/package.json` + `nest-cli.json` 존재 → NestJS

## Commands
```bash
pnpm dev          # 전체 dev
pnpm build        # 전체 빌드
pnpm create-app   # 새 앱 생성: ./scripts/create-app.sh <name> <fastapi|nestjs>
```

## Core Rules
- BFF 필수: Browser → Next.js API Route → Backend (직접 호출 금지)
- DB: public 스키마 금지 → `{서비스명}` 전용 스키마 (DBUSER 정책)
- DB 계정: Owner 3단 분리 (_adm / _object_owner_role / _dml_role)
- 앱 서비스 계정(_svc)은 DML 전용, DDL은 _ops 계정으로만
