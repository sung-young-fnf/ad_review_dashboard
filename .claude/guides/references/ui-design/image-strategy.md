# Image Strategy (상세)

> **상위 문서**: @.claude/guides/UI_DESIGN_SYSTEM.md
> **용도**: 이미지 선택 및 최적화 상세 가이드

---

## 이미지 소스 우선순위

| 우선순위 | 소스 | 용도 | 장점 |
|---------|------|------|------|
| **1** | Unsplash Direct URL | 실제 사진, 배경 | 고품질, 무료, 즉시 사용 |
| **2** | AI 생성 (프롬프트 제공) | 일러스트, 아이콘, 추상 | 커스텀 가능, 독창성 |
| **3** | Lucide/Heroicons | 아이콘 | 일관성, 가벼움 |
| **4** | 플레이스홀더 | 개발 중 임시 | 빠른 프로토타이핑 |

---

## Unsplash Direct URL 패턴

### 기본 URL 구조
```
https://images.unsplash.com/photo-{PHOTO_ID}?w={WIDTH}&h={HEIGHT}&fit=crop&q=80
```

### 카테고리별 권장 이미지

#### 비즈니스/SaaS
```typescript
const BUSINESS_IMAGES = {
  teamwork: "https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=1200&h=800&fit=crop&q=80",
  office: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&h=800&fit=crop&q=80",
  meeting: "https://images.unsplash.com/photo-1552664730-d307ca884978?w=1200&h=800&fit=crop&q=80",
  laptop: "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=1200&h=800&fit=crop&q=80",
  dashboard: "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&h=800&fit=crop&q=80",
  analytics: "https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=1200&h=800&fit=crop&q=80",
};
```

#### 사람/팀
```typescript
const PEOPLE_IMAGES = {
  professionalWoman: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&h=400&fit=crop&q=80",
  professionalMan: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&q=80",
  diverseTeam: "https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=1200&h=800&fit=crop&q=80",
  celebration: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=1200&h=800&fit=crop&q=80",
};
```

#### 추상/배경
```typescript
const ABSTRACT_IMAGES = {
  gradient: "https://images.unsplash.com/photo-1557682250-33bd709cbe85?w=1920&h=1080&fit=crop&q=80",
  geometric: "https://images.unsplash.com/photo-1558591710-4b4a1ae0f04d?w=1920&h=1080&fit=crop&q=80",
  minimal: "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1920&h=1080&fit=crop&q=80",
  tech: "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1920&h=1080&fit=crop&q=80",
};
```

---

## AI 이미지 생성 프롬프트

### 일러스트레이션 스타일
```yaml
SaaS Dashboard 일러스트:
  prompt: |
    Flat design illustration of a modern dashboard interface,
    showing charts and graphs, pastel colors (blue, purple, mint),
    clean lines, isometric perspective, white background,
    professional business style, vector art quality

팀 협업 일러스트:
  prompt: |
    Minimalist illustration of diverse team members collaborating,
    abstract human figures, geometric shapes, gradient colors,
    modern corporate style, no faces detailed, clean composition

성장/성공 일러스트:
  prompt: |
    Abstract illustration representing growth and success,
    upward trending arrow, geometric patterns,
    colors: blue (#3B82F6), green (#10B981), purple (#8B5CF6),
    clean minimal style, suitable for SaaS landing page
```

### 아이콘/로고 스타일
```yaml
앱 아이콘:
  prompt: |
    Modern app icon design, simple geometric shape,
    gradient from blue to purple, rounded corners,
    single memorable symbol, iOS style,
    clean minimal, high contrast

기능 아이콘 세트:
  prompt: |
    Set of 6 line icons for SaaS application,
    consistent 2px stroke weight, rounded caps,
    representing: analytics, team, feedback, goals, reports, settings,
    monochrome, scalable vector style
```

---

## 플레이스홀더 전략

### 개발용 플레이스홀더
```typescript
// 크기별 플레이스홀더
const PLACEHOLDER = {
  avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=",
  thumbnail: "https://placehold.co/400x300/e2e8f0/64748b?text=",
  hero: "https://placehold.co/1920x1080/e2e8f0/64748b?text=",
  card: "https://placehold.co/600x400/e2e8f0/64748b?text=",
};

// 사용 예시
<img src={`${PLACEHOLDER.avatar}${userId}`} alt="User Avatar" />
<img src={`${PLACEHOLDER.card}Loading...`} alt="Card placeholder" />
```

### 로딩 상태 (Skeleton)
```tsx
// shadcn/ui Skeleton 활용
import { Skeleton } from "@/components/ui/skeleton"

// 이미지 로딩 상태
<Skeleton className="w-full h-48 rounded-lg" />

// 아바타 로딩 상태
<Skeleton className="w-10 h-10 rounded-full" />
```

---

## 이미지 최적화 규칙

### Next.js Image 컴포넌트 필수
```tsx
// ✅ 올바른 사용
import Image from "next/image"

<Image
  src="https://images.unsplash.com/photo-xxx"
  alt="설명적인 대체 텍스트"
  width={1200}
  height={800}
  className="rounded-lg"
  priority={isAboveFold}  // LCP 이미지는 priority 추가
/>

// ❌ 잘못된 사용 (일반 img 태그)
<img src="..." alt="..." />
```

### next.config.js 이미지 도메인 설정
```javascript
// next.config.js
module.exports = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
      },
      {
        protocol: 'https',
        hostname: 'api.dicebear.com',
      },
      {
        protocol: 'https',
        hostname: 'placehold.co',
      },
    ],
  },
}
```

---

## 이미지 사용 체크리스트

- [ ] **Next.js Image 컴포넌트** 사용 (일반 img 금지)
- [ ] **alt 텍스트** 의미 있게 작성 (접근성)
- [ ] **적절한 크기** 지정 (w, h 파라미터)
- [ ] **LCP 이미지**에 `priority` 속성 추가
- [ ] **Skeleton** 로딩 상태 제공
- [ ] **remotePatterns** 설정 확인

---

**버전**: 1.0.0
**작성일**: 2025-12-01
