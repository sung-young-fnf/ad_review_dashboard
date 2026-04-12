# React Performance Best Practices (Vercel 기반)

> **출처**: Vercel Engineering React Best Practices
> **버전**: 1.0 (2026-01)
> **상세 문서**: @.claude/guides/vercel-react-best-practices/

---

## Quick Reference: 우선순위별 규칙

| 우선순위 | 카테고리 | 영향도 | 주요 규칙 |
|:--------:|----------|--------|----------|
| **1** | Waterfall 제거 | CRITICAL | Promise.all, better-all, Suspense |
| **2** | Bundle 최적화 | CRITICAL | Direct import, Dynamic import |
| **3** | Server-side | HIGH | React.cache, LRU cache, after() |
| **4** | Client fetch | MEDIUM-HIGH | SWR dedup, Passive listeners |
| **5** | Re-render | MEDIUM | Primitive deps, Functional setState |
| **6** | Rendering | MEDIUM | content-visibility, Hoist JSX |
| **7** | JS 최적화 | LOW-MEDIUM | Set/Map lookup, toSorted |
| **8** | Advanced | LOW | useEffectEvent, useLatest |

---

## 1. Waterfall 제거 (CRITICAL)

### Promise.all 패턴
```typescript
// ❌ 순차 (3 round trips)
const user = await fetchUser();
const posts = await fetchPosts();

// ✅ 병렬 (1 round trip)
const [user, posts] = await Promise.all([
  fetchUser(), fetchPosts()
]);
```

### API Routes 패턴
```typescript
// ✅ 의존성 있는 경우
export async function GET() {
  const authPromise = auth();        // 즉시 시작
  const configPromise = fetchConfig(); // 즉시 시작

  const session = await authPromise;
  const [config, data] = await Promise.all([
    configPromise,
    fetchData(session.user.id)
  ]);

  return Response.json({ data, config });
}
```

### Suspense Boundary
```tsx
// ✅ 레이아웃은 즉시, 데이터는 스트리밍
function Page() {
  return (
    <div>
      <Header />
      <Suspense fallback={<Skeleton />}>
        <DataDisplay />  {/* 이것만 대기 */}
      </Suspense>
      <Footer />
    </div>
  );
}

async function DataDisplay() {
  const data = await fetchData();
  return <div>{data.content}</div>;
}
```

---

## 2. Bundle 최적화 (CRITICAL)

### Direct Import
```typescript
// ❌ Barrel import (전체 로드)
import { Check, X } from 'lucide-react';       // 1,583 모듈
import { Button } from '@mui/material';         // 2,225 모듈

// ✅ Direct import (필요한 것만)
import Check from 'lucide-react/dist/esm/icons/check';
import Button from '@mui/material/Button';
```

### Next.js 설정
```javascript
// next.config.js
module.exports = {
  experimental: {
    optimizePackageImports: [
      'lucide-react', '@mui/material', '@radix-ui/react-*',
      'react-icons', 'date-fns', 'lodash'
    ]
  }
};
```

### Dynamic Import
```tsx
import dynamic from 'next/dynamic';

// ✅ 무거운 컴포넌트 (Monaco ~300KB)
const MonacoEditor = dynamic(
  () => import('./monaco-editor').then(m => m.MonacoEditor),
  { ssr: false }
);

// ✅ Analytics 지연 로드
const Analytics = dynamic(
  () => import('@vercel/analytics/react').then(m => m.Analytics),
  { ssr: false }
);
```

---

## 3. Server-side 성능 (HIGH)

### React.cache (요청 내 중복제거)
```typescript
import { cache } from 'react';

export const getCurrentUser = cache(async () => {
  const session = await auth();
  return await db.user.findUnique({
    where: { id: session.user.id }
  });
});

// 같은 요청 내에서 여러 번 호출해도 1번만 실행
```

### LRU Cache (요청 간 캐싱)
```typescript
import { LRUCache } from 'lru-cache';

const cache = new LRUCache<string, any>({
  max: 1000,
  ttl: 5 * 60 * 1000  // 5분
});

export async function getUser(id: string) {
  const cached = cache.get(id);
  if (cached) return cached;

  const user = await db.user.findUnique({ where: { id } });
  cache.set(id, user);
  return user;
}
```

### after() (Non-blocking)
```typescript
import { after } from 'next/server';

export async function POST(request: Request) {
  await updateDatabase(request);

  // 응답 전송 후 실행 (비차단)
  after(async () => {
    await logUserAction({ ... });
  });

  return Response.json({ status: 'success' });
}
```

---

## 4. Re-render 최적화 (MEDIUM)

### Primitive 의존성
```typescript
// ❌ 객체 변경 시 항상 리렌더
useEffect(() => { ... }, [user]);

// ✅ id 변경 시에만 리렌더
useEffect(() => { ... }, [user.id]);
```

### Functional setState
```typescript
// ❌ items 의존성 필요, 불안정
const addItem = useCallback((item) => {
  setItems([...items, item]);
}, [items]);

// ✅ 의존성 불필요, 안정적
const addItem = useCallback((item) => {
  setItems(curr => [...curr, item]);
}, []);
```

### Immutable 배열 메서드
```typescript
// ❌ 원본 mutate
const sorted = items.sort((a, b) => a.value - b.value);

// ✅ 새 배열 반환 (React 안전)
const sorted = items.toSorted((a, b) => a.value - b.value);

// 다른 immutable 메서드
items.toReversed();           // reverse
items.toSpliced(index, 1);    // splice
items.with(index, newValue);  // 요소 교체
```

### Lazy State Init
```typescript
// ❌ 매 렌더마다 buildIndex 실행
const [index] = useState(buildIndex(items));

// ✅ 초기 렌더에만 실행
const [index] = useState(() => buildIndex(items));
```

---

## 5. 렌더링 성능 (MEDIUM)

### content-visibility
```css
.list-item {
  content-visibility: auto;
  contain-intrinsic-size: 0 80px;
}
```

### SVG 애니메이션
```tsx
// ❌ SVG 직접 애니메이션 (하드웨어 가속 없음)
<svg className="animate-spin">...</svg>

// ✅ Wrapper div 애니메이션 (GPU 가속)
<div className="animate-spin">
  <svg>...</svg>
</div>
```

---

## 6. 적용 체크리스트

### code-writer 구현 시 확인
```yaml
Waterfall:
  - [ ] 독립 fetch들이 Promise.all로 병렬화되어 있는가?
  - [ ] API route에서 promise 먼저 시작, await는 나중에?
  - [ ] 불필요한 await이 early return을 막고 있지 않은가?

Bundle:
  - [ ] lucide-react, @mui 등 direct import 사용?
  - [ ] 무거운 컴포넌트는 dynamic import?
  - [ ] next.config.js optimizePackageImports 설정?

Re-render:
  - [ ] useEffect 의존성이 primitive인가?
  - [ ] setState가 functional form 사용?
  - [ ] .sort() 대신 .toSorted() 사용?
```

---

## 상세 문서

전체 45개 룰 및 코드 예제:
```
@.claude/guides/vercel-react-best-practices/AGENTS.md
```

개별 룰 파일:
```
@.claude/guides/vercel-react-best-practices/rules/
├── async-parallel.md
├── async-suspense-boundaries.md
├── bundle-barrel-imports.md
├── bundle-dynamic-imports.md
├── rerender-dependencies.md
├── rerender-functional-setstate.md
└── ... (40+ 룰)
```
