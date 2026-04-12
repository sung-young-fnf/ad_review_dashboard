# Agent Resume 사용 가이드

## 개요

Claude Code의 Resume 기능을 활용하여 중단된 Agent 작업을 이어서 진행할 수 있습니다.

**지원 Agent**:
- `04-implementation/code-writer` (10 Steps)
- `99-utils/error-fixer` (6 Phases)

## Resume 메커니즘

### 작동 원리

1. **Agent 실행 시**: `agent_id` 자동 생성 (예: `writer_20251028_100000`)
2. **각 Step 완료 시**: Serena MCP 메모리에 진행 상태 저장
3. **작업 중단 시**: Resume 메모리 유지
4. **Resume 실행 시**: 마지막 완료 Step 다음부터 재개

### 메모리 구조

#### code-writer
```yaml
code_writer_resume_{agent_id}:
  agent_id: "writer_20251028_100000"
  task_id: "T001-S01"
  current_step: 5
  completed_steps: [1, 2, 3, 4, 5]
  step_results:
    step_1: "Task T001-S01 파일 읽기 완료"
    step_2: "상태 확인 완료 - AVAILABLE"
    step_3: "Task 시작 표시 완료"
    step_4: "코드베이스 패턴 참조 완료"
    step_5: "DB 필드 검증 완료"
  started_at: "2025-10-28T10:00:00Z"
  last_updated: "2025-10-28T10:15:00Z"
```

#### error-fixer
```yaml
error_fixer_resume_{agent_id}:
  agent_id: "fixer_20251028_100000"
  error_context: "TypeError: Cannot read property 'id' of undefined"
  current_phase: 2
  completed_phases: [0, 1, 2]
  phase_results:
    phase_0: "초기화 완료 - 서버 실행, Chrome 연결"
    phase_1: "Chrome 에러 5개 발견"
    phase_2: "Grep 파싱 완료 - file.ts:42"
  started_at: "2025-10-28T10:00:00Z"
  last_updated: "2025-10-28T10:10:00Z"
```

## 사용법

### 기본 워크플로우

```bash
# 1. 첫 실행
Task --subagent_type "code-writer" --prompt "Task T001-S01 구현"

# 출력 예시:
# 🆕 New: Step 1부터 시작
# agent_id: writer_20251028_100000
# Step 1: Task 파일 Read ✅
# Step 2: Task 상태 확인 ✅
# Step 3: Task 시작 표시 ✅
# Step 4-6: 코드 구현 ✅
# Step 7: 컴파일 검증 [진행 중...]
#
# [사용자가 Ctrl+C로 중단]
# ⏸️ Resume 가능: Task --resume writer_20251028_100000

# 2. Resume 실행
Task --resume "writer_20251028_100000" --prompt "계속"

# 출력 예시:
# 🔄 Resume: Step 7부터 재개
# 이전 작업 요약:
#   Step 1-6: 완료
#   중단 시점: Step 7 (컴파일 검증)
#
# Step 7: 컴파일 검증 ✅
# Step 8: Task 완료 표시 ✅
# Step 9: Resume 정리 ✅
# ✅ Task T001-S01 전체 워크플로우 완료
```

### error-fixer 예시

```bash
# 1. 첫 실행
Task --subagent_type "error-fixer" --prompt "TypeError 수정"

# agent_id: fixer_20251028_100000
# Phase 0: FIRST ACTION ✅
# Phase 1: Chrome DevTools 모니터링 ✅
# Phase 2: Grep 파싱 [진행 중...]
#
# [중단]
# ⏸️ Resume 가능: Task --resume fixer_20251028_100000

# 2. Resume 실행
Task --resume "fixer_20251028_100000" --prompt "계속"

# 🔄 Resume: Phase 2부터 재개
# Phase 2: Grep 파싱 ✅
# Phase 3: 자동 수정 ✅
# Phase 4: 브라우저 재검증 ✅
# ✅ 에러 수정 전체 워크플로우 완료
```

## 실전 시나리오

### 1. 사용자 피드백 반영

```bash
# 구현 진행 중
Task --subagent_type "code-writer" --prompt "T001-S01 API 구현"
# agent_id: writer_20251028_100000
# Step 1-4 완료
# [사용자 확인]

# 사용자: "인증 헤더 추가해야 해요"

# Resume + 추가 요구사항
Task --resume "writer_20251028_100000" --prompt "인증 헤더 추가하여 계속"
# Step 5부터 재개 + 인증 로직 추가
```

### 2. 복잡한 에러 단계별 수정

```bash
# 에러 수정 시작
Task --subagent_type "error-fixer" --prompt "5개 에러 수정"
# agent_id: fixer_20251028_100000
# Phase 1-2 완료
# [3개 에러 수정됨, 2개 남음]

# Resume으로 나머지 에러 수정
Task --resume "fixer_20251028_100000" --prompt "나머지 에러 수정"
# Phase 3부터 재개 + 남은 에러 처리
```

