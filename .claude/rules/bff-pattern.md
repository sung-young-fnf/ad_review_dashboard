## BFF 패턴 (필수)

```
Browser → Next.js /api/v1/[...path] → Backend
```

- ❌ 브라우저에서 Backend 직접 호출 금지
- ❌ `NEXT_PUBLIC_BACKEND_URL` 으로 클라이언트에서 직접 fetch 금지
- ✅ `/api/v1/[...path]/route.ts` catch-all proxy 사용
- ✅ 서버사이드에서만 `process.env.BACKEND_URL` 접근
- ✅ SSO 설정 시 `auth()` → `session.accessToken` → Bearer 토큰 전달
