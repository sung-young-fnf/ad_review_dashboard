# 📐 CODE PATTERNS (프로젝트 표준)

## Admin Impersonation (관리자 전환)
**문서**: [docs/patterns/fullstack/admin-impersonation.md](../docs/patterns/fullstack/admin-impersonation.md)

**필수 규칙**:
- 모든 백엔드 프록시 route에 `X-Impersonate-User` 헤더 추가
- `session.backendToken` 사용 (~~accessToken 아님~~)
- 헤더 패턴: `...(impersonatedUserId && { 'X-Impersonate-User': impersonatedUserId })`

**체크리스트**:
```typescript
// ✅ 표준 패턴
const session = await auth();
const impersonatedUserId = (session as any).impersonatedUserId;

const response = await fetch(backendUrl, {
  headers: {
    'Authorization': `Bearer ${session.backendToken}`,
    ...(impersonatedUserId && { 'X-Impersonate-User': impersonatedUserId }),
  },
});
```

---

## Next.js API Routes (HTTP 메서드 패턴)
**문서**: [docs/patterns/fullstack/api-routes.md](../docs/patterns/fullstack/api-routes.md)

**필수 규칙**:
- **405 에러 방지**: 프론트엔드에서 호출하는 모든 HTTP 메서드 구현 필수
- **404 에러 방지**: 중첩 엔드포인트는 **무조건 별도 디렉토리**
- **환경 변수**: `API_BASE_URL || BACKEND_URL || NEXT_PUBLIC_BACKEND_URL` fallback chain
- **Admin Impersonation**: 모든 메서드에 `X-Impersonate-User` 헤더 포함

### 일반적인 실수 1: 메서드 누락
```typescript
// ❌ DELETE 메서드 누락 → 405 Method Not Allowed
export async function GET(request: NextRequest) { ... }
export async function PUT(request: NextRequest) { ... }
// DELETE 없음 → 프론트엔드 delete() 호출 시 에러

// ✅ 필요한 모든 메서드 구현
export async function GET(request: NextRequest) { ... }
export async function PUT(request: NextRequest) { ... }
export async function DELETE(request: NextRequest) { ... }
```

### 일반적인 실수 2: 중첩 엔드포인트 (⚠️ 매우 빈번)
```typescript
// ❌ 잘못된 구조: [id]/route.ts에 activate 로직 추가 시도
resource/[id]/route.ts
→ `/api/v1/resource/123` ✅ 동작
→ `/api/v1/resource/123/activate` ❌ 404 에러

// ✅ 올바른 구조: 별도 디렉토리
resource/[id]/
├── route.ts              # GET, PUT, DELETE
└── activate/
    └── route.ts          # POST /activate
```

### 핵심 원칙
- Next.js App Router는 **하나의 route.ts = 하나의 경로**
- 동적 라우트(`[id]`) 내 중첩 엔드포인트는 **무조건 별도 디렉토리**
- 같은 route.ts 파일에 여러 URL 경로를 혼합할 수 없음

### 신규 API 추가 체크리스트
- [ ] **Backend API 우선 확인**: curl로 Backend 엔드포인트 존재 여부 확인 (Full-Stack 작업 시)
- [ ] GET, POST, PUT, DELETE 중 필요한 메서드 모두 구현
- [ ] 중첩 엔드포인트는 별도 디렉토리 생성
- [ ] 각 메서드에 `session.backendToken` 인증 체크
- [ ] 각 메서드에 Admin Impersonation 헤더 추가
- [ ] 환경 변수 fallback chain 사용
- [ ] 204 No Content 응답 처리 (DELETE 메서드)
- [ ] **Full-Stack E2E 검증**: Chrome DevTools로 실제 Backend 응답 확인