### 3. 긴 컴파일 재시도

```bash
# 컴파일 진행 중
Task --subagent_type "code-writer" --prompt "T005 구현"
# agent_id: writer_20251028_120000
# Step 7: 컴파일 검증 [실패]
# [사용자가 수동으로 일부 수정]

# Resume으로 재검증
Task --resume "writer_20251028_120000" --prompt "컴파일 재시도"
# Step 7부터 재개 (Step 1-6 스킵)
```

## Resume 상태 관리

### 상태 확인

Serena MCP 메모리 확인:
```bash
mcp__serena__list_memories()
# → code_writer_resume_*
# → error_fixer_resume_*
```

특정 Resume 메모리 읽기:
```bash
mcp__serena__read_memory("code_writer_resume_writer_20251028_100000")
```

### 수동 정리

필요 시 수동으로 Resume 메모리 삭제:
```bash
mcp__serena__delete_memory("code_writer_resume_writer_20251028_100000")
```

### 자동 정리

- **정상 완료 시**: Agent가 자동으로 Resume 메모리 삭제
- **중단 시**: 메모리 유지 (Resume 가능)

## 주의 사항

### ✅ Resume 가능 상황
- Agent 실행 중 사용자가 중단 (Ctrl+C)
- 일시적 네트워크 오류
- 중간 피드백 반영 필요
- 단계별 검증 원할 때

### ❌ Resume 불가능 상황
- Agent가 정상 완료된 경우 (메모리 자동 삭제됨)
- Resume 메모리를 수동으로 삭제한 경우
- 다른 Agent 실행 중 (agent_id 불일치)

### ⚠️ 제약 사항
- Resume은 **같은 세션 내에서만** 유효
- Task ID 변경 시 Resume 불가 (새로운 작업으로 간주)
- agent_id를 정확히 기억해야 함 (출력 메시지 확인)

## FAQ

### Q1. agent_id를 잊어버렸어요
A1. Serena MCP 메모리에서 확인:
```bash
mcp__serena__list_memories()
# code_writer_resume_* 패턴 찾기
```

### Q2. Resume 없이 처음부터 다시 하고 싶어요
A2. 새로운 Task 실행 (다른 agent_id 생성됨):
```bash
Task --subagent_type "code-writer" --prompt "T001-S01 구현"
# 새로운 agent_id 생성
```

### Q3. Resume 메모리가 너무 많아요
A3. 자동 정리 또는 수동 삭제:
- 정상 완료된 작업은 자동 정리됨
- 중단된 작업만 수동 삭제:
```bash
mcp__serena__delete_memory("code_writer_resume_{agent_id}")
```

### Q4. Resume 시 Step을 건너뛸 수 있나요?
A4. 불가능합니다. Resume은 마지막 완료 Step 다음부터만 시작합니다.
순서를 변경하려면 새로운 실행이 필요합니다.

### Q5. 여러 Agent를 동시에 Resume할 수 있나요?
A5. 가능하지만 권장하지 않습니다. 병렬 실행보다는 순차 Resume을 권장합니다.

## 모범 사례

### ✅ 권장
1. **agent_id 메모**: Resume 가능성이 있는 작업은 agent_id를 메모해두기
2. **중간 확인**: 복잡한 작업은 Step마다 중단하여 확인
3. **피드백 반영**: 사용자 피드백은 Resume으로 즉시 반영
4. **에러 단계별 수정**: error-fixer는 Phase별로 Resume 활용

### ❌ 비권장
1. **무분별한 중단**: 간단한 작업까지 Resume 사용
2. **오래된 Resume**: 1시간 이상 경과한 Resume 메모리는 삭제 후 재실행
3. **동시 Resume**: 같은 Task를 여러 Resume으로 처리

## 기술 세부사항

### agent_id 생성 규칙
```python
agent_id = f"{agent_name}_{timestamp}"
# 예: writer_20251028_100000
# 예: fixer_20251028_103000
```

### Step vs Phase
- **code-writer**: Step (1, 2, 3, ..., 9)
- **error-fixer**: Phase (0, 1, 2, 2.5, 3, 4, 5)

### 상태 저장 빈도
- 각 Step/Phase 완료 시마다 저장
- 실패 시에도 상태 저장 (다음 Resume 시 재시도 가능)

---

## 관련 문서

- [@docs/analysis/claude-code-patch-analysis.md](../docs/analysis/claude-code-patch-analysis.md) - Resume 기능 분석
- [code-writer.md](.claude/agents/04-implementation/code-writer.md) - Resume 통합 코드
- [error-fixer.md](.claude/agents/99-utils/error-fixer.md) - Resume 통합 코드

---

_Version: 1.0 - Resume Support Guide_
_Last Updated: 2025-10-28_
