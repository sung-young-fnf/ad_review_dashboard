# Authentication Patterns

> Spark Note 프로젝트의 NextAuth + MS Entra ID 인증 패턴

## When to Use This Skill

- 인증/인가 로직 구현 시
- API Route에서 세션 처리 시
- Backend로 토큰 전달 시
- Admin Impersonation 구현 시

## Core Concepts

### 인증 흐름
```
User → NextAuth → MS Entra ID → JWT (backendToken)
                                      ↓
Frontend API Route → Backend (Bearer Token) → 응답
```

### 주요 토큰

| 토큰 | 용도 | 위치 |
|------|------|------|
| `session.backendToken` | Backend API 호출용 | NextAuth 세션 |
| `session.user` | 사용자 정보 | NextAuth 세션 |
| `X-Impersonate-User` | 관리자 대리 로그인 | Request Header |

## Patterns

### Pattern 1: Server Component 인증

```typescript
// app/(authenticated)/dashboard/page.tsx
import { auth } from '@/auth';
import { redirect } from 'next/navigation';

export default async function DashboardPage() {
  const session = await auth();

  // 인증 체크
  if (!session?.user) {
    redirect('/api/auth/signin?callbackUrl=/dashboard');
  }

  // backendToken 존재 확인
  if (!session.backendToken) {
    redirect('/api/auth/signin?error=token_expired');
  }

  return <Dashboard user={session.user} />;
}
```

### Pattern 2: API Route 인증

```typescript
// app/api/v1/campaigns/route.ts
import { auth } from '@/auth';
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const session = await auth();

  if (!session?.backendToken) {
    return NextResponse.json(
      { error: 'Unauthorized' },
      { status: 401 }
    );
  }

  const response = await fetch(`${BACKEND_URL}/api/v1/campaigns`, {
    headers: {
      'Authorization': `Bearer ${session.backendToken}`,
      'Content-Type': 'application/json',
    },
  });

  return NextResponse.json(await response.json());
}
```

### Pattern 3: Admin Impersonation

```typescript
// lib/server/api-server.ts
import { auth } from '@/auth';
import { cookies } from 'next/headers';

export async function fetchWithAuth(url: string, options?: RequestInit) {
  const session = await auth();
  if (!session?.backendToken) {
    throw new Error('No backend token');
  }

  const headers: HeadersInit = {
    'Authorization': `Bearer ${session.backendToken}`,
    'Content-Type': 'application/json',
  };

  // Admin Impersonation 체크
  const cookieStore = cookies();
  const impersonateUserId = cookieStore.get('impersonate-user-id')?.value;

  if (impersonateUserId && session.user.role === 'admin') {
    headers['X-Impersonate-User'] = impersonateUserId;
  }

  return fetch(url, {
    ...options,
    headers: {
      ...headers,
      ...options?.headers,
    },
  });
}
```

### Pattern 4: Client Component 인증 체크

```typescript
// components/AuthGuard.tsx
'use client';

import { useSession } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const { data: session, status } = useSession();
  const router = useRouter();

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/api/auth/signin');
    }
  }, [status, router]);

  if (status === 'loading') {
    return <LoadingSpinner />;
  }

  if (!session) {
    return null;
  }

  return <>{children}</>;
}
```

### Pattern 5: 역할 기반 접근 제어

```typescript
// lib/auth/roles.ts
export const ROLES = {
  ADMIN: 'admin',
  MANAGER: 'manager',
  MEMBER: 'member',
} as const;

export type Role = typeof ROLES[keyof typeof ROLES];

export function canManageTeam(role: Role): boolean {
  return role === ROLES.ADMIN || role === ROLES.MANAGER;
}

export function canAccessAdmin(role: Role): boolean {
  return role === ROLES.ADMIN;
}

// 사용
if (!canManageTeam(session.user.role)) {
  return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
}
```

### Pattern 6: 토큰 갱신 처리

```typescript
// auth.ts (NextAuth 설정)
export const { handlers, auth } = NextAuth({
  callbacks: {
    async jwt({ token, account }) {
      // 최초 로그인 시 토큰 저장
      if (account) {
        token.backendToken = account.access_token;
        token.expiresAt = account.expires_at;
      }

      // 토큰 만료 5분 전 갱신
      if (Date.now() < (token.expiresAt as number) * 1000 - 5 * 60 * 1000) {
        return token;
      }

      // 토큰 갱신 로직
      return refreshAccessToken(token);
    },

    async session({ session, token }) {
      session.backendToken = token.backendToken as string;
      session.user.id = token.sub as string;
      return session;
    },
  },
});
```

## Common Pitfalls

### ❌ accessToken 대신 backendToken 사용
```typescript
// ❌ accessToken은 MS Graph용
const token = session.accessToken;

// ✅ backendToken은 우리 Backend용
const token = session.backendToken;
```

### ❌ Client Component에서 직접 Backend 호출
```typescript
// ❌ 토큰 노출 위험
'use client';
const data = await fetch(BACKEND_URL, {
  headers: { 'Authorization': `Bearer ${token}` }
});

// ✅ API Route를 통해 호출
'use client';
const data = await fetch('/api/v1/campaigns');
```

### ❌ 인증 없이 페이지 렌더링
```typescript
// ❌ session이 null일 수 있음
export default async function Page() {
  const session = await auth();
  return <Component user={session.user} />; // Error!
}

// ✅ 인증 체크 후 렌더링
export default async function Page() {
  const session = await auth();
  if (!session?.user) {
    redirect('/api/auth/signin');
  }
  return <Component user={session.user} />;
}
```

### ❌ Impersonation 권한 체크 누락
```typescript
// ❌ 누구나 impersonate 가능
headers['X-Impersonate-User'] = impersonateUserId;

// ✅ Admin만 가능
if (impersonateUserId && session.user.role === 'admin') {
  headers['X-Impersonate-User'] = impersonateUserId;
}
```

## Related Skills

- @.claude/skills/nextjs-app-router.md - 페이지 구조
- @.claude/skills/api-route-proxy.md - API Route 패턴
