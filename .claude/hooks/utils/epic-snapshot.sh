#!/bin/bash
# Epic Snapshot Manager — Phase 완료 시 Epic 상태 체크포인트 생성/복원
# ClawTeam SnapshotManager 패턴 참고: JSON 번들로 상태 저장
#
# 사용법:
#   epic-snapshot.sh create <epic-id> [tag]     — 스냅샷 생성
#   epic-snapshot.sh list   <epic-id>           — 스냅샷 목록
#   epic-snapshot.sh restore <epic-id> <snap-id> [--dry-run] — 복원
#   epic-snapshot.sh diff   <epic-id> <snap-id> — 현재 상태와 비교
#   epic-snapshot.sh delete <epic-id> <snap-id> — 스냅샷 삭제
#
# 저장소: docs/epics/{epic-dir}/.snapshots/snap-{timestamp}-{tag}.json

set -eo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
EPICS_DIR="$REPO_ROOT/docs/epics"

if ! command -v jq &>/dev/null; then
    echo "❌ jq required" >&2
    exit 1
fi

# Epic 디렉토리 찾기 (EP210 → EP210-warm-executor-code-interpreter 등)
find_epic_dir() {
    local epic_id="$1"
    # 정확히 일치하는 디렉토리 먼저
    if [ -d "$EPICS_DIR/$epic_id" ]; then
        echo "$EPICS_DIR/$epic_id"
        return
    fi
    # prefix 매칭
    local found
    found=$(find "$EPICS_DIR" -maxdepth 1 -type d -name "${epic_id}*" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return
    fi
    # 대소문자 무시
    found=$(find "$EPICS_DIR" -maxdepth 1 -type d -iname "${epic_id}*" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return
    fi
    echo ""
}

# 스냅샷 생성
create_snapshot() {
    local epic_id="$1"
    local tag="${2:-}"

    local epic_dir
    epic_dir=$(find_epic_dir "$epic_id")
    if [ -z "$epic_dir" ]; then
        echo "❌ Epic not found: $epic_id" >&2
        exit 1
    fi

    local snap_dir="$epic_dir/.snapshots"
    mkdir -p "$snap_dir"

    local ts
    ts=$(date -u +"%Y%m%dT%H%M%S")
    local safe_tag
    safe_tag=$(echo "$tag" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-*$//' | head -c 30)
    local snap_id="${ts}${safe_tag:+-$safe_tag}"

    local epic_name
    epic_name=$(basename "$epic_dir")

    # 1. Epic 문서 수집 (epic.md, Stories, Tasks)
    local docs=()
    local stories=0
    local tasks=0

    # epic.md
    local epic_content=""
    if [ -f "$epic_dir/epic.md" ]; then
        epic_content=$(cat "$epic_dir/epic.md")
    fi

    # Story 파일 수집
    local story_data="[]"
    for sfile in "$epic_dir"/S*.md; do
        [ -f "$sfile" ] || continue
        stories=$((stories + 1))
        local sname
        sname=$(basename "$sfile")
        local scontent
        scontent=$(cat "$sfile")
        story_data=$(echo "$story_data" | jq --arg name "$sname" --arg content "$scontent" \
            '. + [{"name": $name, "content": $content}]')
    done

    # Task 파일 수집
    local task_data="[]"
    if [ -d "$epic_dir/tasks" ]; then
        for tfile in "$epic_dir"/tasks/*.md; do
            [ -f "$tfile" ] || continue
            tasks=$((tasks + 1))
            local tname
            tname=$(basename "$tfile")
            local tcontent
            tcontent=$(cat "$tfile")
            task_data=$(echo "$task_data" | jq --arg name "$tname" --arg content "$tcontent" \
                '. + [{"name": $name, "content": $content}]')
        done
    fi

    # 2. Git 상태 수집
    local git_branch
    git_branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "unknown")
    local git_hash
    git_hash=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local git_dirty
    git_dirty=$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    # 3. PROGRESS.md 상태 (있으면)
    local progress_content=""
    if [ -f "$REPO_ROOT/PROGRESS.md" ]; then
        progress_content=$(head -50 "$REPO_ROOT/PROGRESS.md")
    fi

    # 4. Squad 이벤트 로그 (있으면)
    local squad_summary="{}"
    local squad_log_dir="$REPO_ROOT/.claude/squad-logs"
    # epic_id에 매칭되는 squad 로그 찾기
    if [ -d "$squad_log_dir" ]; then
        local matched_dir
        matched_dir=$(find "$squad_log_dir" -maxdepth 1 -type d -name "*${epic_id}*" 2>/dev/null | head -1)
        if [ -n "$matched_dir" ] && [ -f "$matched_dir/summary.json" ]; then
            squad_summary=$(cat "$matched_dir/summary.json")
        fi
    fi

    # 5. 번들 생성
    local snap_file="$snap_dir/snap-${snap_id}.json"

    jq -n \
        --arg id "$snap_id" \
        --arg epic "$epic_name" \
        --arg tag "$tag" \
        --arg created "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --argjson stories_count "$stories" \
        --argjson tasks_count "$tasks" \
        --arg branch "$git_branch" \
        --arg commit "$git_hash" \
        --argjson dirty "$git_dirty" \
        --arg epic_content "$epic_content" \
        --argjson story_data "$story_data" \
        --argjson task_data "$task_data" \
        --arg progress "$progress_content" \
        --argjson squad "$squad_summary" \
        '{
            meta: {
                id: $id,
                epic_name: $epic,
                tag: $tag,
                created_at: $created,
                story_count: $stories_count,
                task_count: $tasks_count,
                git: {
                    branch: $branch,
                    commit: $commit,
                    dirty_files: $dirty
                }
            },
            epic_md: $epic_content,
            stories: $story_data,
            tasks: $task_data,
            progress_md: $progress,
            squad_summary: $squad
        }' > "$snap_file"

    echo "✅ Snapshot created: $snap_id"
    echo "   📁 $snap_file"
    echo "   📊 Stories: $stories, Tasks: $tasks"
    echo "   🔖 Git: $git_branch@$git_hash (dirty: $git_dirty)"
}

# 스냅샷 목록
list_snapshots() {
    local epic_id="$1"
    local epic_dir
    epic_dir=$(find_epic_dir "$epic_id")
    if [ -z "$epic_dir" ]; then
        echo "❌ Epic not found: $epic_id" >&2
        exit 1
    fi

    local snap_dir="$epic_dir/.snapshots"
    if [ ! -d "$snap_dir" ] || [ -z "$(ls "$snap_dir"/snap-*.json 2>/dev/null)" ]; then
        echo "📭 No snapshots for $(basename "$epic_dir")"
        return
    fi

    echo "📸 Snapshots for $(basename "$epic_dir"):"
    echo ""
    printf "%-28s %-20s %-8s %-8s %-10s\n" "ID" "Tag" "Stories" "Tasks" "Git"
    printf "%-28s %-20s %-8s %-8s %-10s\n" "---" "---" "---" "---" "---"

    for snap_file in $(ls -t "$snap_dir"/snap-*.json 2>/dev/null); do
        local sid stag sst stk sgit
        sid=$(jq -r '.meta.id' "$snap_file" 2>/dev/null)
        stag=$(jq -r '.meta.tag // ""' "$snap_file" 2>/dev/null)
        sst=$(jq -r '.meta.story_count // 0' "$snap_file" 2>/dev/null)
        stk=$(jq -r '.meta.task_count // 0' "$snap_file" 2>/dev/null)
        sgit=$(jq -r '.meta.git.commit // "?"' "$snap_file" 2>/dev/null)
        printf "%-28s %-20s %-8s %-8s %-10s\n" "$sid" "${stag:0:20}" "$sst" "$stk" "$sgit"
    done
}

# 스냅샷 복원
restore_snapshot() {
    local epic_id="$1"
    local snap_id="$2"
    local dry_run="${3:-}"

    local epic_dir
    epic_dir=$(find_epic_dir "$epic_id")
    if [ -z "$epic_dir" ]; then
        echo "❌ Epic not found: $epic_id" >&2
        exit 1
    fi

    local snap_file="$epic_dir/.snapshots/snap-${snap_id}.json"
    if [ ! -f "$snap_file" ]; then
        echo "❌ Snapshot not found: $snap_id" >&2
        exit 1
    fi

    local epic_name
    epic_name=$(basename "$epic_dir")

    echo "🔄 Restoring snapshot: $snap_id → $epic_name"
    echo ""

    # 복원할 내용 미리보기
    local stories tasks
    stories=$(jq -r '.meta.story_count' "$snap_file")
    tasks=$(jq -r '.meta.task_count' "$snap_file")
    local git_commit
    git_commit=$(jq -r '.meta.git.commit' "$snap_file")
    local tag
    tag=$(jq -r '.meta.tag // ""' "$snap_file")

    echo "   📊 Stories: $stories, Tasks: $tasks"
    echo "   🔖 Git: $git_commit"
    [ -n "$tag" ] && echo "   🏷️  Tag: $tag"

    if [ "$dry_run" = "--dry-run" ]; then
        echo ""
        echo "   ⏸️  Dry run — no changes made"
        return
    fi

    # 복원 전 현재 상태 자동 백업
    echo ""
    echo "   📦 Auto-backup current state..."
    create_snapshot "$epic_id" "pre-restore-backup" 2>/dev/null

    # epic.md 복원
    local epic_content
    epic_content=$(jq -r '.epic_md // ""' "$snap_file")
    if [ -n "$epic_content" ] && [ "$epic_content" != "null" ]; then
        echo "$epic_content" > "$epic_dir/epic.md"
        echo "   ✅ epic.md restored"
    fi

    # Story 파일 복원
    jq -c '.stories[]' "$snap_file" 2>/dev/null | while read -r story; do
        local sname scontent
        sname=$(echo "$story" | jq -r '.name')
        scontent=$(echo "$story" | jq -r '.content')
        echo "$scontent" > "$epic_dir/$sname"
        echo "   ✅ $sname restored"
    done

    # Task 파일 복원
    if jq -e '.tasks | length > 0' "$snap_file" >/dev/null 2>&1; then
        mkdir -p "$epic_dir/tasks"
        jq -c '.tasks[]' "$snap_file" 2>/dev/null | while read -r task; do
            local tname tcontent
            tname=$(echo "$task" | jq -r '.name')
            tcontent=$(echo "$task" | jq -r '.content')
            echo "$tcontent" > "$epic_dir/tasks/$tname"
            echo "   ✅ tasks/$tname restored"
        done
    fi

    echo ""
    echo "✅ Restore complete. Pre-restore backup saved."
}

# 현재 상태와 스냅샷 비교
diff_snapshot() {
    local epic_id="$1"
    local snap_id="$2"

    local epic_dir
    epic_dir=$(find_epic_dir "$epic_id")
    if [ -z "$epic_dir" ]; then
        echo "❌ Epic not found: $epic_id" >&2
        exit 1
    fi

    local snap_file="$epic_dir/.snapshots/snap-${snap_id}.json"
    if [ ! -f "$snap_file" ]; then
        echo "❌ Snapshot not found: $snap_id" >&2
        exit 1
    fi

    echo "📊 Diff: $snap_id vs Current"
    echo ""

    # Story 수 비교
    local snap_stories current_stories
    snap_stories=$(jq -r '.meta.story_count' "$snap_file")
    current_stories=$(ls "$epic_dir"/S*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "Stories: snapshot=$snap_stories, current=$current_stories"

    # Task 수 비교
    local snap_tasks current_tasks
    snap_tasks=$(jq -r '.meta.task_count' "$snap_file")
    current_tasks=0
    [ -d "$epic_dir/tasks" ] && current_tasks=$(ls "$epic_dir"/tasks/*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "Tasks:   snapshot=$snap_tasks, current=$current_tasks"

    # Git 비교
    local snap_commit current_commit
    snap_commit=$(jq -r '.meta.git.commit' "$snap_file")
    current_commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "?")
    echo "Git:     snapshot=$snap_commit, current=$current_commit"

    # 파일 수준 diff
    echo ""
    echo "--- Files in snapshot but not current ---"
    jq -r '.stories[].name' "$snap_file" 2>/dev/null | while read -r name; do
        [ ! -f "$epic_dir/$name" ] && echo "  - $name (deleted since snapshot)" || true
    done || true
    jq -r '.tasks[].name' "$snap_file" 2>/dev/null | while read -r name; do
        [ ! -f "$epic_dir/tasks/$name" ] && echo "  - tasks/$name (deleted since snapshot)" || true
    done || true

    echo ""
    echo "--- Files in current but not snapshot ---"
    for sfile in "$epic_dir"/S*.md; do
        [ -f "$sfile" ] || continue
        local sname
        sname=$(basename "$sfile")
        if ! jq -e --arg n "$sname" '.stories[] | select(.name == $n)' "$snap_file" >/dev/null 2>&1; then
            echo "  + $sname (added since snapshot)"
        fi
    done || true
}

# 스냅샷 삭제
delete_snapshot() {
    local epic_id="$1"
    local snap_id="$2"

    local epic_dir
    epic_dir=$(find_epic_dir "$epic_id")
    if [ -z "$epic_dir" ]; then
        echo "❌ Epic not found: $epic_id" >&2
        exit 1
    fi

    local snap_file="$epic_dir/.snapshots/snap-${snap_id}.json"
    if [ ! -f "$snap_file" ]; then
        echo "❌ Snapshot not found: $snap_id" >&2
        exit 1
    fi

    rm "$snap_file"
    echo "✅ Deleted snapshot: $snap_id"
}

# 메인 라우터
CMD="${1:-help}"
shift || true

case "$CMD" in
    create)  create_snapshot "$@" ;;
    list)    list_snapshots "$@" ;;
    restore) restore_snapshot "$@" ;;
    diff)    diff_snapshot "$@" ;;
    delete)  delete_snapshot "$@" ;;
    *)
        echo "Epic Snapshot Manager"
        echo ""
        echo "Usage:"
        echo "  epic-snapshot.sh create  <epic-id> [tag]                — Create snapshot"
        echo "  epic-snapshot.sh list    <epic-id>                      — List snapshots"
        echo "  epic-snapshot.sh restore <epic-id> <snap-id> [--dry-run] — Restore"
        echo "  epic-snapshot.sh diff    <epic-id> <snap-id>            — Compare"
        echo "  epic-snapshot.sh delete  <epic-id> <snap-id>            — Delete"
        ;;
esac
