#!/bin/bash
set -e

# Stop Quality Gate Hook - Reddit Stop Event Hook pattern
# Runs after Claude finishes responding to analyze code quality

cd "$CLAUDE_PROJECT_DIR/.claude/hooks"
cat | npx tsx stop-quality-gate.ts