#!/bin/bash
set -e

# Stop Event Hook: Epic Dependency Validator
# Wrapper for dependency-validator.ts

cd "$CLAUDE_PROJECT_DIR/.claude/hooks"
cat | npx tsx stop-dependency-validator.ts
