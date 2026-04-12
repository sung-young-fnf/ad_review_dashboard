#!/bin/bash
# .claude/hooks/post/self-improve-recorder.sh
# Self-Improving Agent: SubagentStop 시 실패/학습 자동 기록
# Version: 1.0

trap 'exit 0' ERR

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LEARNINGS_DIR="$REPO_ROOT/.claude/learnings"
ERRORS_FILE="$LEARNINGS_DIR/ERRORS.md"
CHANGELOG_FILE="$LEARNINGS_DIR/CHANGELOG.md"

mkdir -p "$LEARNINGS_DIR"

# stdin 읽기
if [ ! -t 0 ]; then
  event_info=$(cat 2>/dev/null || echo "")
else
  event_info=""
fi

# Agent 정보 추출
AGENT_TYPE=$(echo "$event_info" | jq -r '.agent_type // empty' 2>/dev/null || echo "")
AGENT_ID=$(echo "$event_info" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
LAST_MSG=$(echo "$event_info" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")
AGENT_TYPE="${AGENT_TYPE:-${CLAUDE_AGENT_TYPE:-unknown}}"

TODAY=$(date +"%Y-%m-%d")
NOW=$(date +"%Y-%m-%d %H:%M")

# ============================================================================
# 1. 에러 감지 → ERRORS.md 자동 기록
# ============================================================================
record_error() {
  local error_count=0
  local error_lines=""

  if [[ -n "$LAST_MSG" ]]; then
    # 마지막 메시지의 처음 20줄만 분석 (코드 본문의 문자열 리터럴 오탐 방지)
    local msg_head=$(echo "$LAST_MSG" | head -20)

    # === 성공 패턴 조기 종료 (Insights P1 — ERRORS.md 오탐 방지) ===
    # "타입 에러 0개", "빌드 성공", "통과" 등은 성공이므로 에러로 기록하지 않음
    if echo "$msg_head" | grep -qiE "(에러 0개|오류 0개|0 errors|통과했습니다|성공적으로 완료|빌드 성공|BUILD SUCCESS|All checks passed)"; then
      return 0
    fi

    # 1단계: 구조적 에러 패턴만 감지 (코드 안의 문자열 제외)
    # - 줄 시작이 에러 키워드 (로그 출력 패턴)
    # - "error:" 단독이 아닌, 실제 에러 보고 패턴
    error_lines=$(echo "$msg_head" | grep -E "^(ERROR|TypeError|SyntaxError|ReferenceError|Build failed|Module not found|Cannot find module|ENOENT|EPERM|ExitCode [1-9])" 2>/dev/null | head -5 || true)

    # 2단계: 에이전트가 명시적으로 실패를 보고한 경우
    local explicit_fail=$(echo "$msg_head" | grep -iE "^(❌|실패|FAIL:|빌드 실패|타입 에러[^0]|컴파일 에러)" 2>/dev/null | head -3 || true)
    if [[ -n "$explicit_fail" ]]; then
      error_lines="${error_lines}
${explicit_fail}"
    fi

    # 빈 줄 제거 후 카운트
    error_lines=$(echo "$error_lines" | sed '/^$/d')
    error_count=$(echo "$error_lines" | grep -c . 2>/dev/null || echo 0)
  fi

  if [[ "$error_count" -gt 0 ]]; then
    # 최근 커밋 해시
    local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
    # 변경된 파일
    local changed_files=$(git diff --name-only HEAD 2>/dev/null | head -5 | tr '\n' ', ' || echo "none")

    # ERRORS.md에 추가 (prepend 방식 - 최신이 위로)
    local temp_file=$(mktemp)
    {
      head -n 12 "$ERRORS_FILE"  # 헤더 유지
      echo ""
      echo "## [$NOW] $AGENT_TYPE | $commit_hash"
      echo "- **Error**: $(echo "$error_lines" | head -3 | sed 's/^/  /')"
      echo "- **Files**: $changed_files"
      echo "- **Agent ID**: $AGENT_ID"
      echo ""
      tail -n +13 "$ERRORS_FILE"  # 기존 내용
    } > "$temp_file"
    mv "$temp_file" "$ERRORS_FILE"

    echo "Self-Improve: Error recorded in ERRORS.md ($error_count errors from $AGENT_TYPE)" >&2
  fi
}

# ============================================================================
# 2. 변경 기록 → CHANGELOG.md 자동 업데이트
# ============================================================================
record_changelog() {
  # 변경된 파일이 있을 때만 기록
  local modified_files=$(git diff --name-only HEAD 2>/dev/null || echo "")
  if [[ -z "$modified_files" ]]; then
    return 0
  fi

  local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
  local file_count=$(echo "$modified_files" | wc -l | tr -d ' ')
  local file_list=$(echo "$modified_files" | head -5 | tr '\n' ', ')

  # 중복 방지: 같은 커밋 해시가 이미 있으면 스킵
  if grep -q "$commit_hash" "$CHANGELOG_FILE" 2>/dev/null; then
    return 0
  fi

  local temp_file=$(mktemp)
  {
    head -n 10 "$CHANGELOG_FILE"
    echo ""
    echo "## [$NOW] $commit_hash"
    echo "- **Agent**: $AGENT_TYPE"
    echo "- **Scope**: ${file_count} files — $file_list"
    echo "- **Uncommitted**: yes (pending commit)"
    echo ""
    tail -n +11 "$CHANGELOG_FILE"
  } > "$temp_file"
  mv "$temp_file" "$CHANGELOG_FILE"
}

# ============================================================================
# 3. 반복 에러 감지 → Rule Promotion 제안
# ============================================================================
detect_repeats_and_promote() {
  local errors_file="$ERRORS_FILE"
  local learnings_file="$LEARNINGS_DIR/LEARNINGS.md"
  local promoted_file="$REPO_ROOT/.claude/rules/auto-promoted.md"

  mkdir -p "$(dirname "$promoted_file")"

  # === ERRORS.md: 에이전트 타입별 반복 에러 자동 승격 ===
  if [[ -f "$errors_file" ]]; then
    local agent_error_count=$(grep -c "## \[.*\] $AGENT_TYPE" "$errors_file" 2>/dev/null || echo "0")

    if [[ "$agent_error_count" -ge 3 ]]; then
      local top_error=$(grep -A1 "## \[.*\] $AGENT_TYPE" "$errors_file" 2>/dev/null | grep "\*\*Error\*\*" | sed 's/.*\*\*Error\*\*: //' | sort | uniq -c | sort -rn | head -1 | sed 's/^[[:space:]]*[0-9]*//' | xargs)

      # 이미 승격된 규칙인지 확인 (중복 방지 — 에이전트 타입 기준)
      if ! grep -qF "$AGENT_TYPE 반복 에러" "$promoted_file" 2>/dev/null; then
        # auto-promoted.md에 실제로 규칙 추가
        cat >> "$promoted_file" << RULE_EOF

## [$TODAY] $AGENT_TYPE 반복 에러 (${agent_error_count}회)
- **Pattern**: $top_error
- **Rule**: $AGENT_TYPE 실행 시 이 에러 패턴 사전 방지 필수
- **Source**: ERRORS.md 자동 감지
RULE_EOF

        cat << PROMOTE_EOF >&2

✅ [Self-Improve] AUTO-PROMOTED: $AGENT_TYPE 반복 에러 → .claude/rules/auto-promoted.md 에 규칙 추가됨
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
패턴: $top_error (${agent_error_count}회 반복)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROMOTE_EOF
      fi
    fi
  fi

  # === LEARNINGS.md: Count 3+ 교정 규칙 자동 승격 ===
  if [[ -f "$learnings_file" ]]; then
    # Count 3+ & Promoted: none 인 항목의 Rule 추출
    while IFS= read -r rule_line; do
      [[ -z "$rule_line" ]] && continue
      local rule_text=$(echo "$rule_line" | sed 's/^- \*\*Rule\*\*: //')

      # 이미 승격되었는지 확인
      if grep -qF "$rule_text" "$promoted_file" 2>/dev/null; then
        continue
      fi

      # auto-promoted.md에 추가
      cat >> "$promoted_file" << LEARN_RULE_EOF

## [$TODAY] 사용자 교정 반복 승격
- **Rule**: $rule_text
- **Source**: LEARNINGS.md (Count 3+)
LEARN_RULE_EOF

      # LEARNINGS.md에서 Promoted 상태 업데이트
      sed -i '' "s|$rule_text|$rule_text\n- **Promoted**: promoted_to:auto-promoted.md|" "$learnings_file" 2>/dev/null || true

      echo "✅ [Self-Improve] LEARNING PROMOTED: $rule_text → auto-promoted.md" >&2

    done < <(grep -B8 "^\- \*\*Promoted\*\*: none" "$learnings_file" 2>/dev/null | grep -B7 "^\- \*\*Count\*\*: [3-9]" 2>/dev/null | grep "^\- \*\*Rule\*\*:" | head -3 || true)
  fi
}

# 실행
record_error
record_changelog
detect_repeats_and_promote

exit 0
