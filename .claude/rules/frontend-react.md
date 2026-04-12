---
paths:
  - "apps/*/frontend/**/*.{ts,tsx}"
  - "apps/*/frontend/**/*.{js,jsx}"
---

# Frontend Rules (Next.js/React)

> UI 패턴: @.claude/guides/UI_PATTERNS.md
> BFF 체크리스트: serena/read_memory → frontend-api-proxy-checklist

## BFF 패턴 (필수)
- `Browser → Next.js API Route → Backend` (직접 Backend 호출 금지)
- API Route 위치: `app/api/{resource}/route.ts`
- `auth()` wrapper로 인증 토큰 획득, `backendToken` 사용 (accessToken 아님)
- CORS/인증 우회 불가 상태 유지

## React 안전 규칙
- `useEffect` 의존성: **primitive만** (`userId`, `teamId`) — 객체/배열 금지 (무한 렌더)
- `useCallback` 의존성: 사용하는 state 반드시 포함 (stale closure 방지)
- 중첩 삼항 금지: 2단계+ → `if/else` 또는 객체 매핑

## UI 패턴
- Skeleton 로딩 (스피너 대신 레이아웃 유지)
- Shadow 대신 `bg-muted/50` 또는 `ring` 테두리
- Spacing: gap-1(4px 아이콘) / gap-2(8px 그룹) / gap-4(16px 섹션내) / gap-6(24px 섹션간)
- shadcn/ui 컴포넌트 우선 사용 (`@/components/ui/`)

## React Query Invalidation (필수)
> WHY: 같은 도메인 데이터를 여러 queryKey로 조회 → 개별 invalidation 누락 시 UI 불일치
> 스케줄 관련만 12곳 분산 → 8+ 커밋 반복 수정 사례 (2026-03-30)

- **도메인별 invalidation 유틸 필수** — 3개+ queryKey가 같은 도메인이면 유틸 함수로 통합
- **prefix match 사용** — `queryKey: ['scheduled-tasks']`로 하위 키 전부 무효화
- ❌ 개별 `queryClient.invalidateQueries({ queryKey: ['xxx', 'yyy', id] })` 나열 금지
- ✅ `invalidateScheduleQueries(queryClient)` 같은 유틸 한 줄 호출
- 예시: `features/scheduled-tasks/model/invalidate-schedule-queries.ts`
- **⚠️ prefix match는 배열 요소 단위** — `['a']`는 `['a-b']`와 매칭 안 됨 (문자열 부분일치 아님)
  - ❌ `queryKey: ['scheduled-task']` → `['scheduled-task-runs']` 무효화 안 됨
  - ✅ `queryKey: ['scheduled-task-runs']` 별도 추가 필요
  - 새 queryKey prefix 추가 시 invalidation 유틸에 반드시 반영

## FSD (Feature-Sliced Design) — ai-agent
- `features/{feature-name}/` 구조
- `index.ts`로 public API export
- 도메인 간 직접 import 금지 → shared 또는 entities 경유

## Type 동기화
- Backend 응답 = Frontend 타입 필드 일치
- snake_case(Backend) ↔ camelCase(Frontend) 변환 일관성
- OpenAPI 자동 생성 타입 활용: `generated/api.ts`
