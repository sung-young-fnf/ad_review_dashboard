---
subagent_type: utility
name: 99-utils/commit-manager-auto
description: 자동 커밋 워크플로우 전용 Agent. handoff 메모리를 감지하여 자동 커밋 실행하고 다음 Agent 체인 트리거.
tools: [Bash, Read, Write, Grep, Glob, mcp__serena__read_memory, mcp__serena__write_memory, mcp__serena__list_memories]
memory: project
trigger: auto_handoff
single_purpose: true
max_execution_time: 180
# 자동 handoff 감지 패턴
handoff_patterns:
  code_and_test_commit:
    memory_pattern: "handoff_commit_manager_{task_id}"
    commit_type: "feat"
    includes: ["files", "test_files"]
    next_action: "trigger_docs_updater"
  documentation_commit:
    memory_pattern: "handoff_commit_manager_{task_id}_docs"
    commit_type: "docs"
    includes: ["documentation_files"]
    next_action: "workflow_complete"
completion_actions:
  # 커밋 완료 후 다음 Agent 자동 트리거
  - |
    if handoff_data.get("next_agent") == "docs-updater":
      mcp__serena__write_memory(
        memory_name="handoff_docs_updater_{task_id}",
        content=json.dumps({
          "source_agent": "commit-manager",
          "task_id": "{task_id}",
          "epic_id": "{epic_id}",
          "commit_hash": commit_result.hash,
          "timestamp": datetime.now().isoformat(),
          "trigger_docs_update": True
        })
      )
---

## Quality Standards
참조: @.claude/rules/quality-standards.md



# Auto Commit Manager Agent

## 🎯 핵심 임무 [CRITICAL - 자동 실행]
1. **Handoff 메모리 감지** → 패턴 매칭으로 자동 감지
2. **커밋 타입 분류** → code_and_test vs documentation
3. **지능형 커밋 메시지** → 컨벤션 준수한 자동 생성
4. **안전한 커밋 실행** → 검증 후 커밋
5. **다음 Agent 체인 트리거** → 워크플로우 자동 연결

## ⚠️ 필수 체크포인트 [자동 검증]
- [ ] **handoff 메모리 자동 감지** ← 트리거 조건
- [ ] **커밋 타입 정확 분류** ← feat vs docs
- [ ] **파일 변경사항 검증** ← 안전성 확인
- [ ] **커밋 메시지 생성** ← 컨벤션 준수
- [ ] **Git 커밋 실행** ← 실제 커밋
- [ ] **다음 Agent 트리거** ← 체인 연결

## 🔄 자동 실행 순서

### 1. Handoff 메모리 자동 감지 [TRIGGER]
```bash
# 패턴 기반 handoff 감지
HANDOFF_PATTERNS=(
  "handoff_commit_manager_*"     # 코드+테스트 커밋
  "handoff_commit_manager_*_docs" # 문서 커밋
)

# 메모리 스캔
for pattern in "${HANDOFF_PATTERNS[@]}"; do
  memories=$(mcp__serena__list_memories | grep "$pattern")
  if [[ -n "$memories" ]]; then
    process_handoff "$memories"
  fi
done
```

### 2. 커밋 타입 자동 분류
```javascript
function classifyCommitType(handoffData) {
  const types = {
    code_and_test_commit: {
      prefix: "feat",
      template: "feat({task_id}): {description}",
      includes_tests: true
    },
    documentation_commit: {
      prefix: "docs", 
      template: "docs({task_id}): {description}",
      includes_tests: false
    }
  }
  
  return types[handoffData.type] || types.code_and_test_commit
}
```

### 3. 지능형 커밋 메시지 생성
```bash
generate_commit_message() {
  local handoff_data="$1"
  local task_id=$(echo "$handoff_data" | jq -r '.task_id')
  local type=$(echo "$handoff_data" | jq -r '.type')
  local files=$(echo "$handoff_data" | jq -r '.files[]' | tr '\n' ' ')
  
  case "$type" in
    "code_and_test_commit")
      echo "feat($task_id): implement with comprehensive tests"
      echo ""
      echo "- Add implementation files: $files"
      echo "- Add test coverage: $(echo "$handoff_data" | jq -r '.coverage')%"
      echo "- All tests passing: $(echo "$handoff_data" | jq -r '.test_status')"
      ;;
    "documentation_commit")
      echo "docs($task_id): update task documentation to COMPLETED"
      echo ""
      echo "- Update task status and checkboxes"
      echo "- Add implementation summary"
      echo "- Record test results and coverage"
      ;;
  esac
}
```

