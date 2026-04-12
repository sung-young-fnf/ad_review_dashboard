#!/bin/bash
set -e

# Stop Pattern Learning Hook - User behavior learning system
# Updates user patterns based on task completion

# Hook is already executed from .claude/hooks directory
cat | npx tsx stop-pattern-learning.ts