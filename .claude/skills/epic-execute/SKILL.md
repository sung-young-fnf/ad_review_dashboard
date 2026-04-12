---
name: epic-execute
description: "Epic 풀 파이프라인 — 분석→기획→설계→구현→검증 5단계 자동 실행. Use when: Epic 구현 시작, 대규모 기능 개발"
effort: high
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
  - TeamCreate
  - SendMessage
  - AskUserQuestion
  - mcp__serena__read_memory
  - mcp__serena__write_memory
  - mcp__serena__find_symbol
  - mcp__serena__get_symbols_overview
  - mcp__praetorian__praetorian_compact
user-invocable: true
context: fork
---

# Epic Execute — Full Pipeline

> 요청 하나로 분석→기획→설계→구현→검증 5단계 자동 실행

## WHY

기존: Epic 문서 준비 → Story 분해 → Task 설계 → 수동 구현 → 수동 검증 = 수시간 수동 조율
신규: `/epic-execute` 한 번이면 5단계 Squad 파이프라인이 자동 실행, 각 Phase 산출물 있으면 자동 스킵

## 파이프라인 개요

```
Phase 0: 입력 분석 + 파이프라인 계획
    ↓
Phase 1: ANALYSIS — 코드베이스 사전분석 (analysis-squad)
    ↓
Phase 2: PLANNING — Epic/Story 생성 (planning-squad)
    ↓
Phase 3: DESIGN — Task 분해 + 검증 (design-squad)
    ↓
Phase 4: IMPLEMENTATION — 코드 구현 (epic-squad / story-squad)
    ↓
Phase 5: QUALITY — 품질 검증 (quality-squad)
    ↓
Phase 6: COMPLETION — 완료 리포트 + 커밋
```

## Phase 자동 스킵 규칙

각 Phase는 산출물 존재 여부로 스킵 판단:

| Phase | 산출물 | 스킵 조건 |
|-------|--------|----------|
| 1. ANALYSIS | 분석 보고서 | 사용자가 `--skip-analysis` 또는 이미 분석 완료 |
| 2. PLANNING | `docs/epics/EP{XXX}/epic.md` + Story 파일 | Epic 문서 이미 존재 |
| 3. DESIGN | `docs/epics/EP{XXX}/tasks/` Task 파일 | Task 파일 이미 존재 |
| 4. IMPLEMENTATION | 코드 변경 | 구현 완료 Story는 스킵 |
| 5. QUALITY | 품질 보고서 | 사용자가 `--skip-quality` |

---

## Phase 0: 입력 분석 + 파이프라인 계획 (1분)

사용자 입력을 분석하여 어떤 Phase부터 시작할지 결정:

```
1. 입력 파싱:
   - Epic ID가 있으면? → docs/epics/EP{XXX}/ 확인
   - 새 요구사항이면? → Phase 1부터 시작
   - "--from-phase N" 지정? → Phase N부터 시작

2. 산출물 스캔:
   - docs/epics/EP{XXX}/epic.md 존재? → Phase 2 스킵 가능
   - docs/epics/EP{XXX}/tasks/ 존재? → Phase 3 스킵 가능
   - Story 구현 상태 확인 (Grep으로 코드 검증)

3. 파이프라인 계획 출력:
```

**출력 예시:**
```
## Epic Pipeline 계획

**입력:** "채팅 스트리밍 성능 개선"
**Epic ID:** EP149 (신규 생성)

📋 파이프라인:
  Phase 1: ANALYSIS    → 🔄 실행 예정 (analysis-squad)
  Phase 2: PLANNING    → 🔄 실행 예정 (planning-squad)
  Phase 3: DESIGN      → 🔄 실행 예정 (design-squad)
  Phase 4: IMPLEMENT   → 🔄 실행 예정 (epic-squad)
  Phase 5: QUALITY     → 🔄 실행 예정 (quality-squad)

**예상 시간:** 분석 5분 → 기획 15분 → 설계 10분 → 구현 2-4시간 → 검증 5분
**예상 비용:** ~8x (전체 파이프라인)

진행할까요? (전체 / Phase 선택 / 취소)
```

---

## Phase 1: ANALYSIS (5분)

> 코드베이스 사전분석으로 기획 품질 향상