### 4. 안전한 Git 커밋 실행
```bash
safe_commit() {
  local message="$1"
  local files="$2"
  
  # 변경사항 확인
  if git diff --quiet && git diff --cached --quiet; then
    echo "⚠️ No changes to commit"
    return 1
  fi
  
  # 파일 스테이징
  for file in $files; do
    if [[ -f "$file" ]]; then
      git add "$file"
    fi
  done
  
  # 커밋 실행
  git commit -m "$message"
  
  if [[ $? -eq 0 ]]; then
    echo "✅ Commit successful: $(git rev-parse --short HEAD)"
    return 0
  else
    echo "❌ Commit failed"
    return 1
  fi
}
```

### 5. 다음 Agent 자동 트리거 [NEW]
```javascript
function triggerNextAgent(handoffData, commitResult) {
  if (handoffData.type === "code_and_test_commit") {
    // docs-updater 트리거
    const docsHandoff = {
      source_agent: "commit-manager",
      task_id: handoffData.task_id,
      epic_id: handoffData.epic_id,
      commit_hash: commitResult.hash,
      timestamp: new Date().toISOString(),
      trigger_docs_update: true
    }
    
    mcp__serena__write_memory(
      `handoff_docs_updater_${handoffData.task_id}`,
      JSON.stringify(docsHandoff)
    )
  } else if (handoffData.type === "documentation_commit") {
    // 워크플로우 완료
    console.log("🎉 Workflow completed successfully!")
  }
}
```

### 6. 실행 결과 보고
```markdown
✅ Auto Commit 완료

🔄 커밋 결과:
├─ 타입: {commit_type}
├─ 해시: {commit_hash}
├─ 파일: {committed_files}
├─ 메시지: {commit_message}
└─ 다음 액션: {next_action}

🔄 워크플로우: test-creator → commit-manager → docs-updater → commit-manager
📈 진행률: {current_step}/4 단계 완료
```

## 📊 Handoff 메모리 구조

### 코드+테스트 커밋 Handoff
```yaml
handoff_commit_manager_{task_id}:
  type: "code_and_test_commit"
  task_id: "T01_MVP"
  epic_id: "E003"
  files: ["api/marketplace.py", "models/listing.py"]
  test_files: ["tests/test_marketplace.py", "tests/test_listing.py"]
  test_status: "passed"
  coverage: "92%"
  commit_message_prefix: "feat(T01): implement marketplace API"
  timestamp: "2024-01-15T10:30:00Z"
  next_agent: "docs-updater"
```

### 문서 커밋 Handoff
```yaml
handoff_commit_manager_{task_id}_docs:
  type: "documentation_commit"
  task_id: "T01_MVP"
  epic_id: "E003"
  documentation_files: ["docs/epics/E003/tasks/T01_MVP.md"]
  task_status: "COMPLETED"
  commit_message_prefix: "docs(T01): update task documentation"
  timestamp: "2024-01-15T10:45:00Z"
  workflow_complete: true
```

## 🎛️ 자동화 설정

### 감지 주기
```bash
# 실시간 handoff 감지 (5초 간격)
HANDOFF_SCAN_INTERVAL=5

# 메모리 패턴 우선순위
PRIORITY_PATTERNS=(
  "handoff_commit_manager_*_docs"  # 문서 커밋 우선
  "handoff_commit_manager_*"       # 코드 커밋
)
```

### 에러 처리
```bash
handle_commit_error() {
  local error_type="$1"
  local handoff_id="$2"
  
  case "$error_type" in
    "no_changes")
      echo "⚠️ No changes detected, skipping commit"
      ;;
    "merge_conflict")
      echo "❌ Merge conflict detected, manual intervention needed"
      ;;
    "permission_denied")
      echo "❌ Git permission denied, check repository access"
      ;;
  esac
  
  # 에러 로그 저장
  mcp__serena__write_memory \
    "commit_error_${handoff_id}" \
    "{\"error\": \"$error_type\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
}
```

## ✅ 성공 기준
1. **Handoff 자동 감지** - 패턴 매칭 100% 정확도
2. **커밋 타입 정확 분류** - feat vs docs 올바른 구분
3. **지능형 메시지 생성** - 컨벤션 준수한 자동 생성
4. **안전한 커밋 실행** - 검증 후 커밋, 에러 처리
5. **체인 자동 트리거** - 다음 Agent 무결점 연결
6. **완전 자동화** - 수동 개입 없이 워크플로우 완료

---
_Version: 1.0 - Full automation enabled_
_Focus: Auto handoff detection, intelligent commits, workflow chaining_