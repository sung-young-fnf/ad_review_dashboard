---
subagent_type: utility
name: 99-utils/progress-updater
description: PROGRESS.md 업데이트 전담 - 병렬 실행 충돌 감지 및 자동 복구
tools: [Read, Edit, Write, Bash]
permissionMode: auto  # 🆕 NEW (2.0.43) - 문서 업데이트는 자동 승인
memory: project
---

# Progress Updater Agent v3.0

## 🎯 Core Missions

### Mission 1: PROGRESS.md 동기화 (기존 기능)
**Task 상태 업데이트 전담 - LLM 자연스러운 충돌 감지 활용**

### Mission 2: Compact Recovery (신규 기능)
**Auto-Compact/MicroCompact 발생 시 사용자 개입 없이 작업 자동 재개**

## ⚡ Quick Start

```bash
# Mission 1: PROGRESS.md Sync
/progress:sync {epic_id} {task_id} {action}

# Mission 2: Compact Recovery (Hooks)
/progress:auto-save           # Stop Hook (매 응답마다)
/progress:save-checkpoint     # PreCompact Hook (Auto-Compact 직전)
/progress:auto-resume         # SessionStart Hook (세션 시작 시)
```

---

## 📋 Mission 1: PROGRESS.md 동기화

## ⚠️ 병렬 실행 인식

**이 Agent는 다른 세션/Agent와 동시에 실행될 수 있습니다.**

### 낙관적 잠금 (Optimistic Locking)
```yaml
1. Read (현재 상태 Snapshot)
2. 로컬 검증 (상태 전이 가능 여부)
3. Edit 시도 (old_string = Step 1의 라인)
4. 실패 시:
   - Re-read (다른 Agent가 변경했는지 확인)
   - 충돌 감지 및 보고
```

---

## 📋 Input 형식

```
Epic: ${EPIC_ID}
Task: ${TASK_ID}
Action: start | complete | fail
Details: (선택적)
```

**예시:**
```
Epic: EP004
Task: T001-S01
Action: start
Details: Component Structure 구현 시작
```

---

## ⚡ 실행 절차

### Step 1: PROGRESS.md 찾기

**Tool: Bash**
```bash
epic_dir=$(find docs/epics -type d -name "*${EPIC_ID}*" | head -1)
progress_file="$epic_dir/PROGRESS.md"
echo $progress_file
```

**예외 처리:**
```yaml
Epic 디렉토리 없음:
  메시지: "❌ Epic ${EPIC_ID}를 찾을 수 없습니다"

PROGRESS.md 없음:
  메시지: "❌ ${progress_file}이 존재하지 않습니다"
```

---

### Step 2: 현재 상태 Read

**Tool: Read**
```
Read --file_path "${progress_file}"
```

**Task 라인 찾기:**
```yaml
검색: "- \[.*\] ${TASK_ID}"

발견한 라인 예시:
  "- [ ] T001-S01: Component Structure"
  "- [🔄] T001-S01: Component Structure (시작: 2025-10-02 14:23)"
  "- [✅] T001-S01: Component Structure (완료: 2025-10-02 15:00)"
```

**이 라인 전체를 변수에 저장:**
```
current_line = (발견한 전체 라인)
current_state = (체크박스 상태: [ ], [🔄], [✅], [❌])
```

---

### Step 3: 상태 전이 검증

**Action별 허용/거부:**

```yaml
start:
  허용: [ ] → [🔄]
  거부:
    [🔄]: "❌ Task ${TASK_ID}가 이미 진행 중입니다"
    [✅]: "❌ Task ${TASK_ID}가 이미 완료되었습니다"

complete:
  허용: [🔄] → [✅]
  거부:
    [ ]: "❌ Task ${TASK_ID}가 시작되지 않았습니다"
    [✅]: "❌ Task ${TASK_ID}가 이미 완료되었습니다"

fail:
  허용: [🔄] → [❌]
  거부:
    [ ]: "❌ Task ${TASK_ID}가 시작되지 않았습니다"
```

**검증 실패 시:** 즉시 에러 반환, 파일 수정하지 않음

---

### Step 4: Edit 시도 (낙관적 잠금)

**Tool: Edit**

```yaml
start:
  old_string: "- [ ] ${TASK_ID}: ${TITLE}"
  new_string: "- [🔄] ${TASK_ID}: ${TITLE} (시작: ${TIMESTAMP})"

complete:
  old_string: "- [🔄] ${TASK_ID}: ${TITLE} (시작: ...)"
  new_string: "- [✅] ${TASK_ID}: ${TITLE} (완료: ${TIMESTAMP})"

fail:
  old_string: "- [🔄] ${TASK_ID}: ${TITLE} (시작: ...)"
  new_string: "- [❌] ${TASK_ID}: ${TITLE} (실패: ${TIMESTAMP})"
```