```
[산출물 존재?] ──Yes──→ ⏭️ SKIP → Phase 2
      │
      No
      ↓
[Squad 판단] 대상 넓으면 analysis-squad, 좁으면 Solo
      ↓
Task(
  subagent_type="Explore",    # Solo: Pre-Flight Scanner
  # 또는 Squad: analysis-coordinator + 병렬 Agent
  prompt="코드베이스 사전분석: {요구사항 키워드}"
)
      ↓
분석 보고서 수신 → Phase 2에 전달
```

**산출물:**
- 코드 구조/의존성 요약
- 이미 구현된 기능 목록 (IMPLEMENTED / PARTIAL / NOT_FOUND)
- 재사용 가능 패턴/유틸리티
- 기술 부채/보안 취약점 (있으면)

---

## Phase 2: PLANNING (15분)

> 분석 결과를 기반으로 Epic/Story 생성

```
[docs/epics/EP{XXX}/ 존재?] ──Yes──→ ⏭️ SKIP → Phase 3
      │
      No
      ↓
[Squad 판단] 5+ Story 예상 / 크로스도메인 / UX 영향 → planning-squad
             그 외 → Solo (epic-creator + story-creator)
      ↓
# Solo 모드:
Task(subagent_type="02-requirements/01-epic-creator", prompt="...")
Task(subagent_type="02-requirements/story-creator", prompt="...")

# Squad 모드:
TeamCreate(team_name="planning-EP{XXX}-{date}")
  → planner + code-scanner + ux-advisor(조건부)
      ↓
Epic 문서 + Story 문서 생성 → story-validator 체인
      ↓
사용자에게 Story 목록 확인 요청 (BLOCKING)
```

**산출물:**
- `docs/epics/EP{XXX}/epic.md`
- `docs/epics/EP{XXX}/stories/S01-*.md` ~ `S{N}-*.md`
- Story 목록 + AC + 의존성

---

## Phase 3: DESIGN (10분)

> Story → Task 분해 + 검증 + 플로우 분석

```
[docs/epics/EP{XXX}/tasks/ 존재?] ──Yes──→ ⏭️ SKIP → Phase 4
      │
      No
      ↓
[Squad 판단] 5+ Task 예상 / 크로스도메인 → design-squad
             그 외 → Solo (task-planner)
      ↓
FOR story IN stories:
  Task(subagent_type="03-design/task-planner", prompt="Story → Task 분해")
      ↓
# Squad 모드 시 병렬:
  task-validator: AC 커버리지 검증
  spec-flow-analyzer: 플로우 완전성 검증
      ↓
Task 문서 최종 확정
```

**산출물:**
- `docs/epics/EP{XXX}/tasks/T001-*.md` ~ `T{N}-*.md`
- Task 간 의존성 DAG

---

## Phase 4: IMPLEMENTATION (2-8시간)

> Task를 순차/병렬 실행하여 코드 구현

```
1. Story + Task 의존성 분석
2. 병렬 가능 Story 그룹 (Wave) 식별
3. 사용자에게 실행 계획 보고 (BLOCKING)
```

**출력:**
```
## 구현 계획

**Story 총 {N}개:**
- Wave 1 (병렬): S01, S02 (의존성 없음)
- Wave 2 (병렬): S03, S04 (Wave 1 완료 후)
- Wave 3 (순차): S05 (S03+S04 완료 후)

**예상 Squad:** {scale} ({N}명)
**Inter-Story Test Gate:** 각 Wave 완료 후 pnpm build + tsc

진행할까요?
```

**실행:**

**Solo 모드 (Story 3개 이하):**
```
FOR story IN approved_stories:
  code-writer 실행 (순차)
  Inter-Story Test Gate:
    pnpm build && pnpm tsc --noEmit
    [Backend DTO 변경 시] export-openapi.sh + pnpm generate:api
  체크포인트 리포트
  커밋 제안
```

**Squad 모드 (Story 4개+):**
```
1. TeamCreate(team_name="epic-EP{XXX}-{date}")
2. Story별 Task 생성 (TaskCreate)
3. 의존성 설정 (addBlockedBy)
4. Wave별 병렬 실행
5. 각 Wave 완료 후 Test Gate
```

