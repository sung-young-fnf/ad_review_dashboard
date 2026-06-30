# {SERVICE} API 사용 가이드 (template)

> **사용법**: 신규 서비스 만들 때 이 파일을 `{service-repo}/docs/API-USAGE.md` 로 복사 후 `{SERVICE}` / `<base>` / 도메인을 치환. how-to + why 중심. 정확한 schema 는 Swagger UI 참조.

## 기본 정보

| 항목 | 값 |
|------|---|
| Base URL (prd) | `https://{SERVICE}.fnf.co.kr` |
| Base URL (dev) | `https://{SERVICE}-dev.fnf.co.kr` |
| 인증 | (예: `Authorization: Bearer <api_key>` / 또는 SSO Cookie) |
| OpenAPI Swagger | `<base>/docs` (dev 에서 자유 조회, prd 는 보안상 비활성) |
| OpenAPI JSON | `<base>/openapi.json` (AI 가 정확한 schema fetch 시) |

## API 키 발급 (Bearer 인증 서비스)

- 관리자 페이지 또는 인프라 측 발급
- 키는 발급 시 1회 노출, 이후 hash 만 저장 → 즉시 1Password 저장
- 서비스별 키 1개 권장 (로그/한도 추적)

## 가장 간단한 호출

```bash
curl -X POST https://{SERVICE}.fnf.co.kr/api/v1/{endpoint} \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

응답 예시 (필요시 status code + body):
```json
{ ... }
```

## Python 예시

```python
import requests
r = requests.post(
    "https://{SERVICE}.fnf.co.kr/api/v1/{endpoint}",
    headers={"Authorization": f"Bearer {api_key}"},
    json={ ... },
    timeout=30,
)
r.raise_for_status()
print(r.json())
```

## Node 예시

```javascript
const r = await fetch("https://{SERVICE}.fnf.co.kr/api/v1/{endpoint}", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${process.env.API_KEY}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({ ... }),
});
console.log(await r.json());
```

## 발송/요청 옵션 (서비스 특수)

| 필드 | 타입 | 설명 |
|------|------|------|
| ... | ... | ... |

> endpoint/필드 정확한 schema 는 Swagger UI 참조: `<base>/docs`

## 제약 / 한도

| 항목 | 한도 | 이유 |
|------|------|------|
| ... | ... | ... (왜 이 한도인지 배경 명시 — 외부 의존성 / 정책 / 비용) |

## 결과 조회 / status

| status | 의미 |
|--------|------|
| ... | ... |

## 에러 응답

| status | 의미 |
|--------|------|
| 400 | 요청 형식 오류 |
| 401 | 인증 누락/오류 |
| 403 | 권한 없음 |
| 422 | 검증 실패 (서비스 특수 — 한도 초과 등) |
| 429 | rate limit |
| 5xx | 인프라 오류 — 재시도 |

## FAQ

### Q. 외부 노출 가능?
A. (서비스마다 명시)

### Q. 대량 발송 / 대용량 첨부?
A. (서비스마다 명시 — SQS 활용 / SharePoint 링크 등)

## 참고 문서

- `docs/OPS.md` — 배포/롤백/장애 대응
- (서비스 특수 정책 문서)
- 문의: PRCS 인프라 또는 `#team-prcs-aie-all` (또는 서비스 전용 채널)
