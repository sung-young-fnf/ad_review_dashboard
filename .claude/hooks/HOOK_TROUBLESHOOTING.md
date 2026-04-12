# Hook System Troubleshooting Guide

> **문제**: Reddit Hook System (user-prompt-submit.sh)이 실행되지 않음
> **날짜**: 2025-11-19
> **증상**: "Always Answer Korean", "ANALYZE → INJECT → ROUTE" 출력 없음

---

## 🔍 원인 분석

### 1. Hook 파일 상태 ✅
```bash
# Hook 파일 존재 확인
$ ls -la .claude/hooks/pre/user-prompt-submit.sh
-rwxr-xr-x  1 yun  staff  12531 Nov 18 16:27 .claude/hooks/pre/user-prompt-submit.sh

# 실행 권한 OK
# 파일 크기 정상 (12KB)
```

### 2. Hook 입력 방식 확인 ✅
```bash
# Hook은 다음 중 하나로 입력 받음:
USER_INPUT="${CLAUDE_USER_PROMPT:-${1:-}}"

# 방법 1: 환경 변수
CLAUDE_USER_PROMPT='사용자 입력' .claude/hooks/pre/user-prompt-submit.sh

# 방법 2: 인자 전달
.claude/hooks/pre/user-prompt-submit.sh "사용자 입력"
```

### 3. 빈 입력 체크 로직 ✅
```bash
if [[ -z "$USER_INPUT" ]]; then
  echo "⚠️ Warning: 사용자 입력이 비어있습니다." >&2
  exit 0  # Graceful degradation
fi
```

---

## 🚨 근본 원인 (Root Cause)

### **Claude Code Hook 실행 방식 불일치**

Claude Code는 다음 중 하나의 이유로 Hook을 실행하지 않거나, 입력을 전달하지 않을 수 있습니다:

#### 가능한 원인 1: Hook 이벤트 타입 불일치
```bash
# Claude Code가 지원하는 Hook 이벤트:
- user-prompt-submit (사용자 입력 시)  ← 이것을 사용 중
- stop-event (Agent 완료 시)
- tool-use (도구 사용 시)

# 확인 필요: Claude Code 버전에 따라 user-prompt-submit 미지원 가능성
```

#### 가능한 원인 2: stdin 대신 환경 변수 필요
```bash
# Claude Code가 Hook을 호출하는 방식:
# ❌ 잘못된 방식 (stdin)
echo "사용자 입력" | .claude/hooks/pre/user-prompt-submit.sh

# ✅ 올바른 방식 (환경 변수)
CLAUDE_USER_PROMPT="사용자 입력" .claude/hooks/pre/user-prompt-submit.sh

# ✅ 또는 (인자 전달)
.claude/hooks/pre/user-prompt-submit.sh "사용자 입력"
```

#### 가능한 원인 3: Hook 디렉토리 인식 문제
```bash
# Claude Code가 Hook을 찾는 경로:
.claude/hooks/pre/user-prompt-submit.sh  ← 현재 위치 (정상)

# 또는
.claude/hooks/user-prompt-submit.sh      ← 이 위치일 가능성?
```

---

## 🔧 해결 방법

### Solution 1: Hook 수동 테스트 (검증용)
```bash
# 현재 프로젝트에서 테스트
CLAUDE_USER_PROMPT="Task --subagent_type 01-pre-analysis/tech-stack-analyzer" \
  .claude/hooks/pre/user-prompt-submit.sh

# 출력 예상:
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                    🎯 AUTO-CONTEXT INJECTION (Phase 1)                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# ANALYZE:
#   키워드: [Task, tech-stack-analyzer]
#   도메인: [분석]
# ...
```

### Solution 2: Claude Code 설정 확인
```json
// .claude/settings.json 또는 Claude Code 설정
{
  "hooks": {
    "enabled": true,
    "user-prompt-submit": {
      "enabled": true,
      "path": ".claude/hooks/pre/user-prompt-submit.sh"
    }
  }
}
```

