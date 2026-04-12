# PARALLEL EXECUTION GUIDE (병렬 실행 완전 가이드)

> **핵심**: Task는 기본적으로 병렬, 의존성 있을 때만 순차

이 문서는 Agent와 TodoWrite에서 병렬 실행을 적용하는 완전한 가이드입니다.

---

## 🎯 병렬 실행 우선 원칙

**모든 Task 실행 전 필수 체크**:
1. ✅ Task 간 의존성 분석
2. ✅ 독립적 Task 식별
3. ✅ 병렬 그룹 생성
4. ✅ 단일 메시지로 동시 실행
5. ✅ 예상 시간 비교 (병렬 vs 순차)

---

## 📊 병렬 가능 여부 판단 체크리스트

```yaml
병렬 실행 가능 (✅):
  - [ ] 서로 다른 파일 수정
  - [ ] 독립적인 기능 구현
  - [ ] 의존성 없는 API 엔드포인트
  - [ ] 별도 컴포넌트/모듈
  - [ ] 서로 다른 테스트 스위트

순차 실행 필요 (❌):
  - [ ] 이전 Task 결과 의존
  - [ ] 같은 파일 수정
  - [ ] DB 마이그레이션 → 모델 코드
  - [ ] 인증 구현 → 보호된 API
  - [ ] 타입 정의 → 구현 코드
```

---

## 💡 병렬 실행 패턴

### Pattern 1: Agent 병렬 실행

```typescript
// ❌ 잘못된 패턴 (순차 실행)
await Task({ subagent_type: "code-writer", prompt: "T001 구현" });
// 기다림... (5분)
await Task({ subagent_type: "code-writer", prompt: "T002 구현" });
// 기다림... (5분)
await Task({ subagent_type: "code-writer", prompt: "T003 구현" });
// 총 15분

// ✅ 올바른 패턴 (병렬 실행)
// 단일 메시지에 여러 Task tool 호출
[
  Task({ subagent_type: "code-writer", prompt: "T001 구현", description: "T001" }),
  Task({ subagent_type: "code-writer", prompt: "T002 구현", description: "T002" }),
  Task({ subagent_type: "code-writer", prompt: "T003 구현", description: "T003" })
]
// 동시 실행! 총 5분 (3배 빠름)
```

### Pattern 2: Epic 내 Story 병렬화

```yaml
# Epic E003: 4개 Story 의존성 분석

의존성 분석:
  S01 (UI 컴포넌트): 독립적 ✅
  S02 (Backend API): 독립적 ✅
  S03 (통합 테스트): S01, S02 의존 ❌
  S04 (문서화): S01, S02, S03 의존 ❌

병렬 그룹:
  Group 1 (병렬): [S01, S02] → 동시 실행
  Group 2 (순차): S03 → S01, S02 완료 후
  Group 3 (순차): S04 → S03 완료 후

실행 전략:
  ✅ [S01, S02] 병렬 실행 (2배 빠름)
  → 완료 대기
  ✅ S03 실행
  → 완료 대기
  ✅ S04 실행

예상 시간: 12분 (병렬) vs 25분 (순차)
```

### Pattern 3: 복합 Task 병렬화

```yaml
# 복잡한 Task 분해 및 병렬화

Original Task: "사용자 프로필 페이지 구현"

분해 (의존성 분석):
  T001: 프로필 UI 컴포넌트 (독립적)
  T002: API 엔드포인트 (독립적)
  T003: 이미지 업로드 (독립적)
  T004: 통합 (T001, T002, T003 의존)

병렬 실행:
  ✅ [T001, T002, T003] 동시 실행 (3배 빠름)
  → 완료 대기
  ✅ T004 실행

예상 시간: 8분 (병렬) vs 20분 (순차)
```

---

## 🚨 강제 규칙 (Hard Rules)

### 1. 의존성 명시 필수

```yaml
모든 Task 정의 시:
  dependencies: [의존하는 Task ID]

예시:
  T001:
    dependencies: []  # 독립적
  T002:
    dependencies: []  # 독립적
  T003:
    dependencies: [T001, T002]  # T001, T002 완료 필요
```

### 2. 병렬 실행 선언

```yaml
병렬 가능 Task 발견 시:
  → "✅ 병렬 실행 가능: [T001, T002, T003]"
  → 단일 메시지로 동시 Task tool 호출
  → "⏱️ 예상 시간: 5분 (병렬) vs 15분 (순차)"
```

### 3. Agent 체인에서 병렬 처리

