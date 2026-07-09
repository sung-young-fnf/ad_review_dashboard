# advertisement

영상 분석·재생성 대시보드 — 원본 영상 · 분석 프롬프트(수동) · 프롬프트로 만든 AI 영상을
계층 저장하고, 여러 영상을 배속 비교한다.

## Tech Stack
| Layer | Tech |
|-------|------|
| Backend | Python 3.11+ FastAPI + SQLAlchemy(async) + Alembic |
| Frontend | Next.js 16 React 19 TypeScript (shadcn/ui + sonner) |
| DB | PostgreSQL 17 (cloudy 테넌트), 스키마 `advertisement` |
| Storage | S3 (cloudy) — presigned URL |
| Auth | Microsoft Entra ID SSO (OIDC) |
| Design | Genesis (DESIGN.md) — indigo #6366F1 |

## 데이터 모델
```
Video(원본) 1──* Prompt(수동 입력) 1──* GeneratedVideo(AI 영상, 등록만)
```
Video 삭제 시 하위 Prompt·GeneratedVideo + S3 객체까지 cascade 삭제.

## cloudy 'advertisement' 인프라 규칙 (MANDATORY)
> 🔒 DB 비밀번호·cloudy 토큰(`cpt_...`)은 `.env`(gitignore)에만. 커밋 파일에 실제 값 절대 금지.

- **S3**: 반드시 `s3://dt-ane2-s3-dev-dcs-cloudy/advertisement/` prefix 아래만 read/write (그 외 권한 없음)
- **AWS SDK**: 프로필 `cloudy-advertisement` 사용
  - Python: `boto3.Session(profile_name="cloudy-advertisement")`
  - CLI: `--profile cloudy-advertisement`
- **영구키**: 갱신/만료 처리 불필요 (credential_process 자동)
- **DB**: `advertisement` 데이터베이스만 접근 (PostgreSQL 17), 앱 런타임 계정 `advertisement_svc`
- 콘솔: https://dcs-cloudy.int-prcs-dev.fnf.co.kr/cloudy → advertisement

### AWS 프로필 최초 등록 (호스트 1회)
```bash
curl -fsSL https://dcs-cloudy.int-prcs-dev.fnf.co.kr/cloudy/api/setup \
  | bash -s -- <CLOUDY_TOKEN> advertisement
```

### 마이그레이션 계정
cloudy 는 `advertisement_svc`(DML)만 발급. 별도 `_ops`/`_adm` 계정 없음 →
`advertisement_svc` 의 DDL 권한으로 Alembic 실행(권한 부족 시 cloudy 콘솔에서 ops 크리덴셜 요청).
s3gate 식 `scripts/init-db.sql`(3단 role 생성)은 **실행하지 않는다** — 테넌트 DB는 이미 프로비저닝됨.

## DB 정책
- public 스키마 금지 → `advertisement` 스키마만 사용 (모델 `__table_args__={"schema":"advertisement"}`)

## BFF 패턴 (필수)
```
Browser → Next.js /api/v1/[...path] → FastAPI Backend
```
- ❌ 브라우저에서 Backend·S3 API 직접 호출 금지 (presigned URL PUT/GET 만 예외)
- ✅ presigned URL 발급은 백엔드(`services/s3_service.py`) 경유

## 업로드 플로우
```
브라우저 → BFF POST /api/v1/uploads/presign → presigned PUT URL 발급
브라우저 → presigned URL 로 S3 직접 PUT
브라우저 → BFF POST /api/v1/videos {s3_key, title...} 레코드 생성
```

## OpenAPI 타입 동기화 (Backend DTO 변경 후 필수)
```bash
cd apps/advertisement/backend && uv run python scripts/export-openapi.py
cd ../frontend && pnpm generate:api
```

## Ports
- Frontend 3200 / Backend 8000
