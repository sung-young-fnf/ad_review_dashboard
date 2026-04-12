---
name: cowork-debug
description: "Cowork 채팅/지식패널/스트리밍 도메인 진단 스킬. Dynamic Context Injection으로 도메인 구조 자동 주입. Use when: cowork 관련 버그, 채팅 이슈, 지식패널 문제, 스트리밍 끊김"
effort: medium
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - mcp__serena__find_symbol
  - mcp__serena__get_symbols_overview
  - mcp__serena__find_referencing_symbols
  - mcp__serena__search_for_pattern
  - mcp__serena__read_memory
  - mcp__historian__get_error_solutions
user-invocable: true
context: fork
agent: Explore
---

# Cowork Debug Skill

> cowork + chat 도메인 전용 진단 — Pre-injected Context로 탐색 시간 0분

## Pre-injected Context (Dynamic Context Injection)

### Backend 구조

**Controller + API 엔드포인트:**
!`find apps/ai-agent/backend/src/chat/ -name "*.controller.ts" -exec grep -n "^\s*@\(Get\|Post\|Put\|Delete\|Controller\)" {} + 2>/dev/null | head -30`

**Service 레이어 (핵심 비즈니스 로직):**
!`find apps/ai-agent/backend/src/chat/services/ -name "*.ts" 2>/dev/null | head -15`

**DTO 구조 (API 계약):**
!`find apps/ai-agent/backend/src/chat/ -name "*.dto.ts" -exec grep -n "export class" {} + 2>/dev/null | head -15`

**Repository 레이어:**
!`find apps/ai-agent/backend/src/chat/ -name "*.repository.ts" 2>/dev/null`

### DB 스키마

**Cowork/Chat/Knowledge 관련 Prisma 모델:**
!`grep -B1 -A15 "model.*[Cc]owork\|model.*[Kk]nowledge\|model.*[Cc]hat[Ss]ession\|model.*[Cc]hat[Mm]essage" apps/ai-agent/backend/prisma/schema.prisma 2>/dev/null | head -60`

### Frontend 구조

**Cowork 컴포넌트:**
!`find apps/ai-agent/frontend/src/features/cowork/ -name "*.tsx" -o -name "*.ts" 2>/dev/null | head -15`

**Cowork Knowledge 컴포넌트:**
!`find apps/ai-agent/frontend/src/features/cowork-knowledge/ -name "*.tsx" -o -name "*.ts" 2>/dev/null | head -10`

**Chat Widget:**
!`find apps/ai-agent/frontend/src/widgets/chat/ -name "*.tsx" -o -name "*.ts" 2>/dev/null | head -10`

**BFF Route (프록시 체인):**
!`find apps/ai-agent/frontend/src/app/api/ -path "*cowork*" -o -path "*chat*" -o -path "*knowledge*" 2>/dev/null | grep -v node_modules | head -15`

### 변경 히스토리

**최근 Backend 변경 (5개):**
!`git log --oneline -5 -- apps/ai-agent/backend/src/chat/ 2>/dev/null`

**최근 Frontend 변경 (5개):**
!`git log --oneline -5 -- apps/ai-agent/frontend/src/features/cowork/ apps/ai-agent/frontend/src/widgets/chat/ 2>/dev/null`

### 과거 이슈 참조

**관련 에러 기록:**
!`grep -i "cowork\|knowledge\|chat.*stream\|chat.*error" .claude/learnings/ERRORS.md 2>/dev/null | tail -10 || echo "(관련 에러 없음)"`

**관련 솔루션 문서:**
!`ls docs/solutions/ 2>/dev/null | grep -i "cowork\|chat\|stream\|knowledge" || echo "(관련 솔루션 없음)"`

---

## 진단 절차

### Step 1: 증상 분류

사용자 보고 증상을 아래 카테고리로 분류:

| 카테고리 | 증상 예시 | 추적 시작점 |
|----------|----------|------------|
| **채팅 스트리밍** | 메시지 안 옴, 끊김, 지연 | `agent-streaming.service.ts` → `streaming-config.builder.ts` |
| **지식 패널** | 검색 안 됨, 문서 미표시 | `cowork-knowledge.controller.ts` → `KnowledgePanel.tsx` |
| **세션 관리** | 세션 생성 실패, 로드 불가 | Prisma `CoworkSession` → `ChatWidget.tsx` |
| **컨텍스트 빌드** | 잘못된 컨텍스트, 누락 | `context.builder.ts` → API 응답 확인 |
| **UI 렌더링** | 컴포넌트 미표시, 레이아웃 | `CoworkRightPanel.tsx` → Route 추적 |

### Step 2: 코드 경로 추적

Pre-injected Context의 파일 목록을 기반으로 Top-Down 추적:

1. **API 진입점** → Controller에서 해당 엔드포인트 찾기
2. **Service 호출** → `serena/find_referencing_symbols`로 호출 체인 따라가기
3. **데이터 흐름** → DTO → Service → Repository → Prisma 모델
4. **Frontend 연동** → BFF Route → 컴포넌트 props 확인

### Step 3: 근본 원인 보고

```
## Cowork 진단 결과

**도메인:** [채팅 스트리밍 / 지식 패널 / 세션 관리 / 컨텍스트 / UI]
**근본 원인:** [기술적 설명 1-2문장]

**증거:**
- [파일:라인] — [해당 코드가 문제인 이유]
- [파일:라인] — [연관된 코드]

**데이터 흐름:**
Frontend 컴포넌트 → BFF Route → Backend Controller → Service → Repository/Prisma

**수정 방안:**
1. [방안 A] — [장단점]
2. [방안 B] — [장단점]

**추천:** [방안 X] — [근거]
```

## 핵심 규칙

1. **코드 변경 금지** — 진단만 수행 (Edit/Write 사용 불가)
2. **Pre-injected Context 먼저 참조** — 도구 호출 전에 이미 주입된 정보 활용
3. **BFF 체인 확인 필수** — Browser → Next.js API Route → Backend 전체 경로 추적
4. **과거 이슈 매칭** — Pre-injected 에러 기록/솔루션에서 유사 패턴 확인
5. **$ARGUMENTS 활용** — 사용자가 전달한 증상 설명을 즉시 분류에 사용

## 사용 예시

```
/cowork-debug "지식패널에서 문서 검색이 안 됨"
/cowork-debug "채팅 스트리밍이 중간에 끊김"
/cowork-debug "cowork 세션 로드 실패"
```
