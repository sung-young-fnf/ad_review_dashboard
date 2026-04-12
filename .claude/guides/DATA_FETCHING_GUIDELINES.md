# DATA FETCHING GUIDELINES (Agent 전용)

> **목적**: code-writer Agent가 데이터 페칭 구현 시 자동으로 올바른 패턴을 선택하도록 가이드

---

## 🎯 핵심 원칙 (MANDATORY)

### 1. Server-first (YAGNI)
- **기본**: Server Components + `serverAPI` (80%)
- **예외**: React Query (20%, 체크리스트 2개 이상)

### 2. 프로젝트 표준 준수
- ✅ `serverAPI` 사용 (자동 인증 + Admin Impersonation)
- ❌ DB 직접 접근 금지
- ❌ axios 직접 사용 금지 (serverAPI로 통일)

---

## 🔍 자동 판단 로직 (Step-by-Step)

### Step 1: 데이터 페칭 유형 분석

```yaml
요청 분석:
  읽기 (조회):
    - 키워드: "조회", "가져오기", "표시", "보여주기", "fetch", "get"
    → Server Component 우선 고려

  쓰기 (생성/수정/삭제):
    - 키워드: "생성", "수정", "삭제", "저장", "업데이트", "post", "put", "delete"
    → Server Action 우선 고려

  복잡한 상호작용:
    - 키워드: "실시간", "폴링", "무한 스크롤", "낙관적", "캐시 공유"
    → React Query 체크리스트 확인
```

---

### Step 2: React Query 체크리스트 확인

**다음 중 2개 이상 충족하는가?**

```yaml
✅ React Query 사용 조건:
  1. [ ] 낙관적 업데이트 필요 (Optimistic Updates)
     - "즉시 반영", "낙관적", "optimistic"

  2. [ ] 무한 스크롤/가상화 리스트
     - "무한 스크롤", "더 보기", "infinite scroll", "pagination"

  3. [ ] 폴링/포커스 리페치 (30초 이하)
     - "실시간", "폴링", "자동 갱신", "polling", "refetch"

  4. [ ] 동일 데이터의 다중 컴포넌트/페이지 공유
     - "여러 컴포넌트", "캐시 공유", "shared cache"

  5. [ ] 오프라인/네트워크 회복 탄력성 요구
     - "오프라인", "네트워크 복구", "offline", "resilience"

  6. [ ] 복잡한 Mutation 플로우 (다단계)
     - "다단계 업데이트", "복잡한 플로우", "multi-step"

판단:
  - 2개 이상 충족: React Query 사용
  - 1개 이하: Server Component/Action 사용
```

---

### Step 3: 패턴 선택

```yaml
읽기 (조회):
  React Query 체크리스트 2개 이상:
    → React Query (Client Component)

  그 외:
    → Server Component + serverAPI.get()

쓰기 (생성/수정/삭제):
  낙관적 업데이트 또는 복잡한 Mutation:
    → React Query useMutation (Client Component)

  그 외:
    → Server Action + serverAPI.post/put/delete()
```

---

## 📐 코드 생성 템플릿

### Template 1: Server Component (읽기 - 기본)

```typescript
// ✅ 사용 조건: 단순 조회, 정적/반정적 콘텐츠
import { serverAPI } from '@/lib/server/api-server';

async function {{ComponentName}}({ {{params}} }: Props) {
  const {{dataName}} = await serverAPI.get('{{apiPath}}', {
    next: {
      revalidate: {{cacheSeconds}},  // 캐싱 시간 (초)
      tags: ['{{tagName}}']          // 캐시 태그
    }
  });

  return (
    <div>
      {/* UI 렌더링 */}
    </div>
  );
}
```

**변수 결정 규칙**:
- `{{cacheSeconds}}`:
  - 실시간성 높음: 10-30초
  - 중간: 60-300초 (1-5분)
  - 정적: 3600초 (1시간)
- `{{tagName}}`: API 엔티티명 (user, team, campaign 등)

---

### Template 2: Server Action (쓰기 - 기본)

