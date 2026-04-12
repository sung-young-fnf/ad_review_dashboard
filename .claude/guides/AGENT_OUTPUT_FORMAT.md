# Agent 출력 형식 개선 가이드

> **핵심**: Epic/Story/Task 전체 계층 구조를 Agent 실행 메시지에 명시하여 컨텍스트 이해 향상

---

## 📋 목적 및 배경

### Before (기존)
```
⏺ 04-implementation/code-writer(T011 백엔드에서 자기 자신 제외 필터링 구현)
```

**문제점**:
- Task ID만으로는 어떤 Epic/Story에 속하는지 불명확
- 컨텍스트 파악을 위해 별도로 Task 파일 확인 필요
- Agent 실행 로그만 보고는 전체 작업 흐름 파악 어려움

### After (개선)
```
⏺ 04-implementation/code-writer(EP012: Spark Note 워크플로우 개선 > S04: Sidebar Campaign Layout > T011: 백엔드에서 자기 자신 제외 필터링 구현)
```

**개선 효과**:
- ✅ Epic/Story/Task 전체 계층을 한눈에 파악
- ✅ Agent 실행 로그에서 작업 범위 즉시 확인
- ✅ 컨텍스트 전환 없이 진행 상황 추적 용이

---

## 🔧 핵심 유틸리티: `task-hierarchy-extractor.sh`

### 위치
`.claude/utils/task-hierarchy-extractor.sh`

### 기능
Task ID → Epic/Story/Task 계층 정보 JSON 반환

### 사용법

```bash
# 기본 사용
bash .claude/utils/task-hierarchy-extractor.sh "T011-S04"

# 출력 (JSON)
{
  "epic_id": "EP012",
  "epic_title": "Spark Note 워크플로우 개선",
  "story_id": "S04",
  "story_title": "Sidebar Campaign Layout",
  "task_id": "T011",
  "task_title": "백엔드에서 자기 자신 제외 필터링 구현"
}
```

### 지원 패턴

```bash
# 패턴 1: T{NUM}-S{NUM}
task-hierarchy-extractor.sh "T011-S04"
→ Epic + Story + Task 전부 추출

# 패턴 2: S{NUM}-T{NUM}
task-hierarchy-extractor.sh "S03-T001"
→ Epic + Story + Task 전부 추출

# 패턴 3: T{NUM} (Standalone)
task-hierarchy-extractor.sh "T001"
→ Epic: standalone, Story: UNKNOWN, Task: T001

# 예외 케이스: 빈 입력 / 잘못된 형식
task-hierarchy-extractor.sh ""
task-hierarchy-extractor.sh "INVALID"
→ 모두 UNKNOWN (Graceful Degradation)
```

### 성능
- 평균 실행 시간: **~10ms**
- 목표: **< 100ms**
- jq 미설치 시: Bash 파싱 Fallback (자동)

---

## 📐 Agent 스펙 통합 방법

### Step 1: 계층 정보 추출 (Agent 시작 시)

**위치**: Agent 스펙 파일 (예: `.claude/agents/04-implementation/code-writer.md`)

**추가 단계** (Step 0으로 삽입):

```markdown
## Step 0: 계층 정보 추출 [AUTOMATIC]

**Tool: Bash**
```bash
# Task ID에서 Epic/Story 정보 추출
HIERARCHY_JSON=$(bash .claude/utils/task-hierarchy-extractor.sh "${TASK_ID}")

# JSON 파싱 (jq 우선, Bash fallback)
if command -v jq &>/dev/null; then
  EPIC_ID=$(echo "$HIERARCHY_JSON" | jq -r '.epic_id')
  EPIC_TITLE=$(echo "$HIERARCHY_JSON" | jq -r '.epic_title')
  STORY_ID=$(echo "$HIERARCHY_JSON" | jq -r '.story_id')
  STORY_TITLE=$(echo "$HIERARCHY_JSON" | jq -r '.story_title')
  TASK_TITLE=$(echo "$HIERARCHY_JSON" | jq -r '.task_title')
