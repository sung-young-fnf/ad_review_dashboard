#!/bin/bash
set -e

# UserPromptSubmit Hook: Pattern-Based Story Auto-Generator
# Wrapper for pattern-suggester.ts

cd "$CLAUDE_PROJECT_DIR/.claude/hooks"
cat | npx tsx user-prompt-pattern-suggester.ts