### Solution 3: Hook 위치 변경 (Fallback)
```bash
# Claude Code가 다른 위치를 기대한다면:
cp .claude/hooks/pre/user-prompt-submit.sh .claude/hooks/user-prompt-submit.sh

# 또는 심볼릭 링크
ln -s .claude/hooks/pre/user-prompt-submit.sh .claude/hooks/user-prompt-submit.sh
```

### Solution 4: Hook 로깅 활성화 (디버깅용)
```bash
# user-prompt-submit.sh 시작 부분에 로깅 추가
# (라인 10 이후)

# 로그 파일 경로
LOG_FILE="/tmp/claude-hook-user-prompt-submit.log"

# 실행 여부 로깅
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Hook executed" >> "$LOG_FILE"
echo "USER_INPUT: $USER_INPUT" >> "$LOG_FILE"
echo "CLAUDE_USER_PROMPT: $CLAUDE_USER_PROMPT" >> "$LOG_FILE"
echo "Args: $@" >> "$LOG_FILE"
```

---

## 🧪 테스트 시나리오

### Test 1: Hook 직접 실행 (환경 변수)
```bash
CLAUDE_USER_PROMPT="프로젝트 분석해줘" \
  /Users/yun/work/ai/okr2/.claude/hooks/pre/user-prompt-submit.sh
```

**예상 출력**:
```
╔═══════════════════════════════════════════════════════════════════════════╗
║                    🎯 AUTO-CONTEXT INJECTION (Phase 1)                    ║
╚═══════════════════════════════════════════════════════════════════════════╝

ANALYZE:
  키워드: [프로젝트, 분석]
  도메인: [분석]

INJECT:
  🎯 분석 DETECTED
  📋 Agent 추천: 01-pre-analysis/business-analyzer
     (비즈니스 도메인 분석)
  🔧 기술 컨텍스트: ...
```

### Test 2: Hook 로그 확인
```bash
# Hook 실행 후
cat /tmp/claude-hook-user-prompt-submit.log

# 예상 내용:
# [2025-11-19 08:30:00] Hook executed
# USER_INPUT: 프로젝트 분석해줘
# CLAUDE_USER_PROMPT: 프로젝트 분석해줘
# Args:
```

### Test 3: Claude Code 통합 테스트
```bash
# Claude Code에서 직접 입력:
"프로젝트 분석해줘"

# Hook 출력이 보이는지 확인
# - 보임 ✅ → Hook 정상 작동
# - 안 보임 ❌ → Claude Code Hook 연동 문제
```

---

## 🎯 임시 해결책 (Workaround)

Hook이 자동으로 실행되지 않는다면, **수동으로 컨텍스트 주입**:

### Pattern 1: 명시적 Agent 호출 시 컨텍스트 참조
```bash
# 사용자가 직접 입력:
Task --subagent_type "01-pre-analysis/tech-stack-analyzer" --prompt "
기술 스택 분석 요청

📋 컨텍스트:
- 프로젝트: okr2
- 기술 스택: Next.js 15, NestJS, Prisma
- 목적: 현재 기술 스택 상태 파악

@docs/analysis/tech-stack.md 참조
"
```

### Pattern 2: CLAUDE.md 규칙 명시
```bash
# 사용자가 직접 입력:
다음 규칙을 따라 진행:
1. @.claude/CLAUDE.md 참조
2. AUTO-WORKFLOW 자동 라우팅 적용
3. 4개 분석 Agent 병렬 실행
```

---

## 📚 참조

- **Hook 코드**: `.claude/hooks/pre/user-prompt-submit.sh`
- **Hook 가이드**: `.claude/guides/HOOK_DEVELOPMENT_GUIDE.md`
- **Reddit Hook System**: `.claude/guides/REDDIT_HOOK_SYSTEM.md`
- **Claude Code 문서**: https://code.claude.com/docs

---

## ✅ 다음 단계

1. **Hook 로깅 활성화** → 실행 여부 확인
2. **Claude Code 설정 확인** → Hook 연동 상태
3. **수동 테스트** → Hook 동작 검증
4. **Claude Code 버전 확인** → user-prompt-submit 지원 여부

완료 후 이 문서에 결과 업데이트