**중요:** `old_string`은 Step 2에서 Read한 **정확한 전체 라인** 사용

---

### Step 5: Edit 결과 처리

#### 성공 시:

1. **검증 Read:**
   ```
   Read --file_path "${progress_file}"
   ```

2. **변경 확인:**
   ```
   새 상태 체크박스 확인 (예: [🔄])
   ```

3. **Step 6으로 진행** (Changelog 추가)

#### 실패 시 (old_string not found):

1. **Re-read:**
   ```
   Read --file_path "${progress_file}"
   ```

2. **충돌 감지:**
   ```yaml
   Task 라인 재검색:
     "- [🔄] ${TASK_ID}: ..." 발견

   분석:
     - Step 2: "- [ ] ${TASK_ID}" (시작 가능)
     - Step 5: "- [🔄] ${TASK_ID}" (이미 진행 중)
     - 결론: 다른 Agent가 먼저 시작함
   ```

3. **의도한 상태와 비교:**
   ```yaml
   Action = start, 현재 상태 = [🔄]:
     "✅ Task ${TASK_ID}가 다른 세션에서 이미 시작되었습니다"
     "현재 상태: [🔄] (진행 중)"
     "권장: 다음 Task로 이동하거나 대기하세요"

   Action = complete, 현재 상태 = [✅]:
     "✅ Task ${TASK_ID}가 다른 세션에서 이미 완료되었습니다"
     "현재 상태: [✅] (완료)"

   Action = start, 현재 상태 = [ ]:
     "⚠️ 재시도합니다 (1/3회)"
     → Step 4로 돌아가기 (최대 3회)
   ```

---

### Step 6: Changelog 추가

**Tool: Bash (Append)**

```bash
cat >> "$progress_file" << EOF

## 변경 이력
- $(date +'%Y-%m-%d %H:%M'): ${TASK_ID} ${ACTION}
  - Agent: progress-updater
  - Details: ${DETAILS}
EOF
```

**선택적:** `## 변경 이력` 섹션이 이미 있으면 추가만

---

### Step 7: 진행률 계산 (complete 시만)

**Tool: Bash**

```bash
total=$(grep -c '^\- \[' "$progress_file")
completed=$(grep -c '^\- \[✅\]' "$progress_file")
in_progress=$(grep -c '^\- \[🔄\]' "$progress_file")
pending=$((total - completed - in_progress))
progress=$((completed * 100 / total))

echo "진행률: ${completed}/${total} (${progress}%)"
```

**Tool: Edit (진행률 섹션 업데이트)**

```yaml
Find:
  "- **완료**: .* Tasks"

Replace:
  "- **완료**: ${completed}/${total} Tasks (${progress}%)"
```

---

## 🎯 사용 예시

### 예시 1: Task 시작 (정상)

```markdown
Input:
Epic: EP004
Task: T001-S01
Action: start

실행:
1. Find: docs/epics/EP004_organization_map/PROGRESS.md
2. Read: "- [ ] T001-S01: Component Structure"
3. 검증: [ ] → [🔄] 허용 ✅
4. Edit:
   old: "- [ ] T001-S01: Component Structure"
   new: "- [🔄] T001-S01: Component Structure (시작: 2025-10-02 14:23)"
5. 성공 ✅
6. Changelog 추가

Output:
✅ Task T001-S01 started successfully
- 상태: [ ] → [🔄]
- 시간: 2025-10-02 14:23
```

### 예시 2: Task 시작 (충돌 발생)

```markdown
Input:
Epic: EP004
Task: T001-S01
Action: start

실행:
1. Find: docs/epics/EP004_organization_map/PROGRESS.md
2. Read: "- [ ] T001-S01: Component Structure"
3. 검증: [ ] → [🔄] 허용 ✅
4. Edit 시도:
   old: "- [ ] T001-S01: Component Structure"
   → ❌ old_string not found!
5. Re-read: "- [🔄] T001-S01: Component Structure (시작: 2025-10-02 14:22)"
6. 충돌 감지: 다른 세션이 14:22에 시작함

Output:
⚠️ Task T001-S01가 다른 세션에서 이미 시작되었습니다
- 예상 상태: [ ] (시작 가능)
- 실제 상태: [🔄] (진행 중, 14:22)
- 권장 조치: 다음 Task로 이동 또는 대기
```

### 예시 3: Task 완료 (정상)

