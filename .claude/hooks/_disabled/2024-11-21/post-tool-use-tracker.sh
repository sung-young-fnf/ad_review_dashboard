#!/bin/bash
set -e

# Post-tool-use hook that tracks edited files for quality gate analysis
# This runs after Edit, MultiEdit, or Write tools complete successfully

# Read tool information from stdin
tool_info=$(cat)

# Extract relevant data
tool_name=$(echo "$tool_info" | jq -r '.tool_name // empty')
file_path=$(echo "$tool_info" | jq -r '.tool_input.file_path // empty')
session_id=$(echo "$tool_info" | jq -r '.session_id // empty')

# Skip if not an edit tool or no file path
if [[ ! "$tool_name" =~ ^(Edit|MultiEdit|Write)$ ]] || [[ -z "$file_path" ]]; then
    exit 0
fi

# Skip markdown files (documentation)
if [[ "$file_path" =~ \.(md|markdown)$ ]]; then
    exit 0
fi

# Create cache directory in project
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cache_dir="$PROJECT_ROOT/.claude/hooks-cache/${session_id:-default}"
mkdir -p "$cache_dir"

# Function to classify file type for quality analysis
classify_file_type() {
    local file="$1"

    case "$file" in
        *.tsx|*.jsx)
            echo "react"
            ;;
        *.ts)
            if [[ "$file" =~ /api/ ]] || [[ "$file" =~ route\.ts$ ]]; then
                echo "api"
            else
                echo "typescript"
            fi
            ;;
        *.js)
            echo "javascript"
            ;;
        *.prisma|*.sql)
            echo "database"
            ;;
        *.json|*.yaml|*.yml)
            echo "config"
            ;;
        *)
            echo "other"
            ;;
    esac
}

# Classify file and determine risk level
file_type=$(classify_file_type "$file_path")
risk_level="medium"

# Higher risk for certain file types
case "$file_type" in
    react)
        risk_level="high"  # React hooks risk
        ;;
    api)
        risk_level="high"  # API security risk
        ;;
    database)
        risk_level="critical"  # DB schema risk
        ;;
esac

# Log edited file with metadata
timestamp=$(date +%s)
echo "$timestamp:$file_path:$file_type:$risk_level" >> "$cache_dir/edited-files.log"

# Track file types for quality gate analysis
echo "$file_type" >> "$cache_dir/file-types.txt"

# Exit cleanly
exit 0