```typescript
// ✅ 사용 조건: 폼 제출, 단순 CRUD
'use server';

import { serverAPI } from '@/lib/server/api-server';
import { revalidateTag } from 'next/cache';
import { redirect } from 'next/navigation';

export async function {{actionName}}(formData: FormData) {
  // 1. FormData 파싱
  const {{fieldName}} = formData.get('{{fieldName}}') as string;

  // 2. Backend API 호출
  await serverAPI.{{method}}('{{apiPath}}', {
    {{fieldName}},
  });

  // 3. 캐시 무효화
  revalidateTag('{{tagName}}');

  // 4. 리다이렉트 (선택)
  redirect('{{redirectPath}}');
}
```

**변수 결정 규칙**:
- `{{method}}`: post (생성), put (수정), delete (삭제)
- `{{tagName}}`: Server Component의 tags와 동일
- `{{redirectPath}}`: 성공 후 이동할 페이지

---

### Template 3: React Query (복잡한 상호작용 - 예외)

```typescript
// ✅ 사용 조건: 체크리스트 2개 이상 충족
'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// 읽기 (폴링/실시간)
function {{ComponentName}}() {
  const { data, isLoading } = useQuery({
    queryKey: ['{{queryKey}}'],
    queryFn: () => fetch('{{apiPath}}').then(r => r.json()),
    refetchInterval: {{intervalMs}},  // 폴링 간격 (밀리초)
    staleTime: {{staleTimeMs}},       // fresh 유지 시간
  });

  if (isLoading) return <Skeleton />;
  return <div>{/* UI */}</div>;
}

// 쓰기 (낙관적 업데이트)
function {{ComponentName}}() {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (data: {{DataType}}) =>
      fetch('{{apiPath}}', {
        method: '{{METHOD}}',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      }),

    // 낙관적 업데이트 (선택)
    onMutate: async (newData) => {
      await queryClient.cancelQueries({ queryKey: ['{{queryKey}}'] });
      const previous = queryClient.getQueryData(['{{queryKey}}']);

      queryClient.setQueryData(['{{queryKey}}'], (old: {{DataType}}[]) =>
        [...old, newData]
      );

      return { previous };
    },

    onError: (err, newData, context) => {
      queryClient.setQueryData(['{{queryKey}}'], context?.previous);
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['{{queryKey}}'] });
    },
  });

  return <div>{/* UI */}</div>;
}
```

**변수 결정 규칙**:
- `{{intervalMs}}`: 폴링 간격 (30000ms = 30초)
- `{{staleTimeMs}}`: fresh 유지 (10000ms = 10초)
- 낙관적 업데이트: 체크리스트에 포함된 경우만 추가

---

## ⚠️ 필수 검증 (Auto-Validation)

### 구현 전 체크

```yaml
1. serverAPI 사용 확인:
   - [ ] import { serverAPI } from '@/lib/server/api-server';
   - [ ] serverAPI.get/post/put/delete() 사용
   - [ ] ❌ fetch() 직접 사용 금지 (Server Component/Action)
   - [ ] ❌ axios 직접 사용 금지

2. 캐싱 전략 확인:
   - [ ] Server Component: next.revalidate 또는 next.tags 설정
   - [ ] Server Action: revalidateTag() 또는 revalidatePath() 호출
   - [ ] React Query: staleTime, refetchInterval 적절한 값

3. 인증/권한 확인:
   - [ ] serverAPI는 자동 처리 (session.backendToken + X-Impersonate-User)
   - [ ] fetch() 직접 사용 시: Authorization 헤더 수동 추가 필요

4. Anti-pattern 회피:
   - [ ] Server fetch + React Query 중복 호출 금지
   - [ ] 단순 조회에 React Query 사용 금지
   - [ ] DB 직접 접근 금지 (serverAPI 사용)
```

---

## 🚨 에러 케이스 처리

### Case 1: 단순 조회에 React Query 사용 감지

```yaml
감지:
  - 요청: "사용자 프로필 조회"
  - 체크리스트: 0개 충족

자동 수정:
  - ❌ useQuery() 제거
  - ✅ Server Component + serverAPI.get() 변경

이유:
  - YAGNI 원칙 위반
  - 불필요한 클라이언트 번들 증가
```

---

### Case 2: serverAPI 미사용 감지

