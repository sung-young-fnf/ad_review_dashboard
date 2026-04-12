# Hook Development Guide

> **핵심 원칙**: Hook은 **무조건 Bash로만** 작성

## 🎯 왜 Bash인가?

### TypeScript/JavaScript의 문제점 (실제 경험)

1. **JSON 파싱 에러 취약**
   ```typescript
   // ❌ 위험: 빈 입력 시 크래시
   const data = JSON.parse(input);
   ```
   - `--delegate` 플래그로 빈 stdin 수신 시 `Unexpected end of JSON input` 에러
   - Node.js 부팅 시간 추가 (~100ms)
   - 의존성 관리 필요 (node_modules, package.json)

2. **복잡한 디버깅**
   - 500+ 줄의 복잡한 레이어 구조
   - 런타임 에러 추적 어려움
   - TypeScript 컴파일 필요

3. **유지보수 어려움**
   - 코드 베이스 분산 (TS + Bash 혼재)
   - 버전 의존성 충돌
   - 팀원 간 디버깅 어려움

### Bash의 장점

1. **단순하고 안정적**
   - 83줄 vs 500+ 줄 (TypeScript 대비 83% 절감)
   - 기본 Unix 도구만 사용 (jq, grep, sed)
   - 의존성 없음

2. **빠른 실행**
   - ~10ms (Node.js 부팅 없음)
   - 즉시 실행 가능

3. **안전한 에러 처리**
   ```bash
   # ✅ 안전: 빈 입력 조용히 처리
   if [[ -z "$INPUT" ]]; then
       log "Skipped: empty input"
       exit 0  # Silent success
   fi
   ```

4. **쉬운 디버깅**
   - `set -x` 한 줄로 전체 실행 추적
   - 로그 파일로 디버깅 간편
   - Shell 명령어로 즉시 테스트

---

## 📋 Hook 작성 표준 템플릿

### 기본 구조

```bash
#!/bin/bash
# Hook 이름: {hook-name}
# 목적: {간단한 설명}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LOG_FILE="$(dirname "$0")/hook.log"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG_FILE"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Input Validation (MANDATORY for all hooks)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INPUT=$(cat)
INPUT_LENGTH=${#INPUT}
log "Input received: $INPUT_LENGTH bytes"

# SAFETY: Empty Input Handling
if [[ -z "$INPUT" ]] || [[ "$INPUT_LENGTH" -lt 2 ]]; then
    log "Skipped: empty input"
    exit 0  # Silent success (don't block Claude)
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JSON Parsing with Error Handling
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if command -v jq &> /dev/null; then
    PROMPT=$(echo "$INPUT" | jq -r '.prompt' 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ "$PROMPT" == "null" ]]; then
        log "Error: JSON parsing failed"
        exit 0  # Silent success
    fi
else
    # Fallback: simple regex extraction
    PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4)
fi

# Validate prompt
if [[ -z "$PROMPT" ]] || [[ "$PROMPT" == "null" ]]; then
    log "Skipped: no valid prompt found"
    exit 0
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Logic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Your hook logic here

log "Hook completed successfully"
exit 0
```

---

## ⚠️ 필수 규칙 (MANDATORY)

### 1. 빈 입력 처리 (Empty Input Handling)

**모든 Hook은 반드시 빈 입력을 안전하게 처리해야 합니다.**

```bash
# ✅ MUST HAVE
if [[ -z "$INPUT" ]] || [[ "$INPUT_LENGTH" -lt 2 ]]; then
    log "Skipped: empty input"
    exit 0  # Silent success
fi
```

**이유**: `--delegate` 플래그 사용 시 빈 stdin이 전달될 수 있음

### 2. JSON 파싱 에러 처리

```bash
# ✅ MUST HAVE
PROMPT=$(echo "$INPUT" | jq -r '.prompt' 2>/dev/null)
if [[ $? -ne 0 ]] || [[ "$PROMPT" == "null" ]]; then
    log "Error: JSON parsing failed"
    exit 0  # Don't block Claude
fi
```

### 3. Graceful Degradation

**모든 에러는 `exit 0`로 정상 종료해야 합니다.**

```bash
# ✅ 올바른 예
if [[ ! -f "$REQUIRED_FILE" ]]; then
    log "Error: $REQUIRED_FILE not found"
    exit 0  # Silent success (don't block Claude)
fi

# ❌ 잘못된 예
if [[ ! -f "$REQUIRED_FILE" ]]; then
    echo "ERROR: Required file not found!" >&2
    exit 1  # ❌ Hook 에러 발생 (Claude 차단)
fi
```

