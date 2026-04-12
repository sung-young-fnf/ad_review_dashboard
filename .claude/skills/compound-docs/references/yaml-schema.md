# YAML Schema Reference

## 필수 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| module | string | ✅ | 영향받은 모듈/서비스 |
| date | string (YYYY-MM-DD) | ✅ | 문서 작성일 |
| problem_type | enum | ✅ | 문제 유형 |
| component | string | ✅ | 영향받은 컴포넌트 |
| symptoms | string[] (1-5) | ✅ | 관찰된 증상 목록 |
| root_cause | string | ✅ | 근본 원인 키워드 |
| severity | enum | ✅ | 심각도 |
| service | enum | ✅ | 대상 서비스 |
| tags | string[] | ✅ | 검색용 태그 |
| related_docs | string[] | ❌ | 관련 문서 경로 |

## Enum 값

### problem_type

| 값 | 설명 | 카테고리 디렉토리 |
|----|------|----------------|
| build_error | 빌드/컴파일 에러 | build-errors/ |
| runtime_error | 런타임 에러 | runtime-errors/ |
| performance_issue | 성능 문제 | performance-issues/ |
| database_issue | DB 스키마/쿼리 문제 | database-issues/ |
| security_issue | 보안 취약점 | security-issues/ |
| api_integration | API 연동 문제 | api-integration/ |
| ui_bug | UI 렌더링/동작 버그 | ui-bugs/ |
| auth_issue | 인증/인가 문제 | auth-issues/ |
| deployment_issue | 배포/인프라 문제 | deployment-issues/ |

### severity

| 값 | 설명 |
|----|------|
| critical | 서비스 장애, 데이터 손실 |
| high | 주요 기능 장애 |
| medium | 기능 제한적 영향 |
| low | 사소한 영향 |

### service

| 값 | 설명 |
|----|------|
| mcp-orbit | Python/FastAPI 마켓플레이스 서비스 |
| ai-agent | TypeScript/NestJS AI 에이전트 서비스 |
| app-hub | TypeScript/NestJS 앱허브 서비스 |
| agent-office-phaser | Colyseus/Phaser 서비스 |

## 검증 규칙

1. `problem_type`은 위 enum 값 중 하나여야 함
2. `severity`는 `critical|high|medium|low` 중 하나
3. `service`는 `mcp-orbit|ai-agent|app-hub|agent-office-phaser` 중 하나
4. `symptoms`는 1-5개 문자열 배열
5. `date`는 YYYY-MM-DD 형식
6. `tags`는 1개 이상 문자열 배열
