#!/usr/bin/env bash
# Stop Hook: TRUST 5 Quality Validation
# Runs quality checks on recently modified files

set -e
trap 'exit 0' ERR

# Read stdin (required by Claude Code)
event_info=$(cat)

# Get recently modified TypeScript files
MODIFIED_FILES=$(git diff --name-only HEAD~1 2>/dev/null | grep -E '\.(ts|tsx)$' || true)

[[ -z "$MODIFIED_FILES" ]] && {
    echo "ℹ️  No TypeScript files modified"
    exit 0
}

echo "🔍 TRUST 5 Quality Validation"
echo ""

SCORE_CALCULATOR="/Users/yun/work/workspace/breeze_sample/okr2/.claude/utils/quality/score-calculator.js"
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0

while IFS= read -r file; do
    [[ ! -f "$file" ]] && continue

    ((TOTAL_FILES++))
    echo "📄 Checking: $file"

    RESULT=$(node "$SCORE_CALCULATOR" "$file" 2>&1 || true)
    SCORE=$(echo "$RESULT" | grep -o '"totalScore":[0-9]*' | cut -d':' -f2 || echo "0")

    if [[ $SCORE -ge 80 ]]; then
        echo "   ✅ Score: $SCORE/100 (PASS)"
        ((PASSED_FILES++))
    else
        echo "   ⚠️  Score: $SCORE/100 (NEEDS IMPROVEMENT)"
        ((FAILED_FILES++))

        # Show violations
        echo "$RESULT" | grep -A 10 '"violations"' | grep -v '^\[' | grep -v '^\]' || true
    fi
    echo ""
done <<< "$MODIFIED_FILES"

echo "📊 Summary: $PASSED_FILES/$TOTAL_FILES files passed (80+ score)"
echo ""

if [[ $FAILED_FILES -gt 0 ]]; then
    echo "💡 Suggestions:"
    echo "   - Review files with score < 80"
    echo "   - Run: node .claude/utils/quality/score-calculator.js <file>"
    echo "   - Fix violations before next commit"
fi

exit 0