**체크포인트 (각 Story 완료 후):**
```
## Checkpoint: Story S{XX} 완료

**수정 파일:** {N}개
**TypeScript 에러:** 0
**빌드:** PASS
**커밋:** {hash} - {message}

**진행률:** {완료}/{전체} Stories ({%})
**다음:** S{YY} 시작 가능

계속할까요?
```

---

## Phase 5: QUALITY (5분)

> 구현 완료 후 품질 검증

```
[사용자가 --skip-quality?] ──Yes──→ ⏭️ SKIP → Phase 6
      │
      No
      ↓
[Squad 판단] 5+ Task 구현 / 보안 관련 → quality-squad
             그 외 → Solo (implementation-validator)
      ↓
# Squad 모드: 병렬 검증
Task(subagent_type="general-purpose", name="impl-validator", prompt="...")
Task(subagent_type="general-purpose", name="perf-checker", prompt="...")
Task(subagent_type="general-purpose", name="security-checker", prompt="...")

# Solo 모드:
Task(subagent_type="05-quality/implementation-validator", prompt="...")
      ↓
[P0 이슈?] ──Yes──→ error-fixer 즉시 위임 → 수정 후 재검증
      │
      No
      ↓
품질 보고서 생성
```

**산출물:**
```
## 품질 검증 결과

| 항목 | 결과 |
|------|------|
| AC 달성 | ✅ 12/12 |
| API 무결성 | ✅ |
| N+1 쿼리 | ✅ 0건 |
| 보안 취약점 | ✅ 0건 |
| 빌드 | ✅ PASS |

**판정: ✅ 통과**
```

---

## Phase 6: COMPLETION

**모든 Phase 완료 시:**
```
## Epic EP{XXX} 풀 파이프라인 완료

📊 파이프라인 실행 결과:
  Phase 1: ANALYSIS    → ✅ 완료 (5분)
  Phase 2: PLANNING    → ✅ 완료 (12분) — {N} Stories 생성
  Phase 3: DESIGN      → ✅ 완료 (8분) — {M} Tasks 생성
  Phase 4: IMPLEMENT   → ✅ 완료 (2시간) — {K} 커밋
  Phase 5: QUALITY     → ✅ 통과

**총 수정 파일:** {X}개
**총 커밋:** {Y}개
**TypeScript 에러:** 0
**빌드:** PASS

다음 단계:
1. 커밋 확인 및 푸시
2. deployment-watcher 실행
3. epic-completion-manager 호출
```

**praetorian_compact 호출:** 세션 압축

---

## 핵심 규칙

1. **Phase 0 승인 없이 파이프라인 시작 금지** — 사용자가 계획을 확인해야 함
2. **Phase 4 실행 전 재승인** — 구현 시작 전 Story/Task 목록 최종 확인
3. **Inter-Story Test Gate 실패 시 다음 Story 진행 금지**
4. **각 Phase 완료 후 체크포인트 리포트**
5. **P0 이슈 발견 시 파이프라인 중단** — error-fixer로 즉시 수정 후 재개
6. **praetorian_compact**: 각 Phase 완료 후 세션 압축

## Solo vs Squad 자동 결정

각 Phase에서 독립적으로 Solo/Squad 판단:

| Phase | Solo 조건 | Squad 조건 |
|-------|----------|-----------|
| ANALYSIS | 대상 모듈 2개 이하 | 대상 넓음 / 새 도메인 |
| PLANNING | Story 예상 4개 이하 | 5+ Story / 크로스도메인 / UX 영향 |
| DESIGN | Task 예상 4개 이하 | 5+ Task / 복잡 플로우 |
| IMPLEMENTATION | Story 3개 이하 | Story 4개+ |
| QUALITY | Task 3개 이하 | 5+ Task / 보안 관련 |

## 부분 실행

사용자가 특정 Phase만 실행할 수 있음:
- `/epic-execute` → 전체 파이프라인 (기본)
- `/epic-execute --from-phase 4` → Phase 4(구현)부터 시작
- `/epic-execute --skip-analysis --skip-quality` → 분석/검증 생략
- `/epic-execute EP148` → 기존 Epic 이어서 실행 (산출물 있는 Phase 자동 스킵)

## Scope 관리

- Epic 문서에 명시된 범위만 실행
- 각 Phase에서 새 요구사항 발견 시 → 보고 후 백로그 추가
- 범위 확장은 사용자 승인 필수
- 파이프라인 중 어느 시점에서든 "중단" 가능
