# 서비스 레포 표준 문서 구조 (Governance)

> 이 문서는 *mono-starter 로 파생된 모든 서비스 레포*가 공통으로 따르는 문서 구조 표준이다. AI 에이전트(특히 brown.alter)가 서비스 기술 질문을 받았을 때 *어디부터 보는지* 명확히 하기 위한 거버넌스.

## 왜 표준이 필요한가

문제 사례 (2026-06-30):
- 외부 서비스 개발자가 maily 발송 방법을 brown.alter에 질문
- brown 이 추정 답변 → 인증 헤더(`X-API-Key` vs 실제 `Bearer`) / 필드명(`from_addr` vs alias `from`) 오류
- 원인 = "어디 보면 정답이 있는지" 단서가 brown 에게 없었음

해법 = 모든 서비스 레포가 *같은 위치에 같은 종류 문서*를 두면, AI 는 그 위치만 알면 됨. 새 서비스 = 자동 적용.

## 표준 구조

```
{service-repo}/
├── README.md            # MANDATORY — 사람 onboarding 첫 페이지 (Quick Start + Docs Index + Swagger 링크)
├── CLAUDE.md            # MANDATORY — AI 참조 (스택/관습/금기 + Docs Index)
└── docs/
    ├── ARCHITECTURE.md  # 선택 — 시스템 구성/데이터 흐름 (복잡 서비스만)
    ├── API-USAGE.md     # HTTP API 서비스면 MANDATORY — how-to + 인증 + 예시 + 정책/제약 + FAQ
    ├── OPS.md           # MANDATORY — 배포/롤백/장애 대응
    ├── DBUSER-POLICY.md # DB 사용 서비스 — mono-starter 표준 그대로
    └── ({service 특수}) # 예: SENDING-DOMAIN-POLICY.md (maily)
```

## 각 문서 역할

### README.md (사람 first)
- 한 줄 소개 + Quick Start (clone → 실행 5분)
- **Docs Index** — `docs/*.md` 링크 표
- **Swagger UI 링크** (HTTP API 서비스): dev = `<dev_base_url>/docs`, prd = 비활성 권장
- 운영 URL (prd / dev) + Slack 채널

### CLAUDE.md (AI/brown first)
- `## Quick Facts` — repo / 도메인 / 스택 / DB / 인증 방식 한 표로
- `## Docs Index` — README 와 같은 인덱스. AI 가 첫 로드 시 1-hop 으로 정답 도달
- `## Core Rules` — 서비스 특수 규칙 (BFF 패턴, DB 스키마, 금기)
- `## API quick reference` — Swagger UI 링크 + base URL + 인증 방식 한 줄

### docs/API-USAGE.md (how-to + why)
**Swagger 와 역할 분리**:
| 도구 | 역할 |
|------|------|
| OpenAPI Swagger (`<base>/docs`) | **truth source** — endpoint/필드 schema (자동 생성, 항상 정확) |
| API-USAGE.md | **how-to + why** — 인증 흐름, curl/Python/Node 예시, 정책/제약 배경, FAQ |

API-USAGE.md 가 schema 복사 X (drift 방지). Swagger 가 정확한 schema 보유. 문서는:
- Base URL (prd / dev)
- 인증 방식 + 예시 (`Authorization: Bearer ...`)
- API 키 발급 흐름 (관리자 페이지 / Secrets Manager)
- *가장 흔한 요청* curl 예시 + Python + Node (5분 onboarding)
- 첨부/대용량/예약 등 특수 옵션
- *정책 / 제약 + 이유* (왜 한도가 N MB 인지)
- 발송 결과 / status 값 / 에러 응답 표
- FAQ
- "endpoint/필드 정확한 schema 는 Swagger 참조" 1줄

### docs/OPS.md
- 배포 흐름 (Actions → ECR → ArgoCD → ALB)
- 롤백 절차 (tag promote / values 수정)
- 장애 대응 (Pod CrashLoop / DB 연결 / SES bounce 등 흔한 케이스)
- 모니터링 링크 (Datadog dashboard / APM service)

## AI 에이전트 거버넌스 (brown.alter 등)

서비스 기술 질문을 받은 AI 는 **추정 답변 금지**. 다음 순서로 fetch:

1. `{service}/CLAUDE.md` — Docs Index 확인
2. 인덱스에서 가리키는 `docs/{TOPIC}.md` fetch (예: API 사용법 → `docs/API-USAGE.md`)
3. 정확한 schema 필요시 Swagger fetch — `curl -sS <dev_base>/openapi.json`
4. 답변 작성 (예시 코드는 docs 의 것 복붙, schema 는 Swagger 의 것 그대로)

→ 이 순서를 *AI 에이전트 SOUL/skill 에 박는다*. mono-starter 가 표준 위치를 보장하면 AI 는 위치만 알면 됨.

## Swagger UI 보안 (FastAPI 표준)

prd 에서 `/docs` 노출은 정보 누출 risk. mono-starter FastAPI template 권장:

```python
# app.py
import os
ENV = os.getenv("APP_ENV", "dev")
app = FastAPI(
    title="...",
    docs_url="/docs" if ENV != "prd" else None,
    redoc_url="/redoc" if ENV != "prd" else None,
    openapi_url="/openapi.json" if ENV != "prd" else None,
)
```

dev 에서 자유 탐색 + prd 비활성. 내부 도구라 prd 도 노출 OK 면 서비스별 결정.

## 신규 서비스 스캐폴딩 (`scripts/create-app.sh`)

`create-app.sh` 가 신규 서비스 만들 때 위 구조의 *placeholder* 를 자동 생성하도록 한다 (향후 PR). 일단은 *기존/신규 서비스 모두 본 가이드 따라 수동 작성*.

## 표준 미준수 시

AI 답변 정확도가 떨어진다. mono-starter PR 으로 표준 backport 진행:
1. README/CLAUDE.md 보강 (Docs Index 추가)
2. `docs/API-USAGE.md` 등 누락 문서 작성
3. Swagger UI 보안 옵션 적용

서비스팀 본인이 작성 권장 (인프라가 대신 작성하면 코드 내부 컨텍스트 부족).

## 실제 적용 사례

- **maily** (2026-06-30): `docs/API-USAGE.md` + `docs/SENDING-DOMAIN-POLICY.md` 신규. CLAUDE.md Guides 섹션 보강. 본 거버넌스의 첫 적용 사례.

## 참고

- `docs/DBUSER-POLICY.md` — DB 계정 표준 (이미 mono-starter 표준)
- root `CLAUDE.md` — AI 참조 entry point
- brown.alter SOUL — 서비스 기술 질문 routing (`service-doc-lookup` skill)
