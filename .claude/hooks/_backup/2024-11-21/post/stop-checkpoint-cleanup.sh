#!/usr/bin/env bash
# Stop Hook: Checkpoint Cleanup
# Cleans up old checkpoints (7+ days) and generates recovery guides

set -e
trap 'exit 0' ERR

# Read stdin (required by Claude Code)
event_info=$(cat)

CHECKPOINT_DIR="/Users/yun/work/workspace/breeze_sample/okr2/.claude/checkpoints"
[[ ! -d "$CHECKPOINT_DIR" ]] && exit 0

# Find 7+ day old checkpoints
find "$CHECKPOINT_DIR" -name "*.json" -type f -mtime +7 2>/dev/null | while read -r checkpoint_file; do
    EPIC_ID=$(basename "$checkpoint_file" .json)
    BRANCH_NAME=$(grep -o '"checkpoint_branch":"[^"]*"' "$checkpoint_file" | cut -d'"' -f4)

    echo "⚠️  Old checkpoint detected: $EPIC_ID (7+ days)"
    echo "   Branch: $BRANCH_NAME"

    # Ask user
    read -p "   Delete? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git branch -D "$BRANCH_NAME" 2>/dev/null || true
        rm -f "$checkpoint_file"
        echo "   ✅ Deleted"
    fi
done

# Generate stats
TOTAL=$(find "$CHECKPOINT_DIR" -name "*.json" | wc -l | tr -d ' ')
echo ""
echo "📊 Checkpoint Statistics:"
echo "   Total active checkpoints: $TOTAL"

exit 0