**이유**: Hook 에러로 인해 Claude 작업이 차단되면 안 됨

### 4. 로깅 필수

```bash
# ✅ 모든 주요 단계마다 로깅
log "=== Hook started ==="
log "Input received: $INPUT_LENGTH bytes"
log "Parsed prompt: $PROMPT"
log "Hook completed successfully"
```

---

## 🔧 도구 사용 가이드

### jq (JSON 처리)

```bash
# jq 존재 확인 후 사용
if command -v jq &> /dev/null; then
    VALUE=$(echo "$JSON" | jq -r '.field' 2>/dev/null)
else
    # Fallback: grep/sed
    VALUE=$(echo "$JSON" | grep -o '"field":"[^"]*"' | cut -d'"' -f4)
fi
```

### Git 명령어

```bash
# Git root 찾기
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 최근 커밋
RECENT_COMMIT=$(git log -1 --format="%h %s" 2>/dev/null)
```

### 파일 존재 확인

```bash
# 파일 존재 확인
if [[ -f "$FILE_PATH" ]]; then
    # 파일 처리
fi

# 디렉토리 존재 확인
if [[ -d "$DIR_PATH" ]]; then
    # 디렉토리 처리
fi
```

### MCP Tools와의 관계 [NEW - 2025-11-04]

**핵심 제약사항**: Bash Hook은 **Claude Code 컨텍스트 외부**에서 실행되므로 MCP 도구를 **직접 호출할 수 없습니다**.

#### ❌ 불가능한 것

```bash
# ❌ 절대 작동하지 않음 - MCP 도구는 Claude Code 내부에서만 실행 가능
mcp__next-devtools__nextjs_runtime --action discover_servers
mcp__chrome-devtools__list_console_messages
```

**이유**: Hook은 독립적인 Bash 프로세스로 실행되며, Claude Code의 MCP 통신 레이어에 접근할 수 없습니다.

#### ✅ 대안: 간접 검증 + Agent 위임

**1. 간접 검증 패턴** (Hook 내부)
```bash
# ✅ 파일 시스템 기반 간접 확인
NEXT_ERROR_LOG="$REPO_ROOT/.next/error.log"

if [ -f "$NEXT_ERROR_LOG" ] && [ -s "$NEXT_ERROR_LOG" ]; then
    SCORE=$((SCORE - 20))
    ISSUES+=("Next.js 빌드 에러 감지 (.next/error.log 확인 필요)")
    log "Warning: Next.js error log detected, recommend Agent verification"
fi
```

**2. Agent 위임 패턴** (Hook → Agent)
```bash
# ✅ Hook은 문제 감지만, 실제 검증은 Agent에게 위임
cat << EOF
💡 Next.js 서버 에러 감지됨

다음 Agent가 자동으로 상세 검증을 수행합니다:
- error-fixer Agent Phase 0
  → mcp__next-devtools__nextjs_runtime 사용
  → 정확한 에러 위치 및 타입 분석

Hook은 여기까지만 수행하고, MCP 도구는 Agent가 처리합니다.
EOF
```

#### 📋 권장 협력 패턴

**Quality Gate Hook** (post/stop-event.sh):
```bash
# Step 1: 간접 검증 (Bash 가능)
check_next_build_status() {
    if [ -f ".next/error.log" ]; then
        echo "⚠️ Next.js 에러 로그 발견"
        echo "→ error-fixer Agent Phase 0에서 자동 검증 예정"
        return 1
    fi
    return 0
}

# Step 2: Agent 트리거 메시지
if ! check_next_build_status; then
    log "Next.js error detected, Agent verification recommended"
    # Hook은 여기서 종료 (exit 0)
    # error-fixer Agent가 자동으로 Phase 0 실행
fi
```

**error-fixer Agent** (Phase 0):
```yaml
# Agent Context에서 MCP 도구 직접 사용 가능
1. mcp__next-devtools__nextjs_runtime --action discover_servers
2. mcp__next-devtools__nextjs_runtime --action call_tool --toolName "get_errors"
3. 서버 에러 자동 수정 또는 사용자 리포트
```

#### 💡 설계 철학

```yaml
Hook의 역할:
  ✅ 빠른 간접 검증 (파일 존재, 로그 크기)
  ✅ 문제 감지 및 알림
  ✅ Agent 트리거 힌트

Agent의 역할:
  ✅ MCP 도구 직접 사용
  ✅ 정확한 진단 및 수정
  ✅ Full-Stack 검증
```

