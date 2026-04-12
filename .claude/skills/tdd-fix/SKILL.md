---
name: tdd-fix
description: "Test-Driven 자율 버그 수정 루프. 진단→실패테스트→수정→통과까지 반복. Use when: 버그 수정 시 테스트 기반 검증이 필요한 경우"
effort: medium
preconditions:
  - 사용자가 버그/이슈를 보고한 상태
allowed-tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Bash
  - Grep
  - Glob
  - Task
  - mcp__serena__find_symbol
  - mcp__serena__get_symbols_overview
  - mcp__serena__find_referencing_symbols
  - mcp__serena__search_for_pattern
  - mcp__serena__read_memory
  - mcp__serena__write_memory
  - mcp__historian__get_error_solutions
  - mcp__historian__find_similar_queries
  - mcp__praetorian__praetorian_compact
user-invocable: true
context: fork
---

# TDD Fix Skill

> 진단 → 실패 테스트 → 수정 → 테스트 통과 — 자율 루프

## WHY

Insights 분석: 131 bug fix 세션 + 112 buggy_code 마찰.
근본 원인: error-fixer가 "코드만 수정"하고 테스트로 검증하지 않아 잘못된 수정이 반복됨.
test-creator와 error-fixer를 체인으로 연결하면 수정 정확도가 올라간다.

## 핵심 규칙

1. **테스트 먼저** — 수정 전에 반드시 실패 테스트 작성
2. **최대 3회 루프** — 3번째 수정에도 테스트 실패 시 사용자에게 보고
3. **최소 수정** — 테스트 통과하는 최소한의 코드만 변경
4. **빌드 검증** — 루프 종료 후 pnpm build + tsc 필수

## 4-Phase 프로세스

### Phase 1: 진단 (직접 수행, 2분 이내)

```
1. historian/get_error_solutions → 과거 유사 에러 검색
2. Grep docs/solutions/ → 솔루션 문서 검색
3. 코드 경로 추적 (Grep + serena/find_symbol)
4. 근본 원인 특정 (파일:라인)
```

**출력:**
```
## 진단 결과

**근본 원인:** [기술적 설명]
**위치:** [파일:라인]
**증거:** [해당 코드가 문제인 이유]

Phase 2로 진행합니다.
```

진단 실패 시 (원인 불명확) → 사용자에게 보고 후 `/diagnose` 전환 권장.

### Phase 2: 실패 테스트 작성 (test-creator 위임)

```
Task(
  subagent_type: "04-implementation/test-creator",
  prompt: "다음 버그를 재현하는 실패 테스트를 작성하세요:
    - 버그: {Phase 1 진단 결과}
    - 위치: {파일:라인}
    - 기대 동작: {정상 동작}
    - 현재 동작: {버그 동작}

    테스트는 반드시 현재 코드에서 FAIL해야 합니다.
    테스트를 작성하고 실행하여 FAIL을 확인하세요.
    테스트 파일 경로와 실패 메시지를 보고하세요."
)
```

**검증:** test-creator가 보고한 테스트를 Bash로 직접 실행하여 FAIL 확인.
FAIL이 아니면 (이미 PASS) → 버그가 아니거나 테스트가 잘못됨 → 사용자에게 보고.

### Phase 3: 수정 루프 (error-fixer 위임, 최대 3회)

```
FOR attempt IN 1..3:
  Task(
    subagent_type: "99-utils/error-fixer",
    prompt: "다음 테스트를 통과시키기 위해 코드를 수정하세요:
      - 테스트 파일: {Phase 2 테스트 경로}
      - 테스트 실행 명령: {test command}
      - 근본 원인: {Phase 1 진단}
      - 수정 범위: {관련 파일만}

      수정 후 해당 테스트를 실행하여 PASS를 확인하세요.
      전체 테스트 스위트도 실행하여 회귀가 없는지 확인하세요."
  )

  # 직접 검증
  Bash: {test command}

  IF PASS → Phase 4로 이동
  IF FAIL → 다음 attempt (error-fixer에게 이전 실패 정보 전달)
```

**3회 실패 시:**
```
## 자율 수정 실패 (3/3 시도)

**시도 1:** [수정 내용] → [실패 이유]
**시도 2:** [수정 내용] → [실패 이유]
**시도 3:** [수정 내용] → [실패 이유]

수동 개입이 필요합니다. 수정 방향을 지정해주세요.
```

### Phase 4: 최종 검증

```
1. Bash: pnpm build (빌드 성공 확인)
2. Bash: pnpm tsc --noEmit (타입 에러 0개)
3. Bash: {full test suite} (전체 회귀 없음)
4. praetorian_compact (세션 압축)
```

**출력:**
```
## TDD Fix 완료

**버그:** [버그 설명]
**근본 원인:** [파일:라인 — 원인]
**수정:** [변경 파일 목록 — 변경 내용]
**테스트:** [새 테스트 파일 — PASS]
**빌드:** PASS
**시도 횟수:** {N}/3

커밋할까요?
```

## 서비스 감지

Phase 1에서 반드시 서비스 경계를 특정:
- `apps/mcp-orbit/` → Python + pytest
- `apps/ai-agent/` → TypeScript + jest/vitest
- 테스트 명령어가 서비스마다 다름

## 사용 예시

```
사용자: 채팅에서 메시지 전송 후 목록이 갱신되지 않는 버그가 있어
→ /tdd-fix 실행
→ Phase 1: chat.api.ts:42 — mutation 후 invalidateQueries 누락 진단
→ Phase 2: test-creator가 "메시지 전송 후 목록 갱신" 실패 테스트 작성
→ Phase 3: error-fixer가 invalidateQueries 추가 → 테스트 PASS
→ Phase 4: pnpm build PASS → 커밋 제안
```

## Scope 관리

- 진단된 버그 1건만 수정 (다른 버그 발견 시 보고만)
- error-fixer에게 전달하는 수정 범위를 관련 파일로 제한
- 테스트 파일 외에 새 파일 생성 금지
