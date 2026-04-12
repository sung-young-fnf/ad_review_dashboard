# Claude Headless Mode 가이드

> Hook/Script에서 Claude의 추론 능력을 비동기로 활용하는 방법

## 📚 목차

1. [개요](#개요)
2. [기본 사용법](#기본-사용법)
3. [실전 패턴 (T001-T003)](#실전-패턴-t001-t003)
4. [에러 처리](#에러-처리)
5. [성능 최적화](#성능-최적화)
6. [보안 고려사항](#보안-고려사항)
7. [참고 자료](#참고-자료)

---

## 개요

### Claude Headless Mode란?

**정의**:
- CLI에서 `claude -p --output-format json` 실행
- 대화형 UI 없이 JSON 결과만 반환
- Hook/Script에서 Claude 추론 능력 활용

**MergeAnalyzer 패턴에서 차용**:
- **Pattern 1**: Claude Headless Execution (비동기 추론)
- **Pattern 2**: Graceful Degradation (실패 시 조용히 종료)
- **Pattern 3**: Rich UI (ANSI 색상으로 사용자 경험 향상)
- **Pattern 4**: 60초 타임아웃 (빠른 응답 우선)

**핵심 장점**:
- ✅ Hook 내에서 복잡한 분석/추론 가능
- ✅ 사용자 경험 방해 없음 (백그라운드 실행)
- ✅ 실패 시 워크플로우 중단 없음 (Graceful Degradation)

---

## 기본 사용법

### 1. 단순 실행

```bash
# 기본 형태
claude -p "Your prompt here" --output-format json

# 타임아웃 추가 (필수 - 60초 권장)
timeout 60s claude -p "Analyze this code" --output-format json > result.json
```

### 2. JSON 파싱

```bash
# jq로 파싱
RESULT=$(jq -r '.summary' result.json)

# 에러 처리 (Graceful Degradation)
RESULT=$(jq -r '.summary' result.json 2>/dev/null || echo "기본값")

# 여러 필드 추출
MISTAKES=$(jq -r '.mistakes[]' result.json 2>/dev/null)
LEARNINGS=$(jq -r '.learnings[]' result.json 2>/dev/null)
```

### 3. 파일 입력

```bash
# 여러 파일 분석
FILES=$(find docs/epics -name "*.md" | tr '\n' ',')
claude -p "Analyze these files: $FILES" --output-format json

# 특정 Epic의 파일만
EPIC_ID="EP012"
FILES=$(find "docs/epics/$EPIC_ID" -name "*.md" -type f | tr '\n' ' ')
claude -p "Summarize Epic $EPIC_ID files: $FILES" --output-format json
```

---

## 실전 패턴 (T001-T003)

### Pattern 1: 실수 감지 및 학습 (T001)

**사용 사례**: 대화 종료 시 자동 분석 (`.claude/hooks/post/stop-event.sh`)

**목표**:
- 종료된 대화에서 실수/개선점 자동 추출
- `.claude/memory/pattern-learnings.jsonl`에 저장
- Rich UI로 사용자에게 즉시 피드백

**구현 예시**:

```bash
#!/bin/bash
# .claude/hooks/post/stop-event.sh

PROMPT="Analyze the completed conversation for mistakes and learnings.
Output JSON format:
{
  \"mistakes\": [\"mistake 1\", \"mistake 2\"],
  \"learnings\": [\"learning 1\", \"learning 2\"],
  \"confidence\": 0.85
}"

# Headless Mode 실행 (60초 타임아웃)
if timeout 60s claude -p "$PROMPT" --output-format json > /tmp/analysis.json 2>/dev/null; then
    # 성공 시 처리
    MISTAKES=$(jq -r '.mistakes[]' /tmp/analysis.json 2>/dev/null)
    LEARNINGS=$(jq -r '.learnings[]' /tmp/analysis.json 2>/dev/null)

    # Rich UI로 표시 (ANSI 색상)
    if [[ -n "$MISTAKES" ]]; then
        echo -e "\033[1;31m🔍 실수 감지:\033[0m"
        echo "$MISTAKES" | while read -r line; do
            echo -e "  \033[33m❌ $line\033[0m"
        done
    fi

    if [[ -n "$LEARNINGS" ]]; then
        echo -e "\033[1;32m💡 학습 포인트:\033[0m"
        echo "$LEARNINGS" | while read -r line; do
            echo -e "  \033[36m✅ $line\033[0m"
        done
    fi

    # JSONL 형식으로 저장
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq -c ". + {timestamp: \"$TIMESTAMP\"}" /tmp/analysis.json >> .claude/memory/pattern-learnings.jsonl
else
    # 실패 시 Graceful Degradation
    echo "⚠️ 분석 스킵 (타임아웃 또는 Claude 실패)"
fi

# 항상 성공 종료 (Hook 워크플로우 중단 방지)
exit 0
```

**핵심 포인트**:
- ✅ 타임아웃 60초 (빠른 응답 우선)
- ✅ Graceful Degradation (실패해도 exit 0)
- ✅ Rich UI (ANSI 색상으로 즉시 피드백)
- ✅ JSONL 저장 (타임스탬프 포함)

---

### Pattern 2: Spec 자동 개선 (T002)

**사용 사례**: 학습 데이터 기반 CLAUDE.md 패치

**목표**:
- `.claude/memory/pattern-learnings.jsonl` 분석
- 반복되는 실수 패턴 감지
- CLAUDE.md에 자동 패치 (새 규칙 추가)

**구현 예시**:

```bash
#!/bin/bash
# .claude/hooks/utils/auto-improve-specs.sh

LEARNING_FILE=".claude/memory/pattern-learnings.jsonl"

# 최근 10개 학습 데이터 추출
RECENT=$(tail -10 "$LEARNING_FILE" 2>/dev/null)

if [[ -z "$RECENT" ]]; then
    echo "⏭️ 학습 데이터 없음, 스킵"
    exit 0
fi

PROMPT="Based on these learnings, generate improvements for CLAUDE.md:

$RECENT

Analyze repeated mistakes and output JSON:
{
  \"section\": \"Section name (e.g., YAGNI 위반 방지)\",
  \"content\": \"Markdown content to add\",
  \"priority\": \"high|medium|low\"
}"

# Headless Mode 실행
timeout 60s claude -p "$PROMPT" --output-format json > /tmp/improvements.json 2>/dev/null

SECTION=$(jq -r '.section' /tmp/improvements.json 2>/dev/null)
CONTENT=$(jq -r '.content' /tmp/improvements.json 2>/dev/null)
PRIORITY=$(jq -r '.priority' /tmp/improvements.json 2>/dev/null)

if [[ -n "$SECTION" ]] && [[ "$SECTION" != "null" ]]; then
    # CLAUDE.md 패치 (타임스탬프 포함)
    cat >> .claude/CLAUDE.md <<EOF

---

### ⚠️ 자동 학습: $SECTION ($(date +%Y-%m-%d))

**우선순위**: $PRIORITY

$CONTENT

**학습 소스**: pattern-learnings.jsonl (최근 10개 항목)
EOF
    echo -e "\033[1;32m✅ CLAUDE.md 개선 완료\033[0m"
    echo -e "  섹션: \033[36m$SECTION\033[0m"
    echo -e "  우선순위: \033[33m$PRIORITY\033[0m"
else
    echo "⏭️ 개선 제안 없음"
fi

exit 0
```

**핵심 포인트**:
- ✅ 최근 데이터만 분석 (tail -10)
- ✅ 우선순위 기반 패치
- ✅ 타임스탬프 기록 (추적 가능)
- ✅ 빈 결과 처리 (null 체크)

---

### Pattern 3: Epic/Story 리포트 (T003)

**사용 사례**: Epic 완료 시 요약 자동 생성

**목표**:
- Epic 전체 파일 분석
- High-level Summary 생성
- `docs/epics/{EPIC_ID}/SUMMARY.json` 저장

**구현 예시**:

```bash
#!/bin/bash
# .claude/hooks/post/epic-complete.sh

EPIC_ID="$1"
EPIC_DIR="docs/epics/$EPIC_ID"

if [[ -z "$EPIC_ID" ]]; then
    echo "Usage: epic-complete.sh <EPIC_ID>"
    exit 1
fi

if [[ ! -d "$EPIC_DIR" ]]; then
    echo "❌ Epic 디렉토리 없음: $EPIC_DIR"
    exit 0
fi

# Epic 파일 목록 수집
EPIC_FILES=$(find "$EPIC_DIR" -name "*.md" -type f | tr '\n' ' ')

PROMPT="Summarize Epic $EPIC_ID based on these files:

$EPIC_FILES

Output JSON:
{
  \"summary\": \"High-level summary (3-5 sentences)\",
  \"stories\": [\"S01\", \"S02\", ...],
  \"total_tasks\": 10,
  \"completion_rate\": 0.95,
  \"key_achievements\": [\"achievement 1\", \"achievement 2\"]
}"

# Headless Mode 실행 (타임아웃 90초 - Epic은 파일 많음)
timeout 90s claude -p "$PROMPT" --output-format json > "$EPIC_DIR/SUMMARY.json" 2>/dev/null

if [[ ! -f "$EPIC_DIR/SUMMARY.json" ]]; then
    echo "⚠️ 요약 생성 실패"
    exit 0
fi

# Rich UI로 표시
SUMMARY=$(jq -r '.summary' "$EPIC_DIR/SUMMARY.json" 2>/dev/null)
STORIES=$(jq -r '.stories[]' "$EPIC_DIR/SUMMARY.json" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
TOTAL_TASKS=$(jq -r '.total_tasks' "$EPIC_DIR/SUMMARY.json" 2>/dev/null)

echo -e "\033[1;36m📊 Epic $EPIC_ID 완료\033[0m"
echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[32m요약:\033[0m"
echo "$SUMMARY" | fold -s -w 70 | sed 's/^/  /'
echo ""
echo -e "\033[33mStories:\033[0m $STORIES"
echo -e "\033[33mTotal Tasks:\033[0m $TOTAL_TASKS"
echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

exit 0
```

**핵심 포인트**:
- ✅ Epic 규모에 따라 타임아웃 조정 (90초)
- ✅ 파일 존재 확인 (`[[ ! -f ... ]]`)
- ✅ Rich UI (박스형 출력)
- ✅ fold 명령어로 줄바꿈 (가독성)

---

## 에러 처리

### 필수 체크포인트 (4가지)

#### 1. 타임아웃 (60초 강제)

```bash
# ✅ 올바른 방법
timeout 60s claude -p "$PROMPT" --output-format json > result.json

# ❌ 타임아웃 없음 (무한 대기 위험)
claude -p "$PROMPT" --output-format json > result.json
```

#### 2. JSON 파싱 에러

```bash
# ✅ 에러 무시 + 기본값
RESULT=$(jq -r '.field' file.json 2>/dev/null || echo "기본값")

# ✅ null 체크
RESULT=$(jq -r '.field' file.json)
if [[ "$RESULT" == "null" ]] || [[ -z "$RESULT" ]]; then
    RESULT="기본값"
fi

# ❌ 에러 처리 없음
RESULT=$(jq -r '.field' file.json)  # jq 실패 시 빈 문자열
```

#### 3. 빈 출력 처리

```bash
# ✅ 파일 존재 + 크기 확인
if [[ ! -f result.json ]] || [[ ! -s result.json ]]; then
    echo "⚠️ 결과 파일 없음 또는 비어있음"
    exit 0  # Graceful Degradation
fi

# ✅ JSON 유효성 검증
if ! jq empty result.json 2>/dev/null; then
    echo "⚠️ 유효하지 않은 JSON"
    exit 0
fi
```

#### 4. Claude 실패 처리

```bash
# ✅ 실패 시 폴백
if ! timeout 60s claude -p "$PROMPT" --output-format json > result.json 2>/dev/null; then
    echo "⚠️ Claude 실행 실패, 기본 동작 실행"
    # 폴백 로직
    exit 0
fi

# ✅ stderr 로깅 (디버깅용)
if ! timeout 60s claude -p "$PROMPT" --output-format json > result.json 2>> /tmp/claude-errors.log; then
    echo "⚠️ Claude 실패, 로그: /tmp/claude-errors.log"
    exit 0
fi
```

### Graceful Degradation 템플릿

```bash
#!/bin/bash

# 항상 성공 종료 (Hook 워크플로우 중단 방지)
set +e  # 에러 무시 모드

# 에러 처리 함수
handle_error() {
    local msg="$1"
    echo "⚠️ $msg" >&2
    exit 0  # 조용히 종료
}

# Claude 실행
timeout 60s claude -p "$PROMPT" --output-format json > /tmp/result.json 2>/dev/null || handle_error "Claude 실행 실패"

# JSON 검증
jq empty /tmp/result.json 2>/dev/null || handle_error "유효하지 않은 JSON"

# 필드 추출
RESULT=$(jq -r '.field' /tmp/result.json 2>/dev/null || echo "")

# 빈 결과 처리
if [[ -z "$RESULT" ]] || [[ "$RESULT" == "null" ]]; then
    handle_error "결과 없음"
fi

# 정상 처리
echo "✅ 결과: $RESULT"
exit 0
```

---

## 성능 최적화

### 1. 프롬프트 최적화

```bash
# ❌ 비효율적 (너무 장황)
PROMPT="Please carefully analyze this entire codebase and provide
a comprehensive analysis with detailed explanations for each component,
including code quality, security issues, performance bottlenecks..."

# ✅ 효율적 (명확하고 간결)
PROMPT="Analyze for mistakes and learnings. Output JSON:
{
  \"mistakes\": [],
  \"learnings\": []
}"
```

**Tips**:
- ✅ JSON 구조를 프롬프트에 명시
- ✅ 필요한 필드만 요청
- ✅ 예시 출력 제공
- ❌ "comprehensive", "detailed" 같은 모호한 단어 사용

### 2. 파일 필터링

```bash
# ❌ 모든 파일 (불필요한 파일 포함)
FILES=$(find . -name "*.md")

# ✅ 필요한 파일만 (특정 Epic)
FILES=$(find "docs/epics/$EPIC_ID" -name "*.md" -type f)

# ✅ 제외 패턴 사용
FILES=$(find docs/epics -name "*.md" -not -path "*/node_modules/*" -type f)
```

### 3. 캐싱 (1시간 유효)

```bash
# 1시간 단위 캐시 파일
CACHE_FILE="/tmp/claude-cache-$(date +%Y%m%d%H).json"

if [[ -f "$CACHE_FILE" ]] && [[ -s "$CACHE_FILE" ]]; then
    # 캐시 사용
    cat "$CACHE_FILE"
else
    # 신규 실행 + 캐시 저장
    timeout 60s claude -p "$PROMPT" --output-format json | tee "$CACHE_FILE"
fi
```

### 4. 병렬 실행 (독립적 분석)

```bash
# Epic별로 병렬 요약
for epic in docs/epics/EP*; do
    (
        EPIC_ID=$(basename "$epic")
        timeout 90s claude -p "Summarize $EPIC_ID" --output-format json > "$epic/SUMMARY.json"
    ) &
done

wait  # 모든 백그라운드 작업 대기
echo "✅ 모든 Epic 요약 완료"
```

---

## 보안 고려사항

### 1. 민감 정보 필터링

```bash
# ❌ 환경 변수 노출 (API Key 등)
PROMPT="Analyze environment: $(env)"

# ❌ .env 파일 노출
PROMPT="Analyze: $(cat .env)"

# ✅ 안전한 방법 (파일 경로만)
FILES=$(find docs -name "*.md" -type f | tr '\n' ' ')
PROMPT="Analyze these files: $FILES"
```

### 2. 출력 검증 (Injection 방지)

```bash
# ✅ JSON 구조 검증
if ! jq empty /tmp/result.json 2>/dev/null; then
    echo "⚠️ 유효하지 않은 JSON"
    exit 0
fi

# ✅ 예상되는 필드 확인
EXPECTED_FIELDS=("mistakes" "learnings")
for field in "${EXPECTED_FIELDS[@]}"; do
    if ! jq -e ".$field" /tmp/result.json >/dev/null 2>&1; then
        echo "⚠️ 필수 필드 누락: $field"
        exit 0
    fi
done
```

### 3. 로깅 (민감 정보 마스킹)

```bash
# ✅ 민감 정보 마스킹 후 로깅
log_safe() {
    local msg="$1"
    # token, password, api_key 패턴 마스킹
    echo "$msg" | sed -E 's/(token|password|api_key)=[^ ]*/\1=***/g' >> /tmp/claude-audit.log
}

log_safe "Claude 실행: $PROMPT"
```

### 4. 권한 제어

```bash
# ✅ 안전한 임시 파일 생성
TEMP_FILE=$(mktemp /tmp/claude-XXXXXX.json)
chmod 600 "$TEMP_FILE"  # 소유자만 읽기/쓰기

# 작업 완료 후 삭제
trap "rm -f $TEMP_FILE" EXIT
```

---

## 참고 자료

### 실제 구현 예시

- **T001 - 실수 감지**: `.claude/hooks/post/stop-event.sh`
  - Pattern Learning 자동화
  - Rich UI 피드백
  - JSONL 저장

- **T002 - Spec 개선**: `.claude/hooks/utils/auto-improve-specs.sh`
  - CLAUDE.md 자동 패치
  - 반복 패턴 감지
  - 우선순위 기반 개선

- **T003 - Epic 리포트**: `.claude/hooks/post/epic-complete.sh`
  - 완료 요약 자동 생성
  - 박스형 Rich UI
  - SUMMARY.json 저장

### 관련 문서

- **Hook 개발 규칙**: `.claude/guides/HOOK_DEVELOPMENT_GUIDE.md`
- **Reddit Hook System**: `.claude/guides/REDDIT_HOOK_SYSTEM.md`
- **Pattern Learning**: `.claude/memory/pattern-learnings.jsonl` (실제 학습 데이터)

---

## 체크리스트

**Headless Mode 사용 전 확인**:

- [ ] **타임아웃 설정** (60초, Epic은 90초)
- [ ] **JSON 파싱 에러 처리** (`2>/dev/null || echo "기본값"`)
- [ ] **Graceful Degradation** (항상 `exit 0`)
- [ ] **빈 출력 처리** (`[[ ! -f ... ]] || [[ ! -s ... ]]`)
- [ ] **민감 정보 필터링** (환경 변수, .env 제외)
- [ ] **프롬프트 최적화** (JSON 구조 명시, 간결)
- [ ] **Rich UI** (ANSI 색상으로 가독성 향상)
- [ ] **캐싱 고려** (1시간 유효, 중복 실행 방지)

**완료!** 🎉

---

**버전**: 1.0
**최종 업데이트**: 2025-11-17
**작성자**: code-writer Agent
**참조**: T001 (stop-event.sh), T002 (auto-improve-specs.sh), T003 (epic-complete.sh)
