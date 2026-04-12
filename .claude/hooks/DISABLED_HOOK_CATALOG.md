# _disabled Hook Catalog
> Generated: 2025-11-21
>
> Purpose: _disabled/2024-11-21/에 있는 모든 Hook 분석 및 복원 가이드

## 🔥 Critical Priority (필수 복원)

### 1. code-writer-retry-handler.sh (196줄)
**Event**: SubagentStop
**Trigger**: code-writer Agent 종료 시

**목적**:
- Task 완료 여부 자동 감지 (체크박스 기반)
- 80% 미만 완료 시 최대 3회 자동 재시도
- 3회 실패 시 사용자에게 상세 리포트 제공

**핵심 로직**:
```bash
# Step 1: Task 파일 찾기 (EPIC_ID, TASK_ID 기반)
# Step 2: 체크박스 완료율 계산
COMPLETION_RATE=$((CHECKED_COUNT * 100 / TOTAL_COUNT))

# Step 3: 80% 미만 → 재시도
if [ $COMPLETION_RATE -lt 80 ] && [ $RETRY_COUNT -lt 3 ]; then
  # code-writer 재호출 (자동)
fi
```

**Agent 워크플로우 연관성**: ⭐⭐⭐⭐⭐
- code-writer 에러 복구 핵심
- Task 자동 완료 보장

**v3.1 표준 준수 여부**:
- ❌ `set -e` 사용 (Graceful Degradation 위반)
- ❌ Plain Text 출력 명시 없음
- ❌ stderr 차단 없음 (`log_debug` → stderr)
- ✅ Bash only
- ✅ 200줄 이하

**복원 시 수정 필요**:
1. `set -e` 제거 → `set -e; trap 'exit 0' ERR` 로 대체
2. 출력 시작 부분에 `# HOOK OUTPUT: Plain Text Format (Not JSON)` 추가
3. `exec 2>/dev/null` 추가 (선택)
4. `log_debug` → `DEBUG_ENABLED` 조건부로 변경

---

### 2. pre-tool-use-agent-chain-guard-enhanced.sh (159줄)
**Event**: PreToolUse
**Matcher**: Write|Edit|MultiEdit|Read|Grep|Search|Glob

**목적**:
- Agent Chain 실행 중 직접 Write/Edit 차단
- "구현하겠습니다" 선언 후 직접 구현 방지 (VIOLATION)

**핵심 로직**:
```bash
# State file: .claude/.agent-chain-state
# Agent 실행 시 상태 기록 (epic-creator → story-creator → task-planner → code-writer)

# PreToolUse에서 체크:
if [[ "$TOOL_NAME" =~ ^(Write|Edit)$ ]] && [[ -f "$STATE_FILE" ]]; then
  current_chain=$(cat "$STATE_FILE")
  if [[ "$current_chain" =~ "code-writer" ]]; then
    # 차단: Agent가 존재하는데 직접 Write/Edit 시도
    echo "❌ VIOLATION: Agent Chain 중단 방지"
    exit 2  # Blocking error
  fi
fi
```

**Agent 워크플로우 연관성**: ⭐⭐⭐⭐⭐
- AGENT CHAIN INTERRUPTION PREVENTION 핵심
- CLAUDE.md 규칙 강제

**v3.1 표준 준수 여부**:
- ❌ `set -e` 사용
- ❌ Plain Text 출력 명시 없음
- ❌ stderr 차단 없음
- ✅ Bash only
- ✅ 200줄 이하

**복원 시 수정 필요**:
1. `set -e` → Graceful Degradation
2. Blocking error (exit 2) 출력 시 Plain Text 명시
3. `exec 2>/dev/null` 추가 (선택)
4. stdin 읽기 안정화 (image 처리 개선)

---

### 3. pattern-auto-detector.sh (128줄)
**Event**: SubagentStop
**Trigger**: code-writer Agent 종료 시

**목적**:
- Git history 기반 반복 패턴 자동 감지
- 3회 이상 반복 수정 파일 → 패턴 문서화 제안