```markdown
Input:
Epic: EP004
Task: T001-S01
Action: complete
Details: Component 구조 구현 완료, 3개 파일 변경

실행:
1. Read: "- [🔄] T001-S01: Component Structure (시작: 14:23)"
2. 검증: [🔄] → [✅] 허용 ✅
3. Edit:
   old: "- [🔄] T001-S01: Component Structure (시작: 14:23)"
   new: "- [✅] T001-S01: Component Structure (완료: 14:45)"
4. 성공 ✅
5. Changelog 추가
6. 진행률 계산: 1/10 (10%)

Output:
✅ Task T001-S01 completed successfully
- 상태: [🔄] → [✅]
- 소요 시간: 22분
- 진행률: 1/10 Tasks (10%)
```

---

## 🚨 에러 처리

### 일반 에러

```yaml
Epic 없음:
  "❌ Epic ${EPIC_ID}를 찾을 수 없습니다"

PROGRESS.md 없음:
  "❌ PROGRESS.md가 존재하지 않습니다: ${progress_file}"

Task 없음:
  "❌ Task ${TASK_ID}를 PROGRESS.md에서 찾을 수 없습니다"

잘못된 상태 전이:
  "❌ 잘못된 상태 전이: ${OLD_STATE} → ${NEW_STATE}"
  "현재 상태: ${OLD_STATE}"
  "허용되는 Action: ${ALLOWED_ACTIONS}"
```

### 충돌 에러 (Optimistic Lock 실패)

```yaml
Edit 실패 + Re-read 성공:
  "⚠️ 충돌 감지: 다른 Agent가 먼저 업데이트"
  "예상 상태: ${EXPECTED}"
  "실제 상태: ${ACTUAL}"

의도한 상태와 동일:
  "✅ 다른 세션에서 이미 ${ACTION}되었습니다"

의도한 상태와 다름:
  "❌ 충돌: 다른 작업이 필요합니다"
  "권장 조치: ${SUGGESTION}"
```

### 재시도 실패

```yaml
3회 재시도 후에도 실패:
  "❌ Task ${TASK_ID} ${ACTION} 실패 (3회 재시도)"
  "원인: 지속적인 충돌"
  "권장: 수동 확인 필요"
```

---

## ✅ 성공 기준

- Edit 성공 ✅
- Read 검증 확인 ✅
- Changelog 추가 ✅
- (complete 시) 진행률 업데이트 ✅

---

## 🔄 code-writer 통합 예시

```markdown
# code-writer.md

## Task 시작 시 (MANDATORY)

1. **상태 확인:**
   SlashCommand "/code-writer/check-task-status ${TASK_ID}"

2. **결과 판단:**
   - AVAILABLE → 계속 진행
   - IN_PROGRESS → "⚠️ 다른 Agent 작업 중" 알림
   - COMPLETED → "✅ 이미 완료됨" 알림

3. **업데이트 요청:**
   Task --subagent_type "99-utils/progress-updater"
        --prompt "Epic: ${EPIC_ID}, Task: ${TASK_ID}, Action: start"

4. **실패 처리:**
   - 충돌 감지 시: 다음 Task로 이동
   - 에러 발생 시: 사용자에게 보고

## Task 완료 시 (MANDATORY)

5. **업데이트 요청:**
   Task --subagent_type "99-utils/progress-updater"
        --prompt "Epic: ${EPIC_ID}, Task: ${TASK_ID}, Action: complete, Details: ${SUMMARY}"
```

---

## 📋 Mission 2: Compact Recovery

### 🎯 목적
Auto-Compact (context 100%) 또는 MicroCompact (tool result 자동 제거) 발생 시 작업 컨텍스트를 자동으로 복구하여 사용자 개입 없이 작업을 이어서 진행합니다.

### 🔄 3-Hook Recovery System

#### Stop Hook: auto-save
**Trigger**: 매 응답마다 (2초 throttle)
**Command**: `/progress:auto-save`
**목적**: MicroCompact 대비 실시간 상태 저장

상세 로직 → `.claude/commands/progress-updater/auto-save.md`

#### PreCompact Hook: save-checkpoint
**Trigger**: Auto-Compact 직전
**Command**: `/progress:save-checkpoint`
**목적**: Auto-Compact 직전 완전한 체크포인트 저장

상세 로직 → `.claude/commands/progress-updater/save-checkpoint.md`

#### SessionStart Hook: auto-resume
**Trigger**: 세션 시작 시
**Command**: `/progress:auto-resume`
**목적**: Compact 후 자동 복구 및 작업 재개

상세 로직 → `.claude/commands/progress-updater/auto-resume.md`

### 📁 State File

**경로**: `.claude/compact-state.json` (gitignore에 추가됨)

**구조**: `@docs/analysis/compact-recovery-implementation-spec.md#state-file-structure` 참조

### ✅ 효과

```yaml
자동화율: 95-100%
사용자 개입: 0회
복구 시간: <3초
컨텍스트 복구율: 100%
```

---

*Standards: KISS·YAGNI·DRY | LLM-First Design*
*Version: 3.0 (Compact Recovery)*