### 일반적인 실수 3: 백엔드 엔드포인트 미구현 (⚠️ Full-Stack Contract 불일치)
```yaml
증상:
  - Next.js API Route: POST /api/v1/team-feedback ✅ 구현됨
  - 백엔드 응답: 404 "Cannot POST /api/v1/team-okr/:teamId/feedback" ❌
  - Chrome DevTools 콘솔: "Failed to fetch" 또는 404 에러

원인:
  - Frontend는 구현했지만 Backend 엔드포인트가 없음
  - Epic/Story에서 Backend API 구현 Task 누락
  - 또는 Backend URL 경로가 잘못 매핑됨

해결:
  1. Backend API 구현 우선 (Controller + Service + Repository)
  2. 또는 Next.js API Route에서 올바른 Backend URL로 프록시
  3. Full-Stack E2E 검증 (Step 7.5)에서 사전 차단
```

**체크리스트 (Full-Stack 작업 시)**:
```typescript
// ❌ 잘못된 순서
1. Next.js API Route 먼저 구현
2. 배포 → 404 에러 발생
3. 뒤늦게 Backend API 구현

// ✅ 올바른 순서
1. Backend API 먼저 구현 (또는 동시 진행)
2. Next.js API Route 구현 (Backend URL 확인)
3. Full-Stack E2E 검증 (Chrome DevTools + Next.js MCP)
```

**검증 방법**:
```bash
# Backend 엔드포인트 존재 확인 (로컬)
curl -X POST http://localhost:8080/api/v1/team-okr/123/feedback \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{"rating": 5}'

# 200/201 응답 확인 → Next.js 프록시 구현 진행
# 404 응답 → Backend API 먼저 구현 필요
```

---

### 일반적인 실수 4: 단일 조회 엔드포인트 누락 (⚠️ 빈번)
```yaml
증상:
  - Frontend: GET /api/admin/services/{id} 호출
  - 응답: 405 Method Not Allowed
  - Backend에는 목록 조회(GET /)만 있고 단일 조회(GET /{id})가 없음

원인:
  - 목록 조회 API만 구현하고 단일 조회 API 누락
  - CRUD 구현 시 단일 조회를 빠뜨리는 흔한 실수
  - PUT/DELETE에서 ID로 접근하므로 GET/{id}도 당연히 있을 것으로 착각

해결:
  1. Backend에 GET /{id} 엔드포인트 추가
  2. 목록 조회와 동일한 응답 스키마 사용 (ServiceListItemResponse 등)
  3. 로직 중복 방지: 공통 변환 함수 추출 권장
```

**체크리스트 (CRUD API 구현 시)**:
```yaml
# 목록/단일 조회 패턴 확인
GET /resources         # 목록 조회 ✅
GET /resources/{id}    # 단일 조회 ← 누락하기 쉬움!
POST /resources        # 생성
PUT /resources/{id}    # 수정
DELETE /resources/{id} # 삭제
```

---

### 실제 사례
- `DELETE /api/v1/question-templates/[id]` 405 에러 (2025-10-30)
  - 원인: route.ts에 DELETE 메서드 핸들러 누락
  - 해결: DELETE 메서드 추가 + Admin Impersonation 패턴 적용
- `POST /api/v1/resource/[id]/activate` 404 에러 (반복 발생)
  - 원인: [id]/route.ts에 activate 로직 추가 시도
  - 해결: [id]/activate/route.ts 별도 디렉토리 생성
- `POST /api/v1/team-feedback` Backend 404 에러 (2025-11-04)
  - 원인: Next.js는 구현했지만 Backend 엔드포인트 미구현
  - 해결: Backend API 우선 구현 → Next.js 프록시 연결
- `GET /api/admin/services/{id}` 405 에러 (2025-12-11)
  - 원인: Backend에 목록 조회(GET /)만 있고 단일 조회(GET /{id}) 누락
  - 해결: GET /{service_id} 엔드포인트 추가

---

**참조**: `.claude/CLAUDE.md` → ABSOLUTE RULES (React Hook 무한 루프 방지)
