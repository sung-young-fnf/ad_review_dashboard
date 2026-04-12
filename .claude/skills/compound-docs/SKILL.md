---
name: compound-docs
description: "문제 해결 후 솔루션을 docs/solutions/에 구조화 문서로 기록. 지식 복리 효과를 위한 핵심 스킬. Use when: 문제 해결 완료, 비자명 솔루션, 세션 간 지식 보존 필요"
effort: low
preconditions:
  - 문제가 해결된 상태 (진행 중 아님)
  - 솔루션이 검증된 상태
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - mcp__serena__write_memory
  - mcp__serena__read_memory
  - mcp__serena__list_memories
  - mcp__historian__get_error_solutions
context: fork
---

# Compound Docs Skill

> "각 작업 단위가 후속 작업을 더 쉽게 만드는" 지식 복리 시스템

## 개요

문제 해결 직후 솔루션을 `docs/solutions/` 에 구조화하여 기록.
다음 세션에서 유사 문제 발생 시 즉시 참조 가능하도록 검색 가능한 지식 베이스 구축.

**복리 효과:**
1. 첫 번째 N+1 쿼리 해결 → 리서치 30분
2. 솔루션 문서화 → 5분
3. 다음 유사 문제 → 조회 2분
4. 지식이 복리로 축적 → 팀 전체가 빨라짐

## 구조

```
docs/solutions/
  ├── build-errors/
  ├── runtime-errors/
  ├── performance-issues/
  ├── database-issues/
  ├── security-issues/
  ├── api-integration/
  ├── ui-bugs/
  ├── auth-issues/
  ├── deployment-issues/
  └── patterns/
      └── critical-patterns.md  # 필수 참조 패턴 (승격된 것만)
```

## 7-Step 프로세스

### Step 1: 트리거 감지

**자동 트리거 (대화 중):**
- "해결됐다", "고쳤다", "작동한다", "문제 해결"
- error-fixer 완료 후
- code-writer가 BLOCKER 수정 완료 후

**수동 트리거:** `/compound`

**문서화 대상 (비자명 문제만):**
- 여러 조사 시도가 필요했던 문제
- 근본 원인이 비직관적인 문제
- 다음 세션에서 반복될 가능성 있는 문제

**스킵 대상:**
- 단순 오타, 명백한 구문 에러
- 즉시 수정된 사소한 문제

### Step 2: 컨텍스트 수집

대화 히스토리에서 추출:

**필수 정보:**
- **모듈/컴포넌트**: 어디서 문제가 발생했는가
- **증상**: 관찰된 에러/동작 (정확한 에러 메시지)
- **조사 시도**: 시도했지만 실패한 접근법과 그 이유
- **근본 원인**: 기술적 설명
- **솔루션**: 수정한 내용 (코드/설정 변경)
- **예방**: 향후 방지 방법

**BLOCKING**: 필수 정보 누락 시 사용자에게 질문 후 대기

### Step 3: 기존 문서 확인

```bash
# 유사 이슈 검색
Grep "에러 키워드" docs/solutions/
```

**유사 이슈 발견 시:**
- 새 문서 생성 + 교차 참조 (권장)
- 기존 문서 업데이트 (동일 근본 원인일 때만)

**미발견 시:** Step 4로 직행

### Step 4: 파일명 생성

형식: `{sanitized-symptom}-{module}-{YYYYMMDD}.md`

예시:
- `n-plus-one-brief-generation-20260211.md`
- `api-chain-mismatch-chat-service-20260211.md`
- `prisma-migration-drift-agent-schema-20260211.md`

### Step 5: YAML 스키마 검증

모든 문서는 YAML 프론트매터 필수. [yaml-schema.md](./references/yaml-schema.md) 참조.

**검증 실패 시 BLOCK** - Step 6 진행 불가.

### Step 6: 문서 생성

[solution-template.md](./assets/solution-template.md) 템플릿 사용.

카테고리 매핑:
| problem_type | 카테고리 디렉토리 |
|-------------|----------------|
| build_error | build-errors/ |
| runtime_error | runtime-errors/ |
| performance_issue | performance-issues/ |
| database_issue | database-issues/ |
| security_issue | security-issues/ |
| api_integration | api-integration/ |
| ui_bug | ui-bugs/ |
| auth_issue | auth-issues/ |
| deployment_issue | deployment-issues/ |

```bash
mkdir -p "docs/solutions/${CATEGORY}"
# solution-template.md 기반으로 문서 생성
```

### Step 7: 교차 참조 + 패턴 감지

**교차 참조**: Step 3에서 유사 이슈 발견 시 양쪽에 링크 추가.

**패턴 승격 (수동)**: 3+ 유사 이슈 존재 시 `patterns/critical-patterns.md`에 추가 제안.

## 완료 메뉴

```
✓ 솔루션 문서화 완료

파일 생성:
- docs/solutions/{category}/{filename}.md

다음:
1. 워크플로우 계속 (권장)
2. 필수 참조로 승격 (critical-patterns.md에 추가)
3. 관련 문서 연결
4. Serena 메모리에도 저장
5. 문서 확인
```

## 기존 Memory MCP와의 역할 분담

| 저장소 | 용도 | 형태 |
|--------|------|------|
| **docs/solutions/** (신규) | 풍부한 문맥의 솔루션 문서 | 마크다운 + YAML |
| serena/write_memory | 아키텍처 결정, 핵심 패턴 | 키-값 메모리 |
| historian | 과거 에러 검색 | 자동 인덱싱 |
| praetorian | 세션 압축 | TOON 형식 |

**상호보완:**
- `docs/solutions/`에 풍부한 문서 → serena에 키-값 요약 저장
- historian이 자동 인덱싱 → docs/solutions/에서 상세 참조
- praetorian이 세션 압축 → docs/solutions/이 풀 컨텍스트 보존

## 성공 기준

- YAML 프론트매터 검증 통과
- `docs/solutions/{category}/{filename}.md` 생성
- 코드 예시 포함 (before/after)
- 교차 참조 추가 (유사 이슈 존재 시)
- 사용자에게 완료 메뉴 제시