```yaml
# task-planner Agent 출력

Task 분해 결과:
  총 10개 Task
  병렬 그룹 3개
  예상 완료 시간: 8분 (병렬) vs 25분 (순차)

Group 1 (병렬 4개): [T001, T002, T003, T004]
Group 2 (병렬 3개): [T005, T006, T007]
Group 3 (병렬 2개): [T008, T009]
Group 4 (순차 1개): T010 (전체 통합)

code-writer 실행 계획:
  ✅ Group 1 → 단일 메시지로 4개 병렬 실행
  ✅ Group 2 → 단일 메시지로 3개 병렬 실행
  ✅ Group 3 → 단일 메시지로 2개 병렬 실행
  ✅ Group 4 → T010 단독 실행
```

---

## 🆕 Async Agents (Claude Code 2.0.64+)

> **새 기능**: Agent와 Bash가 비동기 실행되고, 메인 에이전트에 완료 알림 가능

### 비동기 실행 패턴

#### Pattern 1: Background Agent 실행

```typescript
// 기존: 순차 실행 (블로킹)
const result1 = await Task({ subagent_type: "code-writer", prompt: "..." });
const result2 = await Task({ subagent_type: "test-creator", prompt: "..." });

// 🆕 새 패턴: 비동기 실행 (논블로킹)
Task({
  subagent_type: "code-writer",
  prompt: "...",
  run_in_background: true  // ← 백그라운드 실행
});
// 즉시 다음 작업 진행 가능!

// 결과 필요 시 AgentOutputTool로 수신
AgentOutputTool({ agentId: "...", block: true });
```

#### Pattern 2: 메인 에이전트 Wake-up

```yaml
# 비동기 Agent 완료 → 메인 에이전트에 메시지 전송

시나리오:
  1. Main Agent: code-writer 백그라운드 실행
  2. Main Agent: 다른 작업 수행 (리서치, 문서화 등)
  3. code-writer 완료 → 메인 에이전트에 알림
  4. Main Agent: 결과 수신 후 다음 단계 진행

효과:
  - 블로킹 대기 시간 제거
  - 유휴 시간 활용
  - 더 유연한 병렬 처리
```

#### Pattern 3: 혼합 전략 (병렬 + 비동기)

```yaml
# 최적의 조합

Group 1 (동시 병렬):
  - [T001, T002, T003] 단일 메시지로 동시 실행

Background (비동기):
  - T004: 장시간 테스트 → run_in_background: true

Main Thread:
  - Group 1 완료 대기
  - 문서 업데이트 (T004 대기 안 함)
  - T004 완료 알림 수신 시 통합

효율: 기존 병렬보다 20-30% 추가 개선
```

### 비동기 체크리스트

```yaml
비동기 실행 적합 (✅):
  - [ ] 장시간 실행 Task (테스트, 빌드)
  - [ ] 메인 작업과 독립적
  - [ ] 결과 즉시 필요 없음
  - [ ] 다른 작업 동시 진행 가능

동기 실행 유지 (❌):
  - [ ] 결과 즉시 필요
  - [ ] 다음 Task의 입력 데이터
  - [ ] 에러 시 즉시 중단 필요
```

---

## 📋 병렬 실행 체크리스트 (모든 Task 실행 전)

```yaml
1. ⛔ Task 의존성 분석 완료?
   → NO → 의존성 분석 필수

2. ⛔ 독립적 Task 존재?
   → YES → 병렬 그룹 생성

3. ⛔ 병렬 그룹 크기 2개 이상?
   → YES → 단일 메시지로 동시 실행

4. ⛔ 순차 실행 필요한 이유 명시?
   → YES (의존성) → 순차 실행
   → NO → 병렬 실행 필수 (VIOLATION)
```

---

## 💡 실전 예시

### 예시 1: Story S01~S04 병렬 분석

```yaml
User: "Epic E003 Story S01~S04 구현"

task-planner 분석:
  S01: UI 컴포넌트 (독립적)
  S02: Backend API (독립적)
  S03: DB 스키마 (독립적)
  S04: 통합 테스트 (S01, S02, S03 의존)

병렬 전략:
  ✅ [S01, S02, S03] 병렬 실행 (단일 메시지)
  → 완료 대기 (약 5분)
  ✅ S04 실행 (약 2분)

총 예상 시간: 7분 (병렬) vs 20분 (순차)
효율: 3배 빠름!
```

### 예시 2: 10개 Task 병렬화

```yaml
task-planner 출력:

총 10개 Task 분해 완료

의존성 분석 결과:
  Group 1 (병렬 5개):
    - T001: 로그인 UI
    - T002: 회원가입 UI
    - T003: 비밀번호 재설정 UI
    - T004: 프로필 UI
    - T005: 설정 UI

  Group 2 (병렬 3개):
    - T006: 인증 API
    - T007: 사용자 API
    - T008: 프로필 API

  Group 3 (순차 2개):
    - T009: 통합 테스트 (depends: T001-T008)
    - T010: E2E 테스트 (depends: T009)

실행 계획:
  ⏱️ Group 1 병렬 실행 → 6분
  ⏱️ Group 2 병렬 실행 → 4분
  ⏱️ Group 3 순차 실행 → 5분

총 예상 시간: 15분 (병렬) vs 45분 (순차)
효율: 3배 빠름!

🚀 병렬 실행을 시작할까요?
```

