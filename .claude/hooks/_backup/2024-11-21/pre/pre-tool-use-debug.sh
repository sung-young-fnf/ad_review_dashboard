#!/bin/bash
# Debug hook to diagnose PreToolUse:Read error
# Fixed: macOS compatible (replaced timeout with read -t)

# Log to stderr (will be visible in Claude Code)
echo "[DEBUG] Hook started" >&2
echo "[DEBUG] TOOL_NAME: ${CLAUDE_TOOL_NAME:-not_set}" >&2
echo "[DEBUG] Current directory: $(pwd)" >&2

# Try to read stdin with timeout (macOS compatible)
# read -t 1: Bash built-in, works on macOS
if read -t 1 INPUT; then
    echo "[DEBUG] stdin read successful (${#INPUT} bytes)" >&2
else
    echo "[DEBUG] stdin read failed or timed out" >&2
fi

# Always exit 0 to not block
exit 0