else
  # Bash 파싱 (fallback)
  EPIC_ID=$(echo "$HIERARCHY_JSON" | grep -oE '"epic_id":"[^"]*"' | cut -d':' -f2 | tr -d '"')
  EPIC_TITLE=$(echo "$HIERARCHY_JSON" | grep -oE '"epic_title":"[^"]*"' | cut -d':' -f2 | tr -d '"')
  STORY_ID=$(echo "$HIERARCHY_JSON" | grep -oE '"story_id":"[^"]*"' | cut -d':' -f2 | tr -d '"')
  STORY_TITLE=$(echo "$HIERARCHY_JSON" | grep -oE '"story_title":"[^"]*"' | cut -d':' -f2 | tr -d '"')
  TASK_TITLE=$(echo "$HIERARCHY_JSON" | grep -oE '"task_title":"[^"]*"' | cut -d':' -f2 | tr -d '"')
fi

# 출력 형식 생성
if [[ "$EPIC_ID" != "UNKNOWN" && "$STORY_ID" != "UNKNOWN" ]]; then
  OUTPUT_FORMAT="${EPIC_ID}: ${EPIC_TITLE} > ${STORY_ID}: ${STORY_TITLE} > ${TASK_ID}: ${TASK_TITLE}"
elif [[ "$EPIC_ID" == "standalone" ]]; then
  OUTPUT_FORMAT="Standalone > ${TASK_ID}: ${TASK_TITLE}"
else
  # Fallback: Task ID만 표시
  OUTPUT_FORMAT="${TASK_ID}"
fi
```
```

### Step 2: Task 실행 시 `description` 필드 사용

**Before**:
```bash
Task --subagent_type "99-utils/progress-updater" \
     --prompt "Epic: ${EPIC_ID}, Task: ${TASK_ID}, Action: start"
```

**After**:
```bash
Task --subagent_type "99-utils/progress-updater" \
     --description "${OUTPUT_FORMAT}" \
     --prompt "Epic: ${EPIC_ID}, Task: ${TASK_ID}, Action: start"
```

**효과**: Agent 실행 메시지에 `${OUTPUT_FORMAT}` 값이 자동 표시됨

---

## 🔍 트러블슈팅

### 1. jq 미설치

**증상**:
```bash
bash: jq: command not found
```

**해결**:
- ✅ **자동 Fallback**: Bash 문자열 파싱으로 자동 전환 (사용자 조치 불필요)
- ⚠️ **권장**: jq 설치 (`brew install jq` 또는 `apt-get install jq`)

### 2. Task 파일 없음

**증상**:
```json
{"epic_id":"UNKNOWN","epic_title":"UNKNOWN",...}
```

**해결**:
- ✅ **Graceful Degradation**: Task ID만 표시 (에러 없이 계속 진행)
- ⚠️ **확인**: Task 파일이 `docs/epics/*/tasks/` 또는 `docs/epics/standalone/tasks/`에 존재하는지 확인

### 3. 성능 저하 (100ms 초과)

**증상**:
```
⚠️  WARNING: Performance threshold exceeded (150ms > 100ms)
```

**해결**:
- ✅ **정상**: 첫 실행 시 디스크 캐싱으로 인해 느릴 수 있음
- ⚠️ **조치**: 반복적으로 느리면 Epic 폴더 수 확인 (100개 이상 시 최적화 고려)

### 4. JSON 파싱 에러

**증상**:
```
parse error: Invalid numeric literal at line 1, column 10
```