**핵심 로직**:
```bash
# Step 1: 최근 20개 커밋 분석
MODIFIED_FILES=$(git log -20 --name-only --pretty=format:)

# Step 2: 파일별 수정 횟수 카운트
REPEATED_FILES=$(echo "$MODIFIED_FILES" | uniq -c | sort -rn | awk '$1 >= 3')

# Step 3: 반복 패턴 리포트
if [ -n "$REPEATED_FILES" ]; then
  echo "🔍 반복 패턴 감지: $file_path (${count}회 수정)"
  echo "💡 패턴 문서화 권장: /pattern-documenter:create"
fi
```

**Agent 워크플로우 연관성**: ⭐⭐⭐⭐
- pattern-documenter Agent 트리거
- Reddit Hook System 패턴 학습

**v3.1 표준 준수 여부**:
- ❌ `set -e` 사용
- ❌ Plain Text 출력 명시 없음
- ❌ stderr 차단 없음
- ✅ Bash only
- ✅ 200줄 이하

**복원 시 수정 필요**:
1. `set -e` → Graceful Degradation
2. 출력 시작에 Plain Text 명시
3. `exec 2>/dev/null` 추가 (선택)

---

## ⚡ High Priority (권장 복원)

### 4. post-tool-use-task-sync.sh (148줄)
**Event**: PostToolUse
**Matcher**: Edit|MultiEdit|Write

**목적**:
- Task 파일 편집 감지 → PROGRESS.md 자동 업데이트
- 체크박스 완료율 자동 계산

**핵심 로직**:
```bash
# Task 파일 편집 감지
if [[ "$file_path" =~ docs/epics/.*/tasks/.*\.md ]]; then
  # 체크박스 카운트
  checked=$(grep -c "^- \[x\]" "$file_path")
  total=$(grep -c "^- \[" "$file_path")

  # PROJECT_STATE.json 업데이트
  # generate-progress.sh 실행 → PROGRESS.md 생성
fi
```

**Agent 워크플로우 연관성**: ⭐⭐⭐⭐
- PROGRESS.md 자동 업데이트
- code-writer 완료 후 자동 동기화

**v3.1 표준 준수 여부**:
- ❌ `set -e` 사용
- ❌ JSON 출력 (Plain Text 아님)
- ✅ jq 사용 (stdin 파싱)
- ✅ Bash only
- ✅ 200줄 이하

**복원 시 수정 필요**:
1. `set -e` → Graceful Degradation
2. jq 실패 처리 강화 (`jq -e`, `|| echo ""`)
3. `exec 2>/dev/null` 추가 (선택)

---

### 5. precompact-preserve.sh (228줄)
**Event**: PreCompact

**목적**:
- 컨텍스트 압축 전 중요 정보 보존
- Agent 상태, 진행 중 Task 정보 저장

**핵심 로직**:
```bash
# 보존할 정보:
# - 현재 Agent Chain 상태
# - 진행 중 Epic/Story/Task
# - 최근 에러 메시지
# - 중요 메모리 (Serena MCP)

# 압축 후 복원:
# - SessionStart에서 자동 로드
```

**Agent 워크플로우 연관성**: ⭐⭐⭐
- 긴 세션에서 컨텍스트 보존
- Agent 상태 유지

**v3.1 표준 준수 여부**:
- ⚠️ 228줄 (200줄 초과, 리팩토링 필요)
- ❌ `set -e` 사용
- ❌ Plain Text 출력 명시 없음
- ✅ Bash only

**복원 시 수정 필요**:
1. 200줄 이하로 리팩토링 (핵심 기능만)
2. `set -e` → Graceful Degradation
3. 출력 시 Plain Text 명시
4. `exec 2>/dev/null` 추가

---

### 6. stop-epic-lifecycle.sh (97줄)
**Event**: Stop

**목적**:
- 세션 종료 시 Epic/Task 편집 감지
- lifecycle-manager.sh 조건부 실행

**핵심 로직**:
```bash
# Step 1: task-sync.log 확인 (최근 30분)
recent_edits=$(grep "Task file edited:" task-sync.log | count)

# Step 2: 편집 있으면 lifecycle-manager.sh 실행
if [ $recent_edits -gt 0 ]; then
  bash lifecycle-manager.sh
fi
```

**Agent 워크플로우 연관성**: ⭐⭐⭐
- Epic 완료 처리 자동화
- epic-completion-manager 트리거

**v3.1 표준 준수 여부**:
- ❌ `set -e` 사용
- ❌ JSON stdin 파싱 (jq 사용)
- ✅ Bash only
- ✅ 200줄 이하