```yaml
감지:
  - Server Action에서 fetch() 직접 사용
  - 또는 axios 사용

자동 수정:
  - ❌ fetch('/api/v1/users', ...) 제거
  - ✅ serverAPI.get('/api/v1/users', ...) 변경

이유:
  - 인증 헤더 수동 관리 필요
  - Admin Impersonation 누락 위험
```

---

### Case 3: 캐싱 전략 누락 감지

```yaml
감지:
  - Server Component에서 next.revalidate 또는 next.tags 누락

자동 수정:
  - 기본값 추가: { next: { revalidate: 60 } }

이유:
  - Next.js 기본 캐싱 활용
  - 불필요한 API 호출 방지
```

---

## 📋 의사결정 플로우차트 (Quick Reference)

```
데이터 페칭 요청 수신
    ↓
읽기 OR 쓰기?
    ↓
┌─────────────┬─────────────┐
│   읽기      │   쓰기      │
└─────────────┴─────────────┘
    ↓              ↓
React Query      낙관적 OR
체크리스트      복잡한 Mutation?
2개 이상?
    ↓              ↓
┌────┬────┐   ┌────┬────┐
│YES │NO  │   │YES │NO  │
└────┴────┘   └────┴────┘
  ↓    ↓        ↓    ↓
React Server  React Server
Query Comp.   Query Action
(Client) (SSR) (Client) (Server)
```

---

## 🔗 참조 문서

- **상세 가이드**: [docs/analysis/data-fetching-patterns.md](../../docs/analysis/data-fetching-patterns.md)
- **프로젝트 패턴**: [.claude/guides/CODE_PATTERNS.md](CODE_PATTERNS.md)
- **serverAPI 상세**: [apps/frontend/src/lib/server/api-server.ts](../../apps/frontend/src/lib/server/api-server.ts)

---

## 💡 실전 예시

### 예시 1: "사용자 목록 조회" 요청

```yaml
분석:
  - 유형: 읽기 (조회)
  - 체크리스트: 0개 충족
  - 판단: Server Component

생성 코드:
```
```typescript
import { serverAPI } from '@/lib/server/api-server';

async function UserList() {
  const users = await serverAPI.get('/api/v1/users', {
    next: { revalidate: 60, tags: ['user'] }
  });

  return (
    <ul>
      {users.map(user => <li key={user.id}>{user.name}</li>)}
    </ul>
  );
}
```

---

### 예시 2: "실시간 대시보드 (30초 갱신)" 요청

```yaml
분석:
  - 유형: 읽기 (조회)
  - 체크리스트: 2개 충족
    ✅ 폴링 (30초)
    ✅ 다중 컴포넌트 캐시 공유
  - 판단: React Query

생성 코드:
```
```typescript
'use client';
import { useQuery } from '@tanstack/react-query';

function LiveDashboard() {
  const { data } = useQuery({
    queryKey: ['dashboard'],
    queryFn: () => fetch('/api/v1/dashboard').then(r => r.json()),
    refetchInterval: 30000,
    staleTime: 10000,
  });

  return <div>{/* 실시간 데이터 */}</div>;
}
```

---

### 예시 3: "사용자 정보 수정 (폼 제출)" 요청

```yaml
분석:
  - 유형: 쓰기 (수정)
  - 낙관적 업데이트: 불필요
  - 판단: Server Action

생성 코드:
```
```typescript
'use server';
import { serverAPI } from '@/lib/server/api-server';
import { revalidateTag } from 'next/cache';
import { redirect } from 'next/navigation';

export async function updateUser(formData: FormData) {
  const userId = formData.get('userId') as string;
  const name = formData.get('name') as string;

  await serverAPI.put(`/api/v1/users/${userId}`, { name });
  revalidateTag('user');
  redirect('/profile');
}
```

---

## 🎯 Summary

| 조건 | 패턴 | 도구 |
|-----|------|-----|
| 읽기 + 단순 조회 | Server Component | `serverAPI.get()` + `next.revalidate` |
| 읽기 + 체크리스트 2개+ | React Query | `useQuery()` + `refetchInterval` |
| 쓰기 + 단순 CRUD | Server Action | `serverAPI.post/put/delete()` + `revalidateTag()` |
| 쓰기 + 낙관적 업데이트 | React Query | `useMutation()` + `onMutate` |

**핵심**: 기본은 Server (80%), React Query는 체크리스트 2개 이상 (20%)