---

## ⚠️ Anti-patterns (금지)

```yaml
❌ 잘못된 예시 1: 병렬 가능한데 순차 실행
User: "S01, S02 구현"
Assistant: "S01 먼저 구현하고, 완료 후 S02 구현하겠습니다"
→ VIOLATION: 의존성 없으면 병렬 필수

❌ 잘못된 예시 2: 병렬 실행 없이 예상 시간만 언급
Assistant: "예상 시간: 15분 (순차 실행)"
→ VIOLATION: 병렬 가능 여부 분석 누락

❌ 잘못된 예시 3: 의존성 분석 없이 무작정 순차
Assistant: "T001 → T002 → T003 순서대로 진행"
→ VIOLATION: 의존성 분석 필수
```

---

## ✅ 올바른 예시

```yaml
✅ 올바른 예시 1: 병렬 분석 후 실행
User: "S01, S02 구현"
Assistant:
  "의존성 분석: S01, S02 독립적 ✅
   병렬 실행: [S01, S02] 동시 진행
   예상 시간: 5분 (병렬) vs 10분 (순차)"
→ 단일 메시지로 2개 Task tool 호출

✅ 올바른 예시 2: 복잡한 Task 병렬 분해
User: "Epic E003 전체 구현"
Assistant:
  "총 10개 Task 분해
   병렬 그룹 3개 생성
   Group 1: [T001-T005] 병렬
   Group 2: [T006-T008] 병렬
   Group 3: [T009-T010] 순차
   예상 시간: 15분 (병렬) vs 45분 (순차)"
```

---

## 🔧 Agent별 병렬 처리 책임

```yaml
task-planner:
  - Task 의존성 분석
  - 병렬 그룹 생성
  - 예상 시간 계산 (병렬 vs 순차)
  - 실행 계획 수립

code-writer:
  - 병렬 그룹별 동시 실행
  - 단일 메시지로 여러 Task tool 호출
  - 완료 대기 후 다음 그룹

progress-updater:
  - 병렬 실행 상태 추적
  - 완료율 계산 (병렬 고려)
```

---

## 📋 TODO WITH PARALLEL EXECUTION

> **핵심**: TodoWrite도 병렬 그룹 명시, 여러 작업 동시 in_progress

### 🎯 TodoWrite 병렬 실행 패턴

#### Pattern 1: 병렬 그룹 명시

```typescript
// ✅ 올바른 패턴: 병렬 그룹 표시
TodoWrite([
  // 병렬 그룹 1 (동시 실행 가능)
  { content: "[병렬] T001 구현", status: "pending", activeForm: "T001 구현 중" },
  { content: "[병렬] T002 구현", status: "pending", activeForm: "T002 구현 중" },
  { content: "[병렬] T003 구현", status: "pending", activeForm: "T003 구현 중" },
  // 순차 그룹 (위 완료 후)
  { content: "T004 통합 테스트", status: "pending", activeForm: "통합 테스트 중" }
])

// 실행 시: T001, T002, T003 동시에 in_progress로 변경
TodoWrite([
  { content: "[병렬] T001 구현", status: "in_progress", activeForm: "T001 구현 중" },
  { content: "[병렬] T002 구현", status: "in_progress", activeForm: "T002 구현 중" },
  { content: "[병렬] T003 구현", status: "in_progress", activeForm: "T003 구현 중" },
  { content: "T004 통합 테스트", status: "pending", activeForm: "통합 테스트 중" }
])
```

#### Pattern 2: 의존성 명시

```typescript
TodoWrite([
  {
    content: "T001 UI 컴포넌트 (독립적)",
    status: "pending",
    activeForm: "UI 컴포넌트 구현 중"
  },
  {
    content: "T002 API 엔드포인트 (독립적)",
    status: "pending",
    activeForm: "API 구현 중"
  },
  {
    content: "T003 통합 (depends: T001, T002)",
    status: "pending",
    activeForm: "통합 작업 중"
  }
])
```

### 🚨 강제 규칙

#### 1. 병렬 가능 작업 식별

```yaml
TodoWrite 생성 시:
  1. Task 의존성 분석
  2. 독립적 Task → [병렬] 태그
  3. 의존 Task → (depends: XXX) 명시
  4. 예상 시간 계산 (병렬 vs 순차)
```

#### 2. 동시 in_progress 허용

```yaml
병렬 그룹 실행 시:
  ❌ 하나씩 in_progress → completed
  ✅ 여러 개 동시 in_progress

예시:
  [병렬] T001: pending → in_progress
  [병렬] T002: pending → in_progress
  [병렬] T003: pending → in_progress
  # 3개 동시 실행!
```

