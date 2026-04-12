#!/bin/bash
# TOON Format Checker Hook
# 문서 파일 저장 후 TOON 변환 가능 여부 검사

# 입력 파일 경로 (Write/Edit 도구의 결과)
HOOK_INPUT=$(cat)
FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# .md 파일만 검사
if [[ ! "$FILE_PATH" =~ \.md$ ]]; then
    exit 0
fi

# 예외 파일 (검사 제외)
EXCLUDE_PATTERNS=(
    "CHANGELOG.md"
    "README.md"
    "LICENSE.md"
    "node_modules"
    ".reference"
)

for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
        exit 0
    fi
done

# 파일이 존재하는지 확인
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# TOON 변환 가능 패턴 검사
SUGGESTIONS=""

# 1. Markdown 테이블 검사 (3행 이상)
TABLE_COUNT=$(grep -c "^|.*|$" "$FILE_PATH" 2>/dev/null || echo 0)
if [[ $TABLE_COUNT -ge 4 ]]; then
    SUGGESTIONS="$SUGGESTIONS\n  - Markdown 테이블 ${TABLE_COUNT}행 발견 → TOON 변환 권장"
fi

# 2. 반복 bullet list 검사 (동일 패턴 3개 이상)
# 패턴: "- **Name**: value" 형태
BULLET_PATTERN_COUNT=$(grep -cE "^[[:space:]]*-[[:space:]]+\*\*[^*]+\*\*:" "$FILE_PATH" 2>/dev/null || echo 0)
if [[ $BULLET_PATTERN_COUNT -ge 3 ]]; then
    SUGGESTIONS="$SUGGESTIONS\n  - 반복 bullet list ${BULLET_PATTERN_COUNT}개 발견 → TOON 변환 권장"
fi

# 3. 반복 헤더 패턴 검사 (## Header + 동일 구조 반복)
REPEATED_HEADERS=$(grep -cE "^##[[:space:]]+" "$FILE_PATH" 2>/dev/null || echo 0)
if [[ $REPEATED_HEADERS -ge 5 ]]; then
    SUGGESTIONS="$SUGGESTIONS\n  - 반복 헤더 ${REPEATED_HEADERS}개 발견 → 구조 검토 권장"
fi

# 제안사항이 있으면 출력
if [[ -n "$SUGGESTIONS" ]]; then
    echo "💡 TOON 최적화 제안 ($(basename "$FILE_PATH")):"
    echo -e "$SUGGESTIONS"
    echo "  💡 /toon-convert $FILE_PATH 로 변환 가능"
fi

exit 0
