# Next.js 변환 가이드

## 🔄 자동 변환 규칙

### 1. Import 구문 변환

```typescript
// BEFORE (Vite + React Router)
import { useNavigate, useParams } from 'react-router-dom';
import { useState, useEffect } from 'react';

// AFTER (Next.js)
import { useRouter, useParams } from 'next/navigation';
import { useState, useEffect } from 'react';
```

### 2. 라우팅 변환

```typescript
// BEFORE
const navigate = useNavigate();
navigate('/dashboard');

// AFTER
const router = useRouter();
router.push('/dashboard');
```

### 3. 데이터 페칭

```typescript
// BEFORE (useEffect + axios)
useEffect(() => {
  axios.get('/api/data').then(setData);
}, []);

// AFTER (Server Component 우선)
async function getData() {
  const res = await fetch('/api/data', { cache: 'no-store' });
  return res.json();
}

// 또는 Client Component
'use client';
const { data } = useQuery(['data'], fetchData);
```

### 4. 환경 변수

```typescript
// BEFORE
import.meta.env.VITE_API_URL

// AFTER
process.env.NEXT_PUBLIC_API_URL
```

## 📁 파일 구조 매핑

```
.reference/src/
├── pages/          → app/
│   ├── Home.tsx    → app/page.tsx
│   └── About.tsx   → app/about/page.tsx
├── components/     → src/shared/ui/
├── features/       → src/features/
└── api/            → app/api/
```

## ⚠️ 주의사항

### Client Component 마킹
- useState, useEffect 사용 → 'use client' 추가
- 브라우저 API 사용 → 'use client' 추가
- 이벤트 핸들러 → 'use client' 추가

### Server Component 최적화
- 데이터 페칭은 Server Component에서
- SEO 중요 페이지는 Server Component
- 정적 데이터는 generateStaticParams 활용

## 🧪 변환 검증

```bash
# 빌드 에러 확인
pnpm build

# 타입 체크
pnpm type-check

# 린트
pnpm lint
```