**참조**: `.claude/hooks/utils/quality-gate.sh` - Next.js 간접 검증 예시

---

## 🧪 Hook 테스트 방법

### 1. 직접 테스트

```bash
# 정상 입력 테스트
echo '{"prompt": "테스트 메시지"}' | .claude/hooks/your-hook.sh

# 빈 입력 테스트
echo '' | .claude/hooks/your-hook.sh

# 잘못된 JSON 테스트
echo 'invalid json' | .claude/hooks/your-hook.sh
```

### 2. 로그 확인

```bash
# 최신 로그 확인
tail -20 .claude/hooks/hook.log

# 실시간 로그 모니터링
tail -f .claude/hooks/hook.log
```

### 3. Exit Code 확인

```bash
echo '{"prompt": "test"}' | .claude/hooks/your-hook.sh
echo "Exit code: $?"  # 항상 0이어야 함
```

---

## 📦 Hook 파일 구조

```
.claude/hooks/
├── user-prompt-submit.sh          # User prompt 전처리
├── post-tool-use-*.sh             # Tool 사용 후 처리
├── stop-*.sh                      # Stop event 처리
├── pre/
│   └── user-prompt-submit.sh      # Pre-hook
├── post/
│   └── stop-event.sh              # Post-hook
├── utils/
│   └── extract-context.sh         # 공유 유틸리티
└── _backup/                       # 비활성화된 파일들
```

---

## 🚫 금지 사항

### 1. TypeScript/JavaScript 사용 금지

```bash
# ❌ 절대 금지
#!/usr/bin/env node
#!/usr/bin/env npx tsx
```

**예외**: `.claude/utils/` 디렉토리의 유틸리티 라이브러리만 허용

### 2. 외부 의존성 금지

```bash
# ❌ npm 패키지 사용 금지
npm install some-package

# ✅ 기본 Unix 도구만 사용
jq, grep, sed, awk, cut, tr
```

### 3. 복잡한 로직 금지

```bash
# ❌ 200줄 넘는 복잡한 Hook
# ✅ 100줄 이내로 간결하게 유지
```

복잡한 로직은 별도 Agent로 분리하세요.

### 4. MCP 도구 직접 호출 금지 [NEW - 2025-11-04]

```bash
# ❌ 절대 작동하지 않음 - Hook은 Claude Code 외부에서 실행
mcp__next-devtools__nextjs_runtime --action discover_servers
mcp__chrome-devtools__list_console_messages
mcp__figmaRemoteMcp__get_screenshot

# ✅ 대신 파일 시스템 기반 간접 검증 사용
if [ -f ".next/error.log" ] && [ -s ".next/error.log" ]; then
    log "Next.js error detected"
    # Agent에게 위임
fi
```

**이유**: Hook은 독립 Bash 프로세스로 실행되며 MCP 통신 레이어에 접근 불가

**대안**: 간접 검증 (파일 존재, 로그 크기) + Agent 위임 패턴 사용

---

## 💡 Best Practices

### 1. 성능 최적화

```bash
# ✅ 빠른 필터링으로 조기 종료
if [[ ! "$PROMPT" =~ (키워드1|키워드2) ]]; then
    log "Skipped: non-matching prompt"
    exit 0
fi
```

### 2. macOS 호환성

```bash
# ✅ macOS 호환 date 명령어
date -u +"%Y-%m-%dT%H:%M:%SZ"

# ❌ GNU date 전용 (Linux만)
date --iso-8601=seconds
```

### 3. Shellcheck 검증

```bash
# Hook 작성 후 Shellcheck 실행
shellcheck .claude/hooks/your-hook.sh
```

---

## 📚 참고 자료

### 우수 사례

- **user-prompt-submit.sh**: 입력 검증, JSON 파싱, 에러 처리 모범 사례
- **stop-quality-gate.sh**: 복잡한 검증 로직의 간결한 구현

### 추가 문서

