# TanStack Query Patterns

> Spark Note 프로젝트의 TanStack Query v5 데이터 페칭 패턴

## When to Use This Skill

- Client Component에서 데이터 페칭 시
- 서버 상태 캐싱이 필요할 때
- Optimistic Updates 구현 시
- 무한 스크롤/페이지네이션 구현 시

## Core Concepts

### Query Key 규칙
```typescript
// 계층적 Query Key 구조
['campaigns']                        // 전체 캠페인 목록
['campaigns', campaignId]            // 특정 캠페인
['campaigns', campaignId, 'submissions'] // 캠페인의 제출물
['users', userId, 'spark-notes']     // 사용자의 스파크노트
```

### Stale Time vs Cache Time

| 설정 | 기본값 | 권장값 | 용도 |
|------|--------|--------|------|
| staleTime | 0 | 5분 | 데이터 신선도 |
| gcTime | 5분 | 30분 | 캐시 유지 시간 |

## Patterns

### Pattern 1: 기본 Query Hook

```typescript
// hooks/useCampaigns.ts
import { useQuery } from '@tanstack/react-query';

export function useCampaigns() {
  return useQuery({
    queryKey: ['campaigns'],
    queryFn: async () => {
      const res = await fetch('/api/v1/campaigns');
      if (!res.ok) throw new Error('Failed to fetch');
      return res.json();
    },
    staleTime: 5 * 60 * 1000, // 5분
  });
}

// 사용
function CampaignList() {
  const { data, isLoading, error } = useCampaigns();

  if (isLoading) return <Skeleton />;
  if (error) return <Error message={error.message} />;

  return <List items={data} />;
}
```

### Pattern 2: Mutation with Cache Invalidation

```typescript
// hooks/useCreateCampaign.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';

export function useCreateCampaign() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (newCampaign: CreateCampaignDTO) => {
      const res = await fetch('/api/v1/campaigns', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newCampaign),
      });
      if (!res.ok) throw new Error('Failed to create');
      return res.json();
    },
    onSuccess: () => {
      // 캐시 무효화
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
    },
  });
}
```

### Pattern 3: Optimistic Update

```typescript
// hooks/useUpdateSparkNote.ts
export function useUpdateSparkNote() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: updateSparkNote,

    // 낙관적 업데이트
    onMutate: async (newData) => {
      await queryClient.cancelQueries({ queryKey: ['spark-notes', newData.id] });

      const previousData = queryClient.getQueryData(['spark-notes', newData.id]);

      queryClient.setQueryData(['spark-notes', newData.id], newData);

      return { previousData };
    },

    // 에러 시 롤백
    onError: (err, newData, context) => {
      queryClient.setQueryData(
        ['spark-notes', newData.id],
        context?.previousData
      );
    },

    // 완료 후 동기화
    onSettled: (data, error, variables) => {
      queryClient.invalidateQueries({ queryKey: ['spark-notes', variables.id] });
    },
  });
}
```

### Pattern 4: Dependent Queries

```typescript
// 사용자 정보를 먼저 가져온 후 팀 정보 가져오기
function useUserAndTeam() {
  const userQuery = useQuery({
    queryKey: ['user'],
    queryFn: fetchUser,
  });

  const teamQuery = useQuery({
    queryKey: ['team', userQuery.data?.teamId],
    queryFn: () => fetchTeam(userQuery.data!.teamId),
    enabled: !!userQuery.data?.teamId, // user 로드 후 실행
  });

  return { userQuery, teamQuery };
}
```

## Common Pitfalls

### ❌ 무한 루프 (객체를 의존성에 포함)
```typescript
// ❌ 매 렌더링마다 새 객체 → 무한 refetch
useQuery({
  queryKey: ['data', { filter: filters }], // 객체!
  queryFn: fetchData,
});

// ✅ primitive 값 사용
useQuery({
  queryKey: ['data', filters.status, filters.date],
  queryFn: fetchData,
});
```

### ❌ 캐시 무효화 누락
```typescript
// ❌ mutation 후 캐시 그대로 → stale 데이터 표시
useMutation({
  mutationFn: createItem,
  // onSuccess 없음!
});

// ✅ 반드시 invalidate
useMutation({
  mutationFn: createItem,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['items'] });
  },
});
```

### ❌ enabled 없이 조건부 fetch
```typescript
// ❌ userId가 undefined일 때도 fetch 시도
useQuery({
  queryKey: ['user', userId],
  queryFn: () => fetchUser(userId), // undefined!
});

// ✅ enabled로 조건 지정
useQuery({
  queryKey: ['user', userId],
  queryFn: () => fetchUser(userId!),
  enabled: !!userId,
});
```

## Related Skills

- @.claude/skills/nextjs-app-router.md - Server Side 데이터 페칭
- @.claude/skills/api-route-proxy.md - API Route 패턴
