# Hook System Audit Report
> Generated: 2025-11-21
>
> Purpose: 현재 등록된 모든 Hook 분석 및 복원 계획

## 📊 Current Hook Registration

### settings.json (4 Events, 6 Hooks)

#### PreToolUse
- ❌ **pre-tool-use-agent-chain-guard-enhanced.sh** (누락)
  - Purpose: Agent Chain 실행 전 검증
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐⭐ (Agent 워크플로우 핵심)

#### PostToolUse
- ❌ **post-tool-use-tracker.sh** (누락)
  - Purpose: Tool 사용 추적/로깅
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐ (디버깅용)

#### SubagentStop
- ❌ **code-writer-retry-handler.sh** (누락)
  - Purpose: code-writer 실패 시 재시도
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐⭐⭐ (에러 복구)

- ✅ **agent-complete.sh** (280줄)
  - Status: 정상 작동
  - 필요성: ⭐⭐⭐⭐⭐ (Agent 완료 처리)

- ❌ **pattern-auto-detector.sh** (누락)
  - Purpose: 반복 패턴 자동 감지
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐⭐ (패턴 학습)

#### SessionStart
- ✅ **session-start-loader.sh** (442줄)
  - Status: 정상 작동
  - 필요성: ⭐⭐⭐⭐⭐ (세션 초기화)

---

### settings.local.json (6 Events, 11 Hooks)

#### SessionStart
- ✅ **session-start-loader.sh** (중복, settings.json과 동일)

#### SessionEnd
- ❌ **session-end-summary.sh** (누락)
  - Purpose: 세션 종료 시 요약
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐ (통계)

#### PreCompact
- ❌ **precompact-preserve.sh** (누락)
  - Purpose: 컨텍스트 압축 전 보존
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐⭐ (컨텍스트 보존)

#### UserPromptSubmit
- ✅ **user-prompt-submit.sh** (249줄, v3.1)
  - Status: 정상 작동 (최근 수정)
  - 필요성: ⭐⭐⭐⭐⭐ (워크플로우 강제)

#### PreToolUse
- ✅ **WebSearch 연도 주입** (Python inline, JSON 출력)
  - Status: 정상 작동
  - 필요성: ⭐⭐⭐⭐

- ✅ **secret-scanner.sh** (242줄)
  - Matcher: Write|Edit|MultiEdit, Bash
  - Status: 정상 작동
  - 필요성: ⭐⭐⭐⭐⭐ (보안)

#### PostToolUse
- ❌ **post-tool-use-task-sync.sh** (누락)
  - Purpose: Task 상태 동기화
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐⭐ (PROGRESS.md 업데이트)

- ❌ **post-tool-use-tech-spec-tracker.sh** (누락)
  - Purpose: Tech Spec 추적
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐ (문서화)

- ❌ **post-tool-use-agent-cache-tracker.sh** (누락)
  - Purpose: Agent 캐시 관리
  - Status: _disabled/2024-11-21/에 있음
  - 필요성: ⭐⭐ (성능)

#### Stop
- ✅ **stop-event.sh** (176줄, model: gpt-5-codex)
  - Status: 정상 작동
  - 필요성: ⭐⭐⭐⭐⭐ (품질 검증)

- ⚠️ **stop-epic-lifecycle.sh** (4줄, 빈 파일)
  - Status: 빈 파일
  - 필요성: ⭐⭐⭐ (Epic 완료 처리)

---

## 🎯 Restoration Priority

### 🔥 Critical (필수 복원)
1. **code-writer-retry-handler.sh** (SubagentStop)
   - Agent 에러 복구 핵심
   - 복원 후 v3.1 표준 적용

2. **pre-tool-use-agent-chain-guard-enhanced.sh** (PreToolUse)
   - Agent Chain 검증
   - 복원 후 v3.1 표준 적용

3. **pattern-auto-detector.sh** (SubagentStop)
   - 반복 패턴 학습
   - 복원 후 v3.1 표준 적용

### ⚡ High (권장 복원)
4. **post-tool-use-task-sync.sh** (PostToolUse)
   - PROGRESS.md 자동 업데이트
   - 복원 후 v3.1 표준 적용

5. **precompact-preserve.sh** (PreCompact)
   - 컨텍스트 보존
   - 복원 후 v3.1 표준 적용

6. **stop-epic-lifecycle.sh** (Stop)
   - 현재 빈 파일, _disabled에서 복원 필요
   - 복원 후 v3.1 표준 적용

### 📊 Medium (선택적 복원)
7. **post-tool-use-tracker.sh** (PostToolUse)
8. **post-tool-use-tech-spec-tracker.sh** (PostToolUse)
9. **post-tool-use-agent-cache-tracker.sh** (PostToolUse)
10. **session-end-summary.sh** (SessionEnd)

---

## ✅ Hook v3.1 Standard Checklist

모든 복원 Hook은 다음 기준을 충족해야 함:

### 1. 출력 형식
```bash
# ============================================================================
# CRITICAL: Plain Text Output (Not JSON)
# Claude Desktop Hook 시스템이 JSON 파싱을 시도하지 않도록 명시
# ============================================================================
cat <<EOF
# HOOK OUTPUT: Plain Text Format (Not JSON)

[Hook 출력 내용]
EOF
```

### 2. stderr 차단
```bash
# ============================================================================
# CRITICAL: stderr 차단 (Claude Desktop Hook Error 방지)
# ============================================================================
# NOTE: 현재 해제 상태 (디버깅 용이성 우선)
# exec 2>/dev/null
```

### 3. 디버그 로그
```bash
DEBUG_LOG="/tmp/hook-debug.log"
DEBUG_ENABLED="${HOOK_DEBUG:-false}"

log_debug() {
  if [[ "$DEBUG_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG"
  fi
}
```

### 4. 빈 입력 처리
```bash
if [[ -z "$INPUT_JSON" ]] || [[ "${#INPUT_JSON}" -lt 2 ]]; then
  log_debug "Skipped: empty input"
  exit 0  # Silent success
fi
```

### 5. Graceful Degradation
```bash
# 모든 에러는 exit 0 (조용히 성공)
# jq 실패, grep 실패 등 모두 방어
```

---

## 🚀 Restoration Plan

### Phase 1: Critical Hooks (필수)
1. code-writer-retry-handler.sh 복원
2. pre-tool-use-agent-chain-guard-enhanced.sh 복원
3. pattern-auto-detector.sh 복원
4. v3.1 표준 적용 및 테스트

### Phase 2: High Priority Hooks (권장)
5. post-tool-use-task-sync.sh 복원
6. precompact-preserve.sh 복원
7. stop-epic-lifecycle.sh 복원 (빈 파일 교체)
8. v3.1 표준 적용 및 테스트

### Phase 3: Medium Priority Hooks (선택)
9. 나머지 Hook 필요성 재평가
10. 선택적 복원

### Phase 4: Cleanup
11. settings.json SessionStart 중복 제거
12. 불필요한 Hook 설정 정리
13. 최종 테스트 및 커밋

---

## 📝 Notes

- UserPromptSubmit 에러 해결 경험을 모든 Hook에 적용
- 각 Hook 복원 시 _disabled/2024-11-21/에서 가져와 수정
- v3.1 표준 체크리스트 필수 준수
- 복원 후 개별 테스트 필수
