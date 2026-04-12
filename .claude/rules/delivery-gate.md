---
globs: ["apps/*/backend/**", "apps/*/frontend/**"]
---

## Full-Stack Delivery Gate (기능 추가 시 필수)
> WHY: 백엔드만 완료 후 "완료" 보고 → 프론트엔드 미구현 → 사용자 재요청 반복 (커밋 로그 2026-03 분석)
> feat 커밋의 대다수가 백엔드 단독 — Phase 분리가 "Phase 1에서 끊기" 유발

**기능 추가(feat) Task 완료 조건** — 아래 모두 충족해야 "completed":
- [ ] **Backend**: Service + Controller/Handler + DTO/Schema
- [ ] **BFF Route**: `app/api/` Next.js API Route (Browser→Backend 프록시)
- [ ] **Frontend**: 컴포넌트에서 BFF 호출 + UI 연동
- [ ] **OpenAPI 타입 재생성** (Backend DTO 변경 시)

**예외 (한쪽만 허용):**
- 순수 인프라 (K8s, CI/CD, Helm) — Quick-Pass
- 사용자가 명시적으로 "백엔드만" / "프론트만" 지정
- 내부 로직 수정 (기존 API 시그니처 변경 없음)

❌ feat Task에서 Backend만 구현 후 "completed" = VIOLATION
❌ "프론트엔드는 다음 Phase에서" 단독 판단 = VIOLATION (사용자 승인 필수)
