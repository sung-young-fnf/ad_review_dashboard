#!/bin/bash
# ============================================================================
# Background Agent Trigger Hook
# ============================================================================
# Triggers: PostToolUse (Edit, Write, MultiEdit)
# Purpose: 코드 변경 후 test-watcher와 docs-sync 백그라운드 실행
# Version: 1.0.0
# ============================================================================

# Graceful Degradation: hook failure should never block the agent
trap 'exit 0' ERR

# Read hook input from stdin
INPUT=$(cat 2>/dev/null || echo "")

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only trigger for code modification tools
case "$TOOL_NAME" in
  Edit|Write|MultiEdit)
    ;;
  *)
    exit 0
    ;;
esac

# Extract file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)

# Skip non-code files
case "$FILE_PATH" in
  *.md|*.log|*.json|*.lock|*.css|*.scss)
    exit 0
    ;;
  *node_modules*|*.git*|*dist/*|*build/*)
    exit 0
    ;;
esac

# Skip if file is in .claude directory (avoid recursive triggers)
if [[ "$FILE_PATH" == *".claude/"* ]]; then
  exit 0
fi

# Create trigger marker file for background agents
TRIGGER_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/.triggers"
mkdir -p "$TRIGGER_DIR" 2>/dev/null || exit 0

# Record the changed file for background agents
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "$FILE_PATH" >> "$TRIGGER_DIR/pending_$TIMESTAMP.txt"

# Output minimal JSON (no systemMessage to avoid noise)
cat << 'EOF'
{
  "continue": true
}
EOF
