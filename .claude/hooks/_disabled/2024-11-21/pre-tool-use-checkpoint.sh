#!/usr/bin/env bash
# PreToolUse Hook: Auto Checkpoint for Risky Epics
# Triggers when Write tool is used on epic.md files

set -e
trap 'exit 0' ERR

# Check if Write tool
TOOL_NAME="${1:-}"
[[ "$TOOL_NAME" != "Write" ]] && exit 0

# Check if epic.md file
FILE_PATH="${2:-}"
[[ ! "$FILE_PATH" =~ epic\.md$ ]] && exit 0

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../utils && pwd)"
source "${SCRIPT_DIR}/risk-detector.sh" 2>/dev/null || exit 0

# Detect risk
RISK_JSON=$(detect_risky_epic "$FILE_PATH" 2>/dev/null) || exit 0

# Check if HIGH risk
RISK_LEVEL=$(echo "$RISK_JSON" | grep -o '"risk_level":"[^"]*"' | cut -d'"' -f4)
[[ "$RISK_LEVEL" != "HIGH" ]] && [[ "$RISK_LEVEL" != "CRITICAL" ]] && exit 0

# Extract Epic ID
EPIC_ID=$(echo "$RISK_JSON" | grep -o '"epic_id":"[^"]*"' | cut -d'"' -f4)

# Check existing checkpoint
CHECKPOINT_DIR="/Users/yun/work/workspace/breeze_sample/okr2/.claude/checkpoints"
mkdir -p "$CHECKPOINT_DIR"
CHECKPOINT_FILE="$CHECKPOINT_DIR/${EPIC_ID}.json"

[[ -f "$CHECKPOINT_FILE" ]] && {
    echo "ℹ️  Checkpoint already exists for $EPIC_ID"
    exit 0
}

# Create checkpoint
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BRANCH_NAME="checkpoint/EP${EPIC_ID}_${TIMESTAMP}"

# Git operations
cd "$(dirname "$FILE_PATH")/../.." || exit 0

git stash push -u -m "Auto-backup before checkpoint $EPIC_ID" &>/dev/null || true
git checkout -b "$BRANCH_NAME" &>/dev/null || true
git add -A &>/dev/null || true
git commit -m "Checkpoint: $EPIC_ID before risky changes" &>/dev/null || true
git checkout - &>/dev/null || true
git stash pop &>/dev/null || true

# Save metadata
cat > "$CHECKPOINT_FILE" <<EOF
{
  "epic_id": "$EPIC_ID",
  "checkpoint_branch": "$BRANCH_NAME",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "risk_level": "$RISK_LEVEL"
}
EOF

echo "✅ Checkpoint created: $BRANCH_NAME"
echo "   Use /epic-rollback $EPIC_ID for recovery"

exit 0
