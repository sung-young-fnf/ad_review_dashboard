#!/bin/bash
set -e

# PostToolUse Hook: Agent Handoff 감지 및 캐싱
# Serena MCP write_memory 감지 → Agent 결과 캐싱

# Read tool information from stdin
tool_info=$(cat)

# Extract relevant data
tool_name=$(echo "$tool_info" | jq -r '.tool_name // empty')
session_id=$(echo "$tool_info" | jq -r '.session_id // empty')

# Skip if not Serena MCP write_memory
if [[ "$tool_name" != "mcp__serena__write_memory" ]]; then
    exit 0
fi

# Extract memory name and content
memory_name=$(echo "$tool_info" | jq -r '.tool_input.memory_name // empty')
memory_content=$(echo "$tool_info" | jq -r '.tool_input.content // empty')

# Project root
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CACHE_BASE_DIR="$PROJECT_ROOT/.claude/agent-cache"

# Log file
LOG_FILE="$PROJECT_ROOT/.claude/hooks/agent-cache.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $1" >> "$LOG_FILE"
}

# Agent Handoff 패턴 감지
# Pattern: handoff_{source_agent}_{target_agent}_{epic/story/task_id}
if [[ "$memory_name" =~ ^handoff_ ]]; then
    log "Agent Handoff detected: $memory_name"

    # Extract agent names
    # Example: handoff_story-creator_task-planner_EP001-S01
    source_agent=$(echo "$memory_name" | cut -d'_' -f2)
    target_agent=$(echo "$memory_name" | cut -d'_' -f3)
    context_id=$(echo "$memory_name" | cut -d'_' -f4-)

    # Create cache directory
    cache_dir="$CACHE_BASE_DIR/$session_id"
    mkdir -p "$cache_dir"

    # Cache source agent result
    cache_file="$cache_dir/${source_agent}-context.json"

    # Build Agent result JSON
    cat > "$cache_file" <<EOF
{
  "agentName": "$source_agent",
  "sessionId": "$session_id",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "success",
  "data": {
    "handoffTo": "$target_agent",
    "contextId": "$context_id",
    "memoryName": "$memory_name",
    "memoryContent": $(echo "$memory_content" | jq -Rs .)
  },
  "metadata": {
    "handoffPattern": true
  }
}
EOF

    log "✅ Cached $source_agent result (handoff to $target_agent)"

    # Log cache stats
    cached_count=$(find "$cache_dir" -name "*-context.json" 2>/dev/null | wc -l | tr -d ' ')
    log "📊 Session $session_id: $cached_count agents cached"
fi

# Pattern: Epic/Story/Task 컨텍스트 저장
# Pattern: epic_EP001_context, story_EP001-S01_context, task_T001_context
if [[ "$memory_name" =~ _context$ ]]; then
    entity_type=$(echo "$memory_name" | cut -d'_' -f1)  # epic, story, task
    entity_id=$(echo "$memory_name" | sed -E 's/^[^_]+_([^_]+)_context$/\1/')

    if [[ "$entity_type" =~ ^(epic|story|task)$ ]]; then
        log "Entity context saved: $memory_name"

        cache_dir="$CACHE_BASE_DIR/$session_id"
        mkdir -p "$cache_dir"

        cache_file="$cache_dir/${entity_type}-${entity_id}-context.json"

        cat > "$cache_file" <<EOF
{
  "agentName": "${entity_type}-context",
  "sessionId": "$session_id",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "success",
  "data": {
    "entityType": "$entity_type",
    "entityId": "$entity_id",
    "memoryName": "$memory_name",
    "memoryContent": $(echo "$memory_content" | jq -Rs .)
  }
}
EOF

        log "✅ Cached $entity_type context: $entity_id"
    fi
fi

# Exit cleanly
exit 0