#### 3. 완료 상태 업데이트

```yaml
병렬 실행 중:
  - 각 Task 독립적으로 completed 변경
  - 순서 무관
  - 모두 완료 시 다음 그룹 시작
```

### 💡 실전 예시

#### 예시 1: Epic E003 Story 구현

```typescript
// ❌ 잘못된 Todo (순차적)
TodoWrite([
  { content: "S01 UI 컴포넌트 구현", status: "pending", activeForm: "S01 구현 중" },
  { content: "S02 Backend API 구현", status: "pending", activeForm: "S02 구현 중" },
  { content: "S03 DB 스키마 구현", status: "pending", activeForm: "S03 구현 중" },
  { content: "S04 통합 테스트", status: "pending", activeForm: "S04 테스트 중" }
])
// → 순차 실행: 20분

// ✅ 올바른 Todo (병렬 명시)
TodoWrite([
  { content: "[병렬] S01 UI 컴포넌트 구현", status: "pending", activeForm: "S01 구현 중" },
  { content: "[병렬] S02 Backend API 구현", status: "pending", activeForm: "S02 구현 중" },
  { content: "[병렬] S03 DB 스키마 구현", status: "pending", activeForm: "S03 구현 중" },
  { content: "S04 통합 테스트 (depends: S01-S03)", status: "pending", activeForm: "S04 테스트 중" }
])
// → 병렬 실행: 7분 (3배 빠름!)
```

#### 예시 2: 복잡한 작업 분해

```typescript
TodoWrite([
  // 병렬 그룹 1: 독립적 UI 작업
  { content: "[병렬 G1] 로그인 페이지 UI", status: "pending", activeForm: "로그인 UI 구현 중" },
  { content: "[병렬 G1] 회원가입 페이지 UI", status: "pending", activeForm: "회원가입 UI 구현 중" },
  { content: "[병렬 G1] 프로필 페이지 UI", status: "pending", activeForm: "프로필 UI 구현 중" },

  // 병렬 그룹 2: 독립적 API 작업
  { content: "[병렬 G2] 인증 API (depends: G1)", status: "pending", activeForm: "인증 API 구현 중" },
  { content: "[병렬 G2] 사용자 API (depends: G1)", status: "pending", activeForm: "사용자 API 구현 중" },

  // 순차: 통합 작업
  { content: "E2E 테스트 (depends: G1, G2)", status: "pending", activeForm: "E2E 테스트 중" }
])

// 예상 시간:
// - G1 병렬 실행: 6분
// - G2 병렬 실행: 4분
// - E2E 순차 실행: 3분
// 총: 13분 (순차: 35분)
```

### 📊 병렬 효율 표시

```yaml
TodoWrite 생성 시 반드시 포함:

📊 실행 계획:
  병렬 그룹 1: [T001, T002, T003] → 5분
  병렬 그룹 2: [T004, T005] → 3분
  순차 작업: T006 → 2분

총 예상 시간: 10분 (병렬) vs 25분 (순차)
효율: 2.5배 빠름!
```

### ⚠️ Anti-patterns

```typescript
// ❌ 잘못된 예시 1: 병렬 가능한데 순차로 표시
TodoWrite([
  { content: "Task 1 구현", status: "pending", activeForm: "Task 1 구현 중" },
  { content: "Task 2 구현", status: "pending", activeForm: "Task 2 구현 중" },
  { content: "Task 3 구현", status: "pending", activeForm: "Task 3 구현 중" }
])
// → 의존성 없으면 [병렬] 태그 필수!

// ❌ 잘못된 예시 2: 하나씩 in_progress
TodoWrite([
  { content: "[병렬] T001", status: "in_progress", activeForm: "T001 구현 중" },
  { content: "[병렬] T002", status: "pending", activeForm: "T002 구현 중" },  // 왜 대기?
  { content: "[병렬] T003", status: "pending", activeForm: "T003 구현 중" }
])
// → 병렬이면 모두 동시 in_progress!

// ✅ 올바른 예시
TodoWrite([
  { content: "[병렬] T001", status: "in_progress", activeForm: "T001 구현 중" },
  { content: "[병렬] T002", status: "in_progress", activeForm: "T002 구현 중" },
  { content: "[병렬] T003", status: "in_progress", activeForm: "T003 구현 중" }
])
```

### 🔧 도구별 통합

```yaml
task-planner → TodoWrite:
  1. Task 의존성 분석
  2. 병렬 그룹 생성
  3. TodoWrite에 병렬 태그 반영

code-writer → TodoWrite:
  1. 병렬 Todo 확인
  2. 단일 메시지로 여러 Task 동시 실행
  3. 각 Task 독립적으로 완료 처리

progress-updater → TodoWrite:
  1. 병렬 실행 상태 추적
  2. 완료율 계산 (병렬 고려)
```
