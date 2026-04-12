#!/bin/bash
# .claude/hooks/utils/hook-performance-tracker.sh
# Hook 성능 모니터링 유틸리티
# Usage: source hook-performance-tracker.sh 후 track_performance "hook-name"

set -e

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PERF_LOG="$REPO_ROOT/.claude/logs/hook-performance.json"

# ============================================================================
# Performance Tracking Functions
# ============================================================================

init_performance_log() {
    local log_dir=$(dirname "$PERF_LOG")
    mkdir -p "$log_dir"

    if [[ ! -f "$PERF_LOG" ]]; then
        echo "{}" > "$PERF_LOG"
    fi
}

start_timer() {
    # Store start time in global variable (milliseconds)
    # macOS 호환: Python 사용
    if command -v python3 &> /dev/null; then
        HOOK_START_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
    else
        # Fallback: 초 단위
        HOOK_START_TIME=$(($(date +%s) * 1000))
    fi
}

end_timer() {
    local hook_name="$1"

    # macOS 호환: Python 사용
    if command -v python3 &> /dev/null; then
        local end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    else
        # Fallback: 초 단위
        local end_time=$(($(date +%s) * 1000))
    fi

    local elapsed_ms=$((end_time - HOOK_START_TIME))

    # bc가 없으면 awk로 계산
    if command -v bc &> /dev/null; then
        local elapsed_sec=$(echo "scale=2; $elapsed_ms / 1000" | bc)
    else
        local elapsed_sec=$(awk "BEGIN {printf \"%.2f\", $elapsed_ms/1000}")
    fi

    # Log to stderr (visible to user)
    echo "[performance] $hook_name: ${elapsed_sec}s" >&2

    # Update performance log
    update_performance_log "$hook_name" "$elapsed_ms"

    # Warn if slow (> 10 seconds)
    if [ "$elapsed_ms" -gt 10000 ]; then
        echo "⚠️ Hook 성능 경고: $hook_name (${elapsed_sec}s)" >&2
    fi
}

update_performance_log() {
    local hook_name="$1"
    local elapsed_ms=$2

    init_performance_log

    # jq가 없으면 경고 (한 번만)
    if ! command -v jq &> /dev/null; then
        local warning_flag="$(dirname "$PERF_LOG")/.jq-warning-shown"

        if [[ ! -f "$warning_flag" ]]; then
            cat >&2 <<'EOF'

⚠️  jq 미설치 감지 - Hook 성능 로그 기능 비활성화

Hook 성능 추적을 위해 jq 설치가 필요합니다:

  macOS (Homebrew):
    brew install jq

  Linux (Debian/Ubuntu):
    sudo apt-get install jq

  Linux (RHEL/CentOS):
    sudo yum install jq

설치 후 Hook이 자동으로 성능 데이터를 수집합니다.
(이 메시지는 한 번만 표시됩니다)

EOF
            touch "$warning_flag"
        fi

        return 0
    fi

    # Load current stats
    local current_stats=$(cat "$PERF_LOG" 2>/dev/null || echo "{}")

    # Update stats (avg, max, count)
    local new_stats=$(echo "$current_stats" | jq --arg name "$hook_name" --argjson ms "$elapsed_ms" '
        .[$name] = (
            .[$name] // {avg: 0, max: 0, count: 0} |
            {
                avg: (((.avg * .count) + $ms) / (.count + 1)),
                max: ([.max, $ms] | max),
                count: (.count + 1),
                last_run: $ms
            }
        )
    ')

    echo "$new_stats" > "$PERF_LOG"
}

get_performance_stats() {
    local hook_name="$1"

    if [[ ! -f "$PERF_LOG" ]]; then
        echo "No performance data"
        return
    fi

    if ! command -v jq &> /dev/null; then
        echo "jq not installed"
        return
    fi

    jq -r --arg name "$hook_name" '
        .[$name] // {} |
        "Avg: \(.avg // 0 | tonumber / 1000 | floor / 1000)s, Max: \(.max // 0 | tonumber / 1000 | floor / 1000)s, Count: \(.count // 0)"
    ' "$PERF_LOG"
}

list_slow_hooks() {
    local threshold_ms=${1:-10000}  # Default 10 seconds

    if [[ ! -f "$PERF_LOG" ]]; then
        echo "No performance data"
        return
    fi

    if ! command -v jq &> /dev/null; then
        echo "jq not installed"
        return
    fi

    echo "Slow Hooks (> ${threshold_ms}ms):"
    jq -r --argjson threshold "$threshold_ms" '
        to_entries |
        map(select(.value.max > $threshold)) |
        sort_by(-.value.max) |
        .[] |
        "  \(.key): \(.value.max / 1000)s (max), \(.value.avg / 1000)s (avg)"
    ' "$PERF_LOG"
}

# ============================================================================
# Convenience Wrapper
# ============================================================================

track_performance() {
    local hook_name="$1"
    shift
    local command="$@"

    start_timer
    eval "$command"
    local exit_code=$?
    end_timer "$hook_name"

    return $exit_code
}

# ============================================================================
# Export Functions
# ============================================================================

export -f init_performance_log
export -f start_timer
export -f end_timer
export -f update_performance_log
export -f get_performance_stats
export -f list_slow_hooks
export -f track_performance
