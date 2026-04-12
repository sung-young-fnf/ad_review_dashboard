---
globs: ["**"]
---

# Standard Patterns for Agent Commands

> **출처**: CCPM verified patterns - Agent 기반 개발의 검증된 Best Practice

이 파일은 모든 Agent Commands가 일관성과 단순성을 유지하기 위해 따라야 하는 공통 패턴을 정의합니다.

---

## Core Principles

1. **Fail Fast** - 핵심 전제 조건만 체크하고 진행
2. **Trust the System** - 거의 실패하지 않는 것들은 과도하게 검증하지 않음
3. **Clear Errors** - 실패 시 정확히 무엇이 문제인지, 어떻게 고치는지 명시
4. **Minimal Output** - 중요한 것만 표시, 장식 제거

---

## Standard Validations

### Minimal Preflight

절대적으로 필요한 것만 체크:

```markdown
## Quick Check
1. 특정 디렉토리/파일이 필요한 경우:
   - 존재 여부만 확인: `test -f {file} || echo "❌ {file} not found"`
   - 없으면 정확한 수정 명령어 알려주기

2. GitHub이 필요한 경우:
   - `gh` 인증 상태를 미리 확인하지 말 것 (보통 인증되어 있음)
   - 실제 실패 시에만 확인
```

### DateTime Handling

```bash
# 현재 datetime 가져오기
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

전체 설명 반복하지 말고 `/rules/datetime.md` 한 번만 참조.

### Error Messages

짧고 실행 가능하게:

```markdown
❌ {무엇이 실패}: {정확한 해결 방법}

예시:
"❌ Epic not found: Run /epic-creator:create feature-name"
"❌ Git not clean: Commit or stash changes first"
```

---

## Standard Output Formats

### Success Output

```markdown
✅ {Action} 완료
  - {핵심 결과 1}
  - {핵심 결과 2}
다음: {권장 다음 액션}
```

### List Output

```markdown
{개수} {항목} 발견:
- {항목 1}: {핵심 세부사항}
- {항목 2}: {핵심 세부사항}
```

### Progress Output

```markdown
{Action}... {current}/{total}
```

---

## File Operations

### Check and Create

```bash
# 권한 묻지 말고 필요한 것 바로 생성
mkdir -p .claude/{directory} 2>/dev/null
```

### Read with Fallback

```bash
# 읽기 시도, 없으면 계속 진행
if [ -f {file} ]; then
  # 파일 읽고 사용
else
  # 합리적인 기본값 사용
fi
```

---

## GitHub Operations

### Trust gh CLI

```bash
# 인증 상태 미리 체크하지 말고 바로 실행
gh {command} || echo "❌ GitHub CLI failed. Run: gh auth login"
```

### Simple Issue Operations

```bash
# 한 번 호출로 필요한 것 모두 가져오기
gh issue view {number} --json state,title,body
```

---

## Common Patterns to Avoid

### DON'T: Over-validate

```markdown
# 나쁜 예 - 너무 많은 체크
1. 디렉토리 존재 확인
2. 권한 확인
3. Git 상태 확인
4. GitHub 인증 확인
5. Rate limit 확인
6. 모든 필드 검증
```

### DO: Check essentials

```markdown
# 좋은 예 - 필수만 확인
1. 대상 존재 확인
2. 작업 시도
3. 실패 시 명확하게 처리
```

### DON'T: Verbose output

```markdown
# 나쁜 예 - 너무 많은 정보
🎯 작업 시작 중...
📋 전제 조건 검증 중...
✅ 1단계 완료
✅ 2단계 완료
📊 통계: ...
💡 팁: ...
```

### DO: Concise output

```markdown
# 좋은 예 - 결과만
✅ 완료: 3개 파일 생성
실패: auth.test.js (구문 오류 - 42줄)
```

### DON'T: Ask too many questions

```markdown
# 나쁜 예 - 너무 interactive
"계속할까요? (yes/no)"
"덮어쓸까요? (yes/no)"
"확실합니까? (yes/no)"
```

### DO: Smart defaults

```markdown
# 좋은 예 - 합리적 기본값으로 진행
# 파괴적이거나 모호한 경우만 질문
"10개 파일 삭제됩니다. 계속? (yes/no)"
```

---

## Context Firewall Integration

**모든 Agent Commands는 Context Firewall을 준수해야 합니다:**

### ❌ NEVER do this:

```markdown
# Bad - Context Firewall Violation
Read {log-file}
Read {test-output}
Read {error-trace}
```

### ✅ DO this instead:

```markdown
# Good - Delegate to Sub-Agent
Task --subagent file-analyzer --prompt "Analyze {log-file}"
Task --subagent test-runner --prompt "Run tests"
Task --subagent code-analyzer --prompt "Analyze {component}"
```

### Why it matters:

- **10개 파일 직접 읽기**: 50,000 tokens
- **file-analyzer 위임**: 5,000 tokens (90% 절감)
- **Main thread**: 요약만 보고 결정

---

## Remember

**Simple is not simplistic** - 여전히 에러는 제대로 처리합니다. 단지 모든 엣지 케이스를 예방하려 하지 않을 뿐입니다.

우리는 다음을 신뢰합니다:
- 파일 시스템은 보통 작동함
- GitHub CLI는 보통 인증되어 있음
- Git 저장소는 보통 유효함
- 사용자는 자기가 뭘 하는지 앎

**Happy path에 집중하고, 잘못되면 우아하게 실패하세요.**

---

## Pattern Checklist

모든 Agent Command 작성 시 확인:

- [ ] Minimal Preflight만 수행 (과도한 검증 제거)
- [ ] Context Firewall 준수 (file-analyzer/code-analyzer 위임)
- [ ] YAGNI 원칙 준수 (현재 필요한 것만 구현)
- [ ] Clear Error Messages (❌ {What}: {Fix})
- [ ] Concise Output (장식 제거, 핵심만)
- [ ] Trust System (파일 시스템, Git, GitHub CLI)
- [ ] Smart Defaults (불필요한 질문 제거)