**복원 시 수정 필요**:
1. `set -e` → Graceful Degradation
2. jq 실패 처리 강화
3. Plain Text 출력 명시
4. 현재 .claude/hooks/stop-epic-lifecycle.sh (4줄 빈 파일) 교체

---

## 📊 Medium Priority (선택적 복원)

### 7. post-tool-use-tracker.sh
**목적**: Tool 사용 추적/로깅
**필요성**: 디버깅용 (낮은 우선순위)

### 8. post-tool-use-tech-spec-tracker.sh
**목적**: Tech Spec 추적
**필요성**: 문서화 자동화 (선택적)

### 9. post-tool-use-agent-cache-tracker.sh
**목적**: Agent 캐시 관리
**필요성**: 성능 최적화 (선택적)

### 10. session-end-summary.sh
**목적**: 세션 종료 시 요약
**필요성**: 통계 (선택적)

---

## 🎯 복원 전략

### Phase 1: Critical Hooks (즉시 복원)
1. ✅ code-writer-retry-handler.sh
2. ✅ pre-tool-use-agent-chain-guard-enhanced.sh
3. ✅ pattern-auto-detector.sh

**예상 시간**: 30-40분 (각 10-15분)

### Phase 2: High Priority Hooks (권장)
4. ✅ post-tool-use-task-sync.sh
5. ✅ precompact-preserve.sh (리팩토링 필요)
6. ✅ stop-epic-lifecycle.sh

**예상 시간**: 40-50분

### Phase 3: 테스트 및 검증
- 각 Hook 개별 테스트
- Agent Chain 통합 테스트
- v3.1 표준 체크리스트 검증

**예상 시간**: 20-30분

### Phase 4: Cleanup
- settings.json/local.json 중복 제거
- 불필요한 Hook 설정 정리
- 최종 커밋

**예상 시간**: 10분

---

## 📝 v3.1 표준 적용 템플릿

모든 복원 Hook에 적용할 표준 구조:

```bash
#!/bin/bash
# .claude/hooks/{event}/{hook-name}.sh
# {Purpose}
# Version: v3.1

# ============================================================================
# CRITICAL: stderr 차단 (Claude Desktop Hook Error 방지)
# ============================================================================
# NOTE: 현재 해제 상태 (디버깅 용이성 우선)
# exec 2>/dev/null

# ============================================================================
# DEBUG CONFIGURATION
# ============================================================================
DEBUG_LOG="/tmp/hook-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG"
  fi
}

# ============================================================================
# GRACEFUL DEGRADATION
# ============================================================================
set -e
trap 'log_debug "Error occurred, exiting gracefully"; exit 0' ERR

# ============================================================================
# stdin 처리
# ============================================================================
if [ ! -t 0 ]; then
  INPUT_JSON=$(cat 2>/dev/null || echo "")
  log_debug "stdin detected, INPUT_JSON length: ${#INPUT_JSON}"
else
  INPUT_JSON=""
  log_debug "No stdin"
fi

# 빈 입력 처리
if [[ -z "$INPUT_JSON" ]] || [[ "${#INPUT_JSON}" -lt 2 ]]; then
  log_debug "Skipped: empty input"
  exit 0
fi

# ============================================================================
# CRITICAL: Plain Text Output (Not JSON)
# ============================================================================
cat <<EOF
# HOOK OUTPUT: Plain Text Format (Not JSON)

{실제 Hook 출력}
EOF

exit 0
```

---

## ✅ 복원 체크리스트 (각 Hook마다)

- [ ] _disabled/2024-11-21/에서 복사
- [ ] v3.1 표준 헤더 추가
- [ ] `set -e` → Graceful Degradation
- [ ] Plain Text 출력 명시
- [ ] stderr 차단 옵션 추가
- [ ] 디버그 로그 조건부 처리
- [ ] stdin 빈 입력 처리
- [ ] jq 실패 처리 강화 (`jq -e`, `|| echo ""`)
- [ ] 실행 권한 부여 (`chmod +x`)
- [ ] 개별 테스트 실행
- [ ] settings.json/local.json 등록 확인

---

## 🚀 시작 준비 완료!

다음 단계: Phase 1 Critical Hooks 복원 시작