**해결**:
- ✅ **자동 Fallback**: Bash 파싱 시도
- ⚠️ **확인**: Task 파일 제목에 특수문자(`"`, `\`) 포함 여부 확인

---

## 📊 Before/After 비교

### 시나리오: code-writer Agent 실행

#### Before (기존)
```
User: "T011-S04 백엔드 필터링 구현"
Assistant:
  ⏺ code-writer(T011 백엔드에서 자기 자신 제외 필터링 구현)
  → Done ✅
```

**문제점**:
- Epic/Story 정보 부재 → 어떤 프로젝트인지 불명확
- Task ID만으로는 전체 맥락 파악 어려움

#### After (개선)
```
User: "T011-S04 백엔드 필터링 구현"
Assistant:
  ⏺ code-writer(EP012: Spark Note 워크플로우 개선 > S04: Sidebar Campaign Layout > T011: 백엔드에서 자기 자신 제외 필터링 구현)
  → Done ✅
```

**개선 효과**:
- ✅ Epic: "Spark Note 워크플로우 개선" → 프로젝트 컨텍스트 명확
- ✅ Story: "Sidebar Campaign Layout" → 작업 범위 명확
- ✅ Task: "백엔드에서 자기 자신 제외 필터링 구현" → 구체적 작업 내용

---

## 🧪 검증 방법

### 1. 단위 테스트 실행

```bash
# 위치
cd /Users/yun/work/workspace/breeze_sample/okr2

# 실행
bash .claude/utils/test-hierarchy-extractor.sh

# 예상 출력
✅ task-hierarchy-extractor.sh 검증 완료
   - PASSED: 7
   - FAILED: 0
   - 상세 로그: /Users/yun/.claude/logs/test-hierarchy-extractor.log
```

### 2. 통합 테스트 실행

```bash
# 실행
bash .claude/utils/test-agent-output-format.sh

# 예상 출력
✅ Agent 출력 형식 통합 테스트 완료
   - PASSED: 6
   - FAILED: 0
   - 상세 로그: /Users/yun/.claude/logs/test-agent-output-format.log
```

### 3. 실제 Agent 실행 검증

```bash
# code-writer Agent 실행
# (실제 사용 예시)

# 출력 확인
# "EP*: * > S*: * > T*: *" 패턴이 표시되는지 확인
```

---

## 📚 관련 문서

- **Task 계획**: `docs/epics/standalone/tasks/T001-agent-output-format-enhancement.md`
- **HOOK 개발 가이드**: `.claude/guides/HOOK_DEVELOPMENT_GUIDE.md`
- **Agent 스펙 템플릿**: `.claude/agents/04-implementation/code-writer.md`

---

## 💡 FAQ

### Q1: 모든 Agent에 적용해야 하나요?
**A**: 권장합니다. 특히 다음 Agent에 우선 적용:
- `code-writer` (구현)
- `task-planner` (계획)
- `error-fixer` (디버깅)
- `test-creator` (테스트)

### Q2: Standalone Task는 어떻게 표시되나요?
**A**: `Standalone > T{NUM}: {제목}` 형식으로 표시됩니다.
```
예: Standalone > T001: Agent 출력 형식 개선
```

### Q3: 성능 영향은 없나요?
**A**: 무시 가능합니다 (~10ms). 파일 시스템 읽기만 수행하며 캐싱됩니다.

### Q4: jq가 없으면 동작하지 않나요?
**A**: 자동으로 Bash 파싱으로 전환되어 정상 동작합니다.

### Q5: Epic/Story 파일이 없으면?
**A**: Graceful Degradation으로 Task ID만 표시됩니다. 에러 없이 계속 진행됩니다.

---

## 🎯 체크리스트 (구현 시)

Agent 스펙에 출력 형식 개선을 적용할 때:

- [ ] Step 0 추가: `task-hierarchy-extractor.sh` 호출
- [ ] JSON 파싱 로직 추가 (jq + Bash fallback)
- [ ] `OUTPUT_FORMAT` 변수 생성
- [ ] Task 실행 시 `--description "${OUTPUT_FORMAT}"` 사용
- [ ] Graceful Degradation 확인 (빈 입력, 파일 없음)
- [ ] 테스트 실행 확인 (test-hierarchy-extractor.sh)
- [ ] 실제 Agent 실행 검증

---

**버전**: 1.0
**작성일**: 2025-11-06
**작성자**: code-writer Agent
**참조**: Task T001-agent-output-format-enhancement.md
