#!/bin/bash
# Hook 테스트 자동화 스크립트

echo "🧪 Hook 테스트 시작..."
echo ""

# 테스트 카운터
TOTAL=0
PASSED=0
FAILED=0

# 테스트 결과 저장
RESULTS=()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_hook() {
    local hook_name="$1"
    local hook_path=".claude/hooks/$hook_name"
    local test_input="$2"
    local test_type="$3"

    TOTAL=$((TOTAL + 1))

    if [[ ! -f "$hook_path" ]]; then
        echo "⏭️  Skip: $hook_name (파일 없음)"
        return
    fi

    # 실행 권한 확인
    if [[ ! -x "$hook_path" ]]; then
        echo "❌ FAIL: $hook_name (실행 권한 없음)"
        FAILED=$((FAILED + 1))
        RESULTS+=("❌ $hook_name - No execute permission")
        return
    fi

    # Hook 실행
    local output
    local exit_code
    output=$(echo "$test_input" | "$hook_path" 2>&1)
    exit_code=$?

    # Exit code 검증 (항상 0이어야 함)
    if [[ $exit_code -ne 0 ]]; then
        echo "❌ FAIL: $hook_name ($test_type - Exit code: $exit_code)"
        FAILED=$((FAILED + 1))
        RESULTS+=("❌ $hook_name - $test_type failed (exit $exit_code)")
    else
        echo "✅ PASS: $hook_name ($test_type)"
        PASSED=$((PASSED + 1))
        RESULTS+=("✅ $hook_name - $test_type passed")
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Cases
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NORMAL_INPUT='{"prompt": "테스트 메시지"}'
EMPTY_INPUT=''
INVALID_JSON='invalid json'

# user-prompt-submit Hook
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: user-prompt-submit.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_hook "user-prompt-submit.sh" "$NORMAL_INPUT" "Normal Input"
test_hook "user-prompt-submit.sh" "$EMPTY_INPUT" "Empty Input"
test_hook "user-prompt-submit.sh" "$INVALID_JSON" "Invalid JSON"
echo ""

# stop-quality-gate Hook
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: stop-quality-gate.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_hook "stop-quality-gate.sh" "$NORMAL_INPUT" "Normal Input"
test_hook "stop-quality-gate.sh" "$EMPTY_INPUT" "Empty Input"
echo ""

# stop-pattern-learning Hook
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: stop-pattern-learning.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_hook "stop-pattern-learning.sh" "$NORMAL_INPUT" "Normal Input"
test_hook "stop-pattern-learning.sh" "$EMPTY_INPUT" "Empty Input"
echo ""

# stop-dependency-validator Hook
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: stop-dependency-validator.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_hook "stop-dependency-validator.sh" "$NORMAL_INPUT" "Normal Input"
test_hook "stop-dependency-validator.sh" "$EMPTY_INPUT" "Empty Input"
echo ""

# user-prompt-pattern-suggester Hook
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: user-prompt-pattern-suggester.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_hook "user-prompt-pattern-suggester.sh" "$NORMAL_INPUT" "Normal Input"
test_hook "user-prompt-pattern-suggester.sh" "$EMPTY_INPUT" "Empty Input"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 테스트 결과"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total:  $TOTAL"
echo "Passed: $PASSED ✅"
echo "Failed: $FAILED ❌"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo "⚠️  실패한 테스트:"
    for result in "${RESULTS[@]}"; do
        if [[ "$result" =~ ^❌ ]]; then
            echo "  $result"
        fi
    done
    echo ""
    exit 1
else
    echo "🎉 모든 테스트 통과!"
    exit 0
fi
