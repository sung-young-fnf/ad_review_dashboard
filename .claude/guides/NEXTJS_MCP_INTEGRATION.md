# Next.js MCP 통합 가이드

> **Two-Layer Error Detection**: Next.js MCP (서버) + Chrome DevTools MCP (클라이언트) 협력 시스템

**작성일**: 2025-11-04
**통합 버전**: v1.0

---

## 📋 목차

1. [개요](#개요)
2. [Two-Layer Detection 아키텍처](#two-layer-detection-아키텍처)
3. [Agent별 통합 전략](#agent별-통합-전략)
4. [Hook 시스템 통합](#hook-시스템-통합)
5. [사용 시나리오](#사용-시나리오)
6. [트러블슈팅](#트러블슈팅)
7. [참조](#참조)

---

## 개요

### 목적

Next.js MCP와 Chrome DevTools MCP를 협력시켜 **Full-Stack E2E 검증**을 달성합니다:

- **서버 측 검증** (Next.js MCP): 빌드 에러, 런타임 에러, 페이지 메타데이터
- **클라이언트 측 검증** (Chrome DevTools MCP): 브라우저 콘솔, 네트워크, DOM 상태

### 핵심 이점

```yaml
Before (Chrome DevTools만 사용):
  - 브라우저 열고 나서야 에러 발견
  - Server Component 에러는 디버깅 어려움
  - 소스맵 없이 압축된 에러만 확인

After (Two-Layer Detection):
  - 80% 에러를 브라우저 열기 전 차단 ✅
  - 정확한 파일명:라인 번호 (소스맵) ✅
  - 서버/클라이언트 에러 분리 진단 ✅
```

---

## Two-Layer Detection 아키텍처

### 개념도

```
┌─────────────────────────────────────────────────────────┐
│                   Two-Layer Detection                    │
└─────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
      ┌─────▼─────┐                   ┌────▼─────┐
      │ Layer 1:  │                   │ Layer 2: │
      │ Next.js   │──────────────────▶│ Chrome   │
      │ MCP       │   Phase 0 → 1-3   │ DevTools │
      │ (Server)  │                   │ (Client) │
      └───────────┘                   └──────────┘
           │                               │
      ┌────▼────┐                     ┌────▼────┐
      │ Phase 0 │                     │ Phase 1 │
      │ Server  │                     │ Console │
      │ Errors  │                     │ Errors  │
      └─────────┘                     └─────────┘
           │                               │
      ┌────▼────┐                     ┌────▼────┐
      │ 80%     │                     │ 20%     │
      │ Pre-    │                     │ Client  │
      │ Filter  │                     │ Only    │
      └─────────┘                     └─────────┘
```

### 실행 순서

```yaml
1. Phase 0 (Next.js MCP - 서버 에러 우선 확인):
   Tools:
     - discover_servers → 포트 자동 감지
     - get_errors → 빌드/런타임 에러 조회
     - get_logs → 서버 로그 확인

   결과:
     - build errors → 즉시 수정, Phase 1 스킵
     - runtime errors → Server Component/Action 수정
     - no errors → Phase 1 진행

2. Phase 1-3 (Chrome DevTools - 클라이언트 검증):
   Tools:
     - list_console_messages → 브라우저 콘솔 에러
     - list_network_requests → API 요청 실패
     - take_snapshot → DOM 상태 검증

   결과:
     - 하이드레이션 에러 → 클라이언트 컴포넌트 수정
     - API 필드 매핑 누락 → Hook 수정
     - DOM 상태 불일치 → UI 로직 수정
```

---

## Agent별 통합 전략

### 1. error-fixer Agent

**파일**: `.claude/agents/99-utils/error-fixer.md`

**통합 내용**:

```yaml
Phase 0: Next.js MCP 서버 에러 우선 확인 [NEW - 2025-11-04]

실행 단계:
  1. 서버 탐색:
     mcp__next-devtools__nextjs_runtime --action discover_servers

  2. 에러 조회:
     mcp__next-devtools__nextjs_runtime \
       --action call_tool \
       --port {포트} \
       --toolName "get_errors"

  3. 에러 분류:
     - build: TypeScript, ESLint → 즉시 자동 수정
     - runtime: Server Component, Server Action → 서버 코드 수정
     - none: → Phase 1 (Chrome DevTools) 진행

효과:
  - 브라우저 열기 전 80% 에러 사전 차단
  - 소스맵 기반 정확한 파일 위치
  - 서버/클라이언트 에러 분리
```

**명령어**: `.claude/commands/error-fixer/check-nextjs-errors.sh`

### 2. code-writer Agent

**파일**: `.claude/agents/04-implementation/code-writer.md`

**통합 내용**:

```yaml
Step 7.5: Full-Stack E2E 검증 [CRUD 작업 시 필수]

0. Next.js MCP 서버 정보 수집 [NEW - 2025-11-04]

0-1. Next.js 개발 서버 확인
0-2. 페이지 메타데이터 조회:
  mcp__next-devtools__nextjs_runtime \
    --action call_tool \
    --toolName "get_page_metadata" \
    --args '{"path": "/campaign/submit"}'

  응답:
    {
      "route": "/campaign/submit",
      "isServerComponent": true,
      "hasClientComponents": true,
      "renderType": "SSR",
      "serverActions": ["submitCampaign", "saveDraft"]
    }

0-3. Server Action 추적 (필요시)

1-4. Chrome DevTools 검증 (기존 유지)

5. 서버 로그 확인:
  mcp__next-devtools__nextjs_runtime \
    --action call_tool \
    --toolName "get_logs"

6. Full-Stack 검증 결과:
  ✅ Next.js MCP: 서버 에러 없음
  ✅ Chrome DevTools: API 성공 + DOM 변경
```

### 3. ui-tester Agent

**파일**: `.claude/agents/04-implementation/ui-tester.md`

**통합 내용** (향후 계획):

```yaml
Phase 0: Next.js MCP 페이지 메타데이터 확인
  - SSR/CSR/SSG 렌더링 전략 파악
  - Server Component/Client Component 분리 확인
  - Acceptance Criteria에 반영

Phase 1-3: Chrome DevTools UI 검증 (기존 유지)
```

---

## Hook 시스템 통합

### Quality Gate Hook

**파일**: `.claude/hooks/utils/quality-gate.sh`

**통합 내용**:

```bash
# 5. Next.js MCP 서버 에러 검증 [NEW - 2025-11-04]
# Note: Bash Hook에서 MCP 도구 직접 호출 불가
# 대신 error-fixer Agent Phase 0가 자동으로 서버 에러 확인
# (참조: .claude/agents/99-utils/error-fixer.md - Phase 0)
#
# Next.js 빌드 에러 간접 확인 (fallback)
NEXT_ERROR_LOG="$REPO_ROOT/.next/error.log"
if [ -f "$NEXT_ERROR_LOG" ] && [ -s "$NEXT_ERROR_LOG" ]; then
  SCORE=$((SCORE - 20))
  ISSUES+=("Next.js 빌드 에러 감지 (.next/error.log 확인 필요)")
fi
```

### Hook의 제약사항 및 대안

**제약사항**:
- Hook은 Claude Code 외부에서 독립 Bash 프로세스로 실행
- MCP 통신 레이어에 접근 불가
- `mcp__next-devtools__*` 명령어 직접 호출 불가능

**대안**:
1. **간접 검증**: 파일 시스템 기반 (`.next/error.log` 존재 여부)
2. **Agent 위임**: error-fixer Phase 0에서 실제 MCP 도구 사용

**상세**: `.claude/guides/HOOK_DEVELOPMENT_GUIDE.md` - "MCP Tools와의 관계" 섹션

---

## 사용 시나리오

### 시나리오 1: 하이드레이션 에러

```yaml
Context: CRUD 작업 완료 → UI 검증 중

Phase 0 (Next.js MCP):
  get_errors → ✅ 빌드 에러 없음
  get_errors → ✅ 런타임 에러 없음
  → Phase 1로 진행

Phase 1 (Chrome DevTools):
  list_console_messages →
    ❌ "Text content does not match server-rendered HTML"

  분석:
    - 서버 렌더링: "Loading..."
    - 클라이언트 렌더링: 실제 데이터

  해결:
    - useEffect로 클라이언트 전용 데이터 처리
    - 또는 Suspense boundary 추가
```

### 시나리오 2: Server Action 에러

```yaml
Context: 폼 제출 → 500 에러 발생

Phase 0 (Next.js MCP):
  get_errors →
    ❌ Runtime error in Server Action:
       File: app/actions/submit.ts:45
       Error: Cannot read property 'id' of undefined

  해결:
    - Server Action 파일 수정 (submit.ts:45)
    - null 체크 추가
    - get_errors 재확인 → ✅ 에러 사라짐

  → Phase 1 스킵 (서버 측 해결)
```

### 시나리오 3: API 필드 매핑 누락

```yaml
Context: 새 필드 추가 → UI에 표시 안 됨

Phase 0 (Next.js MCP):
  get_errors → ✅ 에러 없음
  → Phase 1 진행

Phase 1 (Chrome DevTools):
  list_console_messages →
    ❌ "TypeError: Cannot read property 'newField' of undefined"

  list_network_requests →
    ✅ GET /api/v1/resource → 200 OK
    Response: { ..., newField: "value" }

  분석:
    - 백엔드 응답에 newField 존재
    - 프론트엔드 Hook에서 매핑 누락

  해결:
    - API Hook 파일 수정 (hooks.ts)
    - return { ..., newField: data.newField } 추가
```

---

## 트러블슈팅

### 1. Next.js MCP 서버를 찾을 수 없음

**증상**:
```
mcp__next-devtools__nextjs_runtime --action discover_servers
→ No Next.js servers found
```

**원인**:
- Next.js 개발 서버가 실행되지 않음
- 포트가 예상 범위(3000-3010) 밖

**해결**:
```bash
# 1. 개발 서버 확인
pgrep -f "next dev"

# 2. 서버 재시작
cd apps/frontend && pnpm dev

# 3. 명시적 포트 지정
mcp__next-devtools__nextjs_runtime \
  --action list_tools \
  --port 3001
```

### 2. get_errors가 에러를 반환하지 않는데 실제로는 에러 발생

**증상**:
- Phase 0: ✅ 에러 없음
- Phase 1: ❌ 브라우저 콘솔에 에러

**원인**:
- 클라이언트 전용 에러 (useEffect, Event Handler)
- 서버는 정상 렌더링, 브라우저에서만 에러

**해결**:
- 이것이 정상 동작 (Two-Layer의 목적)
- Phase 1 Chrome DevTools로 클라이언트 에러 감지

### 3. Hook에서 MCP 도구 호출 실패

**증상**:
```bash
# .claude/hooks/utils/quality-gate.sh
mcp__next-devtools__nextjs_runtime --action discover_servers
→ command not found
```

**원인**:
- Hook은 Claude Code 외부에서 실행
- MCP 도구는 Claude Code 내부에서만 사용 가능

**해결**:
- Hook: 간접 검증만 (파일 존재 확인)
- Agent: 실제 MCP 도구 사용 (error-fixer Phase 0)

**참조**: `.claude/guides/HOOK_DEVELOPMENT_GUIDE.md` - "MCP 도구 직접 호출 금지"

---

## 참조

### 수정된 파일 목록

```yaml
Agent 파일:
  - .claude/agents/99-utils/error-fixer.md
    → Phase 0 추가 (Next.js MCP 서버 에러 확인)

  - .claude/agents/04-implementation/code-writer.md
    → Step 7.5 강화 (Full-Stack 검증)

명령어 스크립트:
  - .claude/commands/error-fixer/check-nextjs-errors.sh (NEW)
    → Next.js MCP Phase 0 위임 스크립트

Hook 파일:
  - .claude/hooks/utils/quality-gate.sh
    → Next.js 에러 로그 간접 확인 추가

문서:
  - docs/analysis/debugging-workflow.md
    → Two-Layer Detection 아키텍처 설명

  - docs/testing/e2e-dom-state-verification.md
    → Full-Stack E2E Verification 업데이트

  - .claude/guides/HOOK_DEVELOPMENT_GUIDE.md
    → MCP Tools 제약사항 및 대안 추가

  - .claude/guides/NEXTJS_MCP_INTEGRATION.md (NEW)
    → 본 문서
```

### 관련 문서

- **Next.js MCP 공식 문서**: https://nextjs.org/docs/app/guides/mcp
- **Chrome DevTools MCP**: `.claude/guides/CHROME_DEVTOOLS_INTEGRATION.md` (기존)
- **Debugging Workflow**: `docs/analysis/debugging-workflow.md`
- **Hook Development Guide**: `.claude/guides/HOOK_DEVELOPMENT_GUIDE.md`

### MCP 도구 Quick Reference

**Next.js MCP** (`mcp__next-devtools__nextjs_runtime`):
```yaml
discover_servers:
  설명: 실행 중인 Next.js 서버 자동 탐색
  입력: 없음
  출력: [{ port, url, version }]

list_tools:
  설명: 사용 가능한 Next.js MCP 도구 목록
  입력: { port }
  출력: [{ name, description, inputSchema }]

call_tool:
  설명: Next.js MCP 도구 실행
  입력: { port, toolName, args? }
  출력: 도구별 응답

주요 도구:
  - get_errors: 빌드/런타임 에러 조회
  - get_page_metadata: 페이지 렌더링 정보
  - get_server_action_by_id: Server Action 추적
  - get_logs: 서버 로그 확인
  - get_project_metadata: 프로젝트 정보
```

**Chrome DevTools MCP** (`mcp__chrome-devtools__*`):
```yaml
list_pages:
  설명: 열린 브라우저 탭 목록

list_console_messages:
  설명: 콘솔 메시지 조회 (log, error, warn)

list_network_requests:
  설명: 네트워크 요청 조회 (fetch, xhr)

take_snapshot:
  설명: DOM 텍스트 스냅샷 (uid 기반)

take_screenshot:
  설명: 페이지 스크린샷 캡처
```

---

## 버전 히스토리

```yaml
v1.0 (2025-11-04):
  - 초기 통합 완료
  - error-fixer Phase 0 추가
  - code-writer Step 7.5 강화
  - Hook quality-gate 간접 검증 추가
  - 통합 문서 작성
```

---

**작성자**: Agent 최적화 프로젝트
**검토자**: Claude Code
**승인일**: 2025-11-04