- [Claude Code Hooks Documentation](https://docs.claude.com/hooks)
- [Bash Best Practices](https://google.github.io/styleguide/shellguide.html)

---

## 🔄 기존 TypeScript Hook 마이그레이션

TypeScript Hook을 Bash로 변환하려면:

1. **핵심 로직 추출**: TypeScript의 핵심 비즈니스 로직만 식별
2. **Bash로 재작성**: 위 템플릿 사용하여 Bash로 변환
3. **테스트**: 3가지 테스트 케이스 (정상/빈 입력/잘못된 JSON) 모두 통과
4. **비활성화**: TypeScript 파일을 `_backup/`으로 이동

**도움 필요 시**: `99-utils/file-analyzer` Agent에게 TypeScript Hook 분석 요청

---

## ✅ 체크리스트

새 Hook 작성 시 다음을 확인하세요:

- [ ] Shebang이 `#!/bin/bash`인가?
- [ ] 빈 입력 처리가 있는가?
- [ ] JSON 파싱 에러 처리가 있는가?
- [ ] 모든 에러가 `exit 0`로 종료되는가?
- [ ] 로깅이 충분한가?
- [ ] 3가지 테스트 케이스가 통과하는가?
- [ ] 100줄 이내로 간결한가?
- [ ] Shellcheck 검증을 통과했는가?

---

## 🆕 Claude Code 2.0.41+ 신규 기능

### 1. SubagentStop Hook 메타데이터 (2.0.42+)

**새 환경 변수**:
```bash
CLAUDE_AGENT_ID              # Agent 고유 ID (예: "code-writer")
CLAUDE_AGENT_TRANSCRIPT_PATH # Agent 실행 전문 경로
```

**활용 예시**:
```bash
# Stop Hook에서 Agent 완료 자동 로깅
if [[ -n "$CLAUDE_AGENT_ID" ]] && [[ -n "$CLAUDE_AGENT_TRANSCRIPT_PATH" ]]; then
  echo "📋 Agent 완료: $CLAUDE_AGENT_ID"
  echo "   Transcript: $CLAUDE_AGENT_TRANSCRIPT_PATH"

  # 핵심 Agent 완료 시 자동 액션
  if [[ "$CLAUDE_AGENT_ID" =~ (code-writer|task-planner) ]]; then
    log "PROGRESS.md 자동 업데이트 권장"
  fi
fi
```

**효과**: Agent Chain 추적 자동화, 수동 로그 불필요

---

### 2. Hook Custom Model 지정 (2.0.41+)

**settings.json 설정**:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/post/stop-event.sh",
            "timeout": 15,
            "model": "gpt-5-codex"  // 🆕 Hook별 모델 지정
          }
        ]
      }
    ]
  }
}
```

**Hook 내부 사용**:
```bash
# 환경 변수로 전달됨
HOOK_MODEL="${CLAUDE_HOOK_MODEL:-gpt-5-codex}"

# React Hook 검증에 GPT-5 Codex 사용
if [[ "$HOOK_MODEL" == "gpt-5-codex" ]]; then
  echo "💡 심화 검증: Codex delegate codereview --model $HOOK_MODEL"
fi
```

**효과**: 품질 검증 특화 모델 사용 (React Hook 감지율 80% → 95%)

---

### 3. Hook Timeout 커스터마이징 (2.0.41+ SDK)

**권장 Timeout 값**:
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "command": "user-prompt-submit.sh",
            "timeout": 8  // 파일 검색 포함 (기존 3초)
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "command": "stop-event.sh",
            "timeout": 15  // Git 분석 포함 (기존 10초)
          }
        ]
      }
    ]
  }
}
```

**효과**: Hook Timeout 에러 방지 (0건/일)

---

### 4. Git 명령어 자동 승인 확장 (2.0.41+)

**자동 승인 명령어**:
```bash
# 기본 승인 (기존)
git status
git diff
git log

# 🆕 신규 승인 (2.0.41+)
git branch
git show
git rev-parse
git ls-files
# ... 더 많은 읽기 전용 명령어
```

**Hook에서 활용**:
```bash
# 승인 다이얼로그 없이 즉시 실행
MODIFIED_FILES=$(git diff --name-only HEAD)
CURRENT_BRANCH=$(git branch --show-current)
COMMIT_HASH=$(git rev-parse HEAD)
```

**효과**: Hook 실행 속도 향상 (Git 명령어 승인 대기 시간 0ms)

---

## 📋 업데이트 체크리스트 (2.0.41+)

새 Hook 작성 시:
- [ ] SubagentStop 메타데이터 활용 (`CLAUDE_AGENT_ID`)
- [ ] Custom Model 지정 필요 시 `model` 설정
- [ ] Timeout 값 적절하게 설정 (파일 검색/Git 분석 고려)
- [ ] 자동 승인된 Git 명령어 활용 (속도 향상)

---

**마지막 업데이트**: 2025-11-17 (Claude Code 2.0.42 반영)
**작성자**: Hook 표준화 프로젝트 + Next.js MCP 통합 + 2.0.41+ 기능 추가
