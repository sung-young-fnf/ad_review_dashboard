---
name: diagnose
description: "버그/이슈 진단 전용 모드. 코드 변경 없이 근본 원인만 분석. Use when: 버그 리포트, '왜 X가 안 되는지', 원인 파악 필요"
effort: high
preconditions:
  - 사용자가 버그/이슈를 보고한 상태
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - mcp__serena__find_symbol
  - mcp__serena__get_symbols_overview
  - mcp__serena__find_referencing_symbols
  - mcp__serena__search_for_pattern
  - mcp__serena__read_memory
  - mcp__historian__get_error_solutions
  - mcp__historian__find_similar_queries
user-invocable: true
context: fork
---

# Diagnose Skill

> "수정하기 전에 원인을 찾아라" — wrong_approach 133건의 근본 해결

## Pre-injected Context (Dynamic Context Injection)

**최근 에러 히스토리:**
!`tail -30 .claude/learnings/ERRORS.md 2>/dev/null || echo "(에러 기록 없음)"`

**최근 변경 파일:**
!`git log --oneline -5 2>/dev/null`
!`git diff --name-only HEAD~3..HEAD 2>/dev/null | head -15`

**현재 브랜치 + 상태:**
!`git branch --show-current 2>/dev/null` / !`git status --short 2>/dev/null | head -10`

## WHY

Insights 분석 결과, 최대 마찰 원인은 **진단 없이 수정 시도** (wrong_approach 133건 + misunderstood_request 79건).
이 스킬은 **코드 변경을 금지**하고 근본 원인 분석에만 집중하도록 강제한다.

## 핵심 규칙

1. **코드 변경 절대 금지** — Edit, Write, NotebookEdit 사용 불가
2. **실행/호출 금지** — 문제가 되는 기능을 직접 실행하지 않음
3. **Pre-injected 에러 히스토리를 먼저 참조** — 유사 이슈 즉시 매칭
3. **진단만 수행** — 코드 추적, 로그 분석, 데이터 흐름 파악

## 5-Step 진단 프로세스

### Step 1: 증상 명확화

```
**증상:** [사용자가 관찰한 정확한 동작]
**기대 동작:** [정상적으로 작동해야 하는 방식]
**재현 조건:** [언제/어떤 상황에서 발생하는지]
```

사용자가 불명확하면 질문으로 명확화. 추측하지 않음.

### Step 2: 과거 지식 검색 (Local-First)

```bash
# 1차: 솔루션 문서 검색
Grep "관련 키워드" docs/solutions/

# 2차: historian 에러 검색
historian/get_error_solutions "에러 메시지"

# 3차: serena 메모리 검색
serena/read_memory "관련 메모리"
```

유사 이슈가 있으면 즉시 보고. 새로운 이슈면 Step 3으로.

### Step 3: 코드 경로 추적

**Top-Down 추적:**
1. 진입점 찾기 (API endpoint, UI handler, event listener)
2. 호출 체인 따라가기 (serena/find_referencing_symbols)
3. 분기 조건 확인 (if/else, try/catch, guard clauses)
4. 데이터 변환 지점 확인 (DTO, mapper, serializer)

**Bottom-Up 추적 (진입점 불명확 시):**
1. 에러 메시지/로그에서 키워드 Grep
2. 해당 코드의 호출자 추적 (find_referencing_symbols)
3. 조건 분기에서 실패 경로 식별

### Step 4: 근본 원인 보고

```
## 진단 결과

**근본 원인:** [기술적 설명 1-2문장]

**증거:**
- [파일:라인] — [해당 코드가 문제인 이유]
- [파일:라인] — [연관된 코드]

**영향 범위:** [이 버그가 영향을 주는 다른 기능]

**수정 방안 (제안):**
1. [방안 A] — [장단점]
2. [방안 B] — [장단점]

**추천:** [방안 X] — [근거]
```

### Step 5: 사용자 결정 대기

진단 보고 후 **반드시 사용자 승인을 기다림**:
- "수정 진행할까요?" → error-fixer 또는 code-writer로 핸드오프
- "더 조사해줘" → 추가 분석
- "다른 방향으로" → 방향 전환

## 완료 기준

- 근본 원인이 코드 레벨에서 특정됨 (파일:라인)
- 수정 방안이 1개 이상 제시됨
- 사용자가 다음 단계를 결정함
- **코드 변경 0건** (이 스킬에서는 절대 수정하지 않음)
