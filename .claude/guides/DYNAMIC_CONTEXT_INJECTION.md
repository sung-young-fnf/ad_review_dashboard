# Dynamic Context Injection Guide

> SKILL.md / Command .md 파일에서 `!`command`` 구문으로 셸 명령을 전처리하여 Claude에게 결과만 전달

## 개념

```
SKILL.md 작성 시:          !`git status --short`
                                ↓ (전처리)
Claude가 받는 프롬프트:     M  src/auth.ts
                           A  src/new-file.ts
```

- `!`command``는 **프롬프트가 Claude에게 전달되기 전에** 셸에서 실행됨
- Claude는 커맨드 자체를 보지 않고 **실행 결과만** 봄
- Hook과 다름: Hook = 도구 호출 전후 side effect / Dynamic Injection = 프롬프트 조립 시 context enrichment

## 왜 사용하는가

| Before (도구 호출) | After (Dynamic Injection) |
|-------------------|--------------------------|
| Claude "git log 볼게" → Bash 호출 → 결과 → 분석 (3 turn) | 스킬 호출 즉시 결과 주입 (0 turn) |
| 매번 동일한 정보를 도구로 수집 | 한 번 정의하면 자동 주입 |
| 컨텍스트 윈도우 + 도구 호출 오버헤드 | 순수 데이터만 주입 |

## 작성 규칙

### 기본 구문

```markdown
## Pre-injected Context (Dynamic Context Injection)

**Git 상태:**
!`git status --short 2>/dev/null`

**최근 커밋:**
!`git log --oneline -5 2>/dev/null`
```

### 필수 패턴

1. **`2>/dev/null` 항상 추가** — 명령 실패 시 stderr 누출 방지
2. **`|| echo "(fallback)"` 권장** — 빈 출력 방지로 Claude 혼란 예방
3. **`head -N` / `tail -N` 제한** — 대용량 출력 방지 (최대 50줄 권장)
4. **섹션 헤더에 `## Pre-injected Context` 사용** — 일관된 명명
5. **`${CLAUDE_SKILL_DIR}` 활용** — 스킬 번들 스크립트 참조 시

### 안티패턴

```markdown
# ❌ Bad - stderr 처리 없음
!`git status`

# ❌ Bad - 출력 제한 없음
!`cat apps/ai-agent/backend/prisma/schema.prisma`

# ❌ Bad - 파이프 실패 시 빈 출력
!`kubectl get pods | grep Running`

# ✅ Good
!`git status --short 2>/dev/null | head -20`
!`head -50 apps/ai-agent/backend/prisma/schema.prisma 2>/dev/null || echo "(파일 없음)"`
!`kubectl get pods 2>/dev/null | grep Running || echo "(클러스터 접근 불가)"`
```

## 사용 시점 판단

### Dynamic Injection 적합

| 조건 | 예시 |
|------|------|
| **매번 같은 정보를 수집** | git status, PROGRESS.md, 최근 에러 |
| **스킬 시작 시 반드시 필요** | 브랜치명, 현재 시간, 환경 정보 |
| **읽기 전용 데이터** | 로그, 설정 파일, 스키마 요약 |
| **결과가 작은 데이터** | 50줄 이하 출력 |

### 도구 호출이 더 적합

| 조건 | 이유 |
|------|------|
| **사용자 입력에 따라 달라짐** | 동적 경로, 에러 메시지 기반 검색 |
| **MCP 서버 호출** | serena, historian 등 전용 프로토콜 |
| **대용량 결과** | 파일 전체 읽기, DB 쿼리 |
| **조건부 실행** | "에러가 있으면 X, 없으면 Y" |

## 카테고리별 유용한 패턴

### Git 컨텍스트
```markdown
!`git branch --show-current 2>/dev/null`
!`git status --short 2>/dev/null | head -15`
!`git log --oneline -5 2>/dev/null`
!`git diff --cached --stat 2>/dev/null`
!`git diff --name-only HEAD~3..HEAD 2>/dev/null | head -15`
```

### 프로젝트 상태
```markdown
!`find docs/epics -name "PROGRESS.md" 2>/dev/null | sort -r | head -1 | xargs head -25 2>/dev/null`
!`ls -t .serena/memories/ 2>/dev/null | head -10`
!`tail -20 .claude/learnings/ERRORS.md 2>/dev/null || echo "(없음)"`
```

### 도메인 구조 (cowork 예시)
```markdown
!`grep -rn "@Controller\|@Get\|@Post" apps/ai-agent/backend/src/chat/ 2>/dev/null | head -20`
!`ls apps/ai-agent/frontend/src/features/cowork/ 2>/dev/null`
!`git log --oneline -5 -- apps/ai-agent/backend/src/chat/ 2>/dev/null`
```

### 환경/인프라
```markdown
!`date -u +%s`
!`kubectl config current-context 2>/dev/null || echo "(kubectl 미설정)"`
!`node -v 2>/dev/null` / !`python3 --version 2>/dev/null`
```

### Prisma/DB 스키마 요약
```markdown
!`grep -E "^model " apps/ai-agent/backend/prisma/schema.prisma 2>/dev/null`
!`grep -E "^  (id|name|status|type)" apps/ai-agent/backend/prisma/schema.prisma 2>/dev/null | head -30`
```

## agent-generator 적용

새 Agent/Skill 생성 시 **반드시** Dynamic Context Injection 활용 가능 여부를 검토:

1. 이 Agent/Skill이 **매번 동일한 정보를 수집하는가?** → `!`command`` 추가
2. 이 정보가 **50줄 이내로 요약 가능한가?** → `!`command` | head -N` 사용
3. 실패 시 **빈 출력이 되는가?** → `|| echo "(fallback)"` 추가

### 템플릿 예시

```yaml
---
name: my-skill
description: 설명
context: fork
---

# My Skill

## Pre-injected Context (Dynamic Context Injection)

**Git 상태:**
!`git status --short 2>/dev/null | head -10`

**관련 최근 변경:**
!`git log --oneline -5 -- {관련경로}/ 2>/dev/null`

## 실행 절차
...
```

## 참조
- [공식 문서](https://code.claude.com/docs/en/skills#inject-dynamic-context)
- `${CLAUDE_SKILL_DIR}` — 스킬 디렉토리 경로 (스크립트 참조용)
- `${CLAUDE_SESSION_ID}` — 세션 ID (로깅용)
- `$ARGUMENTS` / `$0`, `$1` — 스킬 인수 접근

---

_Version: 1.0 - 2026-03-20_
