# Next.js App Router Patterns

> Spark Note 프로젝트의 Next.js 15 App Router 패턴

## When to Use This Skill

- 새로운 페이지/레이아웃 생성 시
- Server Component vs Client Component 결정 시
- 데이터 페칭 패턴 구현 시
- 라우트 그룹 구조 설계 시

## Core Concepts

### 라우트 그룹 구조
```
app/
├── (authenticated)/     # 인증 필요 페이지
│   ├── layout.tsx      # 인증 체크 + Sidebar
│   ├── dashboard/
│   ├── team/
│   └── campaigns/
├── (public)/           # 공개 페이지
│   └── login/
└── api/                # API Routes
    └── v1/
```

### Server vs Client Component

| 상황 | 컴포넌트 타입 | 이유 |
|------|-------------|------|
| 데이터 페칭 | Server | 직접 DB/API 접근 |
| 인터랙션 (onClick) | Client | 이벤트 핸들러 필요 |
| 상태 관리 (useState) | Client | React hooks 필요 |
| SEO 중요 | Server | 서버 렌더링 |

## Patterns

### Pattern 1: 인증된 페이지 구조

```typescript
// app/(authenticated)/team/page.tsx
import { auth } from '@/auth';
import { redirect } from 'next/navigation';
import { serverAPI } from '@/lib/server/api-server';

export default async function TeamPage() {
  // 1. 인증 체크 (Server Side)
  const session = await auth();
  if (!session?.user) {
    redirect('/api/auth/signin?callbackUrl=/team');
  }

  // 2. 데이터 페칭 (Server Side)
  const user = await serverAPI.get('/api/v1/auth/profile');
  const teamData = await serverAPI.get(`/api/v1/teams/${user.teamId}`);

  // 3. Client Component에 데이터 전달
  return <TeamDashboard user={user} initialData={teamData} />;
}
```

### Pattern 2: API Route Proxy

```typescript
// app/api/v1/[...path]/route.ts
import { auth } from '@/auth';
import { NextRequest, NextResponse } from 'next/server';

export async function GET(
  request: NextRequest,
  { params }: { params: { path: string[] } }
) {
  const session = await auth();
  if (!session?.backendToken) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const path = params.path.join('/');
  const response = await fetch(`${BACKEND_URL}/api/v1/${path}`, {
    headers: {
      'Authorization': `Bearer ${session.backendToken}`,
      'Content-Type': 'application/json',
    },
  });

  return NextResponse.json(await response.json());
}
```

### Pattern 3: Loading & Error States

```typescript
// app/(authenticated)/campaigns/loading.tsx
export default function Loading() {
  return <CampaignsSkeleton />;
}

// app/(authenticated)/campaigns/error.tsx
'use client';
export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div>
      <h2>문제가 발생했습니다</h2>
      <button onClick={reset}>다시 시도</button>
    </div>
  );
}
```

## Common Pitfalls

### ❌ Server Component에서 hooks 사용
```typescript
// ❌ 에러 발생
export default async function Page() {
  const [state, setState] = useState(); // Error!
}
```

### ❌ Client Component에서 async 사용
```typescript
// ❌ 에러 발생
'use client';
export default async function Page() { // Error!
  const data = await fetch(...);
}
```

### ❌ 인증 없이 backendToken 사용
```typescript
// ❌ null 가능성
const token = session.backendToken; // undefined일 수 있음

// ✅ 안전한 패턴
if (!session?.backendToken) {
  redirect('/api/auth/signin');
}
```

## Related Skills

- @.claude/skills/tanstack-query.md - Client Side 데이터 페칭
- @.claude/skills/auth-patterns.md - 인증 패턴
