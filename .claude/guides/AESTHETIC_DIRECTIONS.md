# Aesthetic Directions Guide (shadcn/ui 내 적용)

> **프로젝트**: okr2 (autumn_template)
> **기반**: Anthropic Skills frontend-design + shadcn/ui 시스템
> **목적**: "제네릭 AI 미학" 회피, 차별화된 UI 생성

---

## 🎯 개요

### 핵심 철학

> "Create **distinctive**, production-grade frontend interfaces with **high design quality**. Avoid generic AI aesthetics."

**목표**:
- ❌ 평범한 AI 생성 UI (Arial 폰트, 보라색 그래디언트)
- ✅ 기억에 남는 독특한 디자인 (Visually striking and memorable)
- ✅ shadcn/ui 시스템 내에서 차별화 (안정성 + 창의성)

### 4가지 미학 방향

```yaml
1. Minimalism-Tech (기본, 80% 케이스)
   - 사용 시기: Admin Dashboard, SaaS 제품, 데이터 중심 UI
   - 특징: 극도의 공간, 타이포그래피 중심, Monochrome

2. Luxury-Professional (럭셔리 브랜드)
   - 사용 시기: 고급 패션, 부동산, 프리미엄 서비스
   - 특징: Serif 폰트, Gold Accent, 넓은 여백

3. Brutalism-Bold (강렬한 인상)
   - 사용 시기: 스타트업, 크리에이티브 에이전시, 개인 포트폴리오
   - 특징: System 폰트, Neon Accent, 타이트한 간격

4. Retro-Futurism (독특한 브랜드)
   - 사용 시기: 게임, 엔터테인먼트, Y2K 브랜드
   - 특징: Retro 폰트, Electric Blue, 비대칭 레이아웃
```

---

## 🎨 1. Minimalism-Tech (기본, 80% 케이스)

### 1.1 사용 시기

**적합한 프로젝트**:
- Admin Dashboard
- SaaS 제품
- 데이터 중심 UI
- B2B 플랫폼

**Purpose & Tone**:
- Purpose: 효율성, 명확성, 데이터 가시성
- Tone: 전문적, 신뢰감, 미니멀

### 1.2 디자인 특징

```yaml
Typography:
  - Heading: Inter (기존 유지), font-bold, text-2xl~4xl
  - Body: Inter, font-normal, text-sm~base
  - 특징: 굵은 Heading으로 계층 구조 명확화

Color:
  - Dominant: Monochrome (bg-background, text-foreground)
  - Accent: Single Bold Color (--primary)
  - 원칙: 60% 배경, 30% 텍스트, 10% 악센트

Motion:
  - Subtle: translate-y-[-2px], duration-200
  - Hover: opacity-80, shadow-sm
  - 원칙: 부드럽고 눈에 띄지 않는 전환

Spacing:
  - 일반: space-y-4, px-6, py-4
  - 여백: 충분하지만 과하지 않음 (8px 단위)
```

### 1.3 코드 예시

#### Button (Minimalism-Tech)

```tsx
import { Button } from "@/components/ui/button"

// 기본 버튼 (shadcn/ui 그대로)
<Button variant="default" size="default">
  Save Changes
</Button>

// Accent 버튼 (Primary)
<Button variant="default" className="bg-primary text-primary-foreground">
  Create New
</Button>

// Ghost 버튼 (Subtle)
<Button variant="ghost" className="hover:bg-accent/10">
  Cancel
</Button>
```

#### Card (Minimalism-Tech)

```tsx
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"

export function MinimalCard() {
  return (
    <Card className="border shadow-sm hover:shadow-md transition-shadow duration-200">
      <CardHeader className="space-y-2">
        <CardTitle className="text-2xl font-bold text-foreground">
          Dashboard Overview
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <p className="text-muted-foreground text-sm">
          Clear and concise content with minimal styling.
        </p>
        <Button variant="default" size="sm">
          View Details
        </Button>
      </CardContent>
    </Card>
  )
}
```

#### Layout (Grid)

```tsx
// 데이터 대시보드 레이아웃
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 p-6">
  <Card>...</Card>
  <Card>...</Card>
  <Card>...</Card>
</div>
```

### 1.4 CSS Variables (기본값 유지)

```css
/* globals.css - Minimalism-Tech는 기본값 사용 */
:root {
  --background: 0 0% 100%;
  --foreground: 222.2 47.4% 11.2%;
  --primary: 222.2 47.4% 11.2%;
  --primary-foreground: 210 40% 98%;
}
```

---

## 💎 2. Luxury-Professional (럭셔리 브랜드)

### 2.1 사용 시기

**적합한 프로젝트**:
- 고급 패션 브랜드
- 부동산 플랫폼
- 프리미엄 서비스
- 럭셔리 이커머스

**Purpose & Tone**:
- Purpose: 신뢰감, 품격, 프리미엄 경험
- Tone: 우아함, 세련됨, 럭셔리

### 2.2 디자인 특징

```yaml
Typography:
  - Heading: Playfair Display (Serif), font-bold, text-3xl~5xl
  - Body: Inter (기존), font-normal, text-base
  - 특징: Serif Heading으로 고급스러움 강조

Color:
  - Dominant: Soft Neutral (bg-background, text-foreground)
  - Accent: Gold (#D4AF37 → Darker #B8860B for Accessibility)
  - Secondary: Deep Navy (#1A1A2E)

Motion:
  - Smooth: ease-in-out, duration-300
  - Hover: shadow-lg, transform subtle
  - 원칙: 부드럽고 우아한 전환

Spacing:
  - 넓은 여백: space-y-8, px-12, py-8
  - 원칙: 충분한 공간으로 여유로움 표현
```

### 2.3 Setup (Luxury-Professional)

#### Google Fonts 추가

```tsx
// app/layout.tsx
import { Playfair_Display } from 'next/font/google'

const playfair = Playfair_Display({
  subsets: ['latin'],
  weight: ['700'],
  variable: '--font-serif',
})

export default function RootLayout({ children }) {
  return (
    <html lang="ko" className={playfair.variable}>
      <body>{children}</body>
    </html>
  )
}
```

#### CSS Variables 확장

```css
/* globals.css */
:root {
  /* 기존 Variables 유지 */
  --background: 0 0% 100%;
  --foreground: 222.2 47.4% 11.2%;

  /* Luxury-Professional: Gold Accent (Darker for Accessibility) */
  --accent: 43 74% 36%;  /* #B8860B (Dark Goldenrod) - Contrast 4.6:1 ✅ */
  --accent-foreground: 0 0% 100%;  /* White text on Gold */

  /* Secondary: Deep Navy */
  --luxury-navy: 240 32% 12%;  /* #1A1A2E */
}

.dark {
  --accent: 45 90% 61%;  /* #E5C76B (Lighter Gold for Dark Mode) */
  --accent-foreground: 240 32% 12%;  /* Dark Navy text on Gold */
}
```

#### Tailwind Config 확장

```typescript
// tailwind.config.ts
export default {
  theme: {
    extend: {
      fontFamily: {
        serif: ['var(--font-serif)'],  // Playfair Display
      },
      colors: {
        'luxury-navy': 'hsl(var(--luxury-navy))',
      }
    }
  }
}
```

### 2.4 코드 예시

#### Button (Luxury-Professional)

```tsx
import { Button } from "@/components/ui/button"

// Gold Accent 버튼
<Button className="bg-accent text-accent-foreground hover:bg-accent/90 shadow-lg">
  Explore Collection
</Button>

// Outline 버튼 (Navy)
<Button variant="outline" className="border-luxury-navy text-luxury-navy hover:bg-luxury-navy hover:text-white">
  Learn More
</Button>
```

#### Card (Luxury-Professional)

```tsx
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"

export function LuxuryCard() {
  return (
    <Card className="border-accent/20 shadow-lg hover:shadow-xl transition-all duration-300">
      <CardHeader className="space-y-4 pb-8">
        {/* Serif Font for Heading */}
        <CardTitle className="font-serif text-3xl font-bold text-foreground">
          Premium Service
        </CardTitle>
        <div className="h-0.5 w-12 bg-accent" />
      </CardHeader>
      <CardContent className="space-y-6 px-8 pb-8">
        <p className="text-muted-foreground leading-relaxed text-base">
          Experience unparalleled quality and sophistication with our
          curated selection of premium offerings.
        </p>
        <Button className="bg-accent text-accent-foreground hover:bg-accent/90 shadow-md">
          Get Started
        </Button>
      </CardContent>
    </Card>
  )
}
```

#### Hero Section (Luxury-Professional)

```tsx
export function LuxuryHero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center px-12 py-24">
      <div className="max-w-4xl mx-auto text-center space-y-8">
        {/* Serif Heading */}
        <h1 className="font-serif text-5xl md:text-7xl font-bold text-foreground leading-tight">
          Elevate Your Experience
        </h1>

        {/* Accent Line */}
        <div className="flex justify-center">
          <div className="h-0.5 w-24 bg-accent" />
        </div>

        {/* Body Text */}
        <p className="text-xl text-muted-foreground leading-relaxed max-w-2xl mx-auto">
          Discover a world of refined elegance and timeless sophistication.
        </p>

        {/* CTA Buttons */}
        <div className="flex flex-col sm:flex-row gap-4 justify-center items-center pt-4">
          <Button className="bg-accent text-accent-foreground hover:bg-accent/90 shadow-lg px-8 py-6 text-lg">
            Explore Collection
          </Button>
          <Button variant="outline" className="border-luxury-navy text-luxury-navy hover:bg-luxury-navy hover:text-white px-8 py-6 text-lg">
            Learn More
          </Button>
        </div>
      </div>
    </section>
  )
}
```

---

## ⚡ 3. Brutalism-Bold (강렬한 인상)

### 3.1 사용 시기

**적합한 프로젝트**:
- 스타트업 (대담한 브랜드)
- 크리에이티브 에이전시
- 개인 포트폴리오
- 실험적 프로젝트

**Purpose & Tone**:
- Purpose: 인상적, 기억에 남음, 독창적
- Tone: 대담함, 날것, 실험적

### 3.2 디자인 특징

```yaml
Typography:
  - Heading: system-ui (Courier New, monospace), uppercase
  - Body: system-ui, font-normal
  - 특징: Raw한 시스템 폰트, 대문자 강조

Color:
  - Dominant: Pure Black & White (최대 대비)
  - Accent: Neon Green (#00FF41) - Contrast 13.7:1 ✅
  - 원칙: 극단적 대비, 강렬한 악센트

Motion:
  - Sharp: duration-100, scale-105
  - Hover: transform-bold, no-smooth
  - 원칙: 빠르고 날카로운 전환

Spacing:
  - 타이트: space-y-2, px-4, py-2
  - 원칙: 미니멀한 간격, 밀집된 레이아웃
```

### 3.3 Setup (Brutalism-Bold)

#### CSS Variables 확장

```css
/* globals.css */
:root {
  /* Brutalism-Bold: Pure Black & White */
  --background: 0 0% 100%;  /* Pure White */
  --foreground: 0 0% 0%;    /* Pure Black */

  /* Neon Accent */
  --accent: 130 100% 50%;  /* #00FF41 (Neon Green) - Contrast 13.7:1 ✅ */
  --accent-foreground: 0 0% 0%;  /* Black text on Neon */

  /* Border */
  --border: 0 0% 0%;  /* Pure Black Border */
}

.dark {
  --background: 0 0% 0%;    /* Pure Black */
  --foreground: 0 0% 100%;  /* Pure White */
  --accent: 130 100% 50%;   /* Neon Green (same) */
  --accent-foreground: 0 0% 0%;
}
```

#### Tailwind Config 확장

```typescript
// tailwind.config.ts
export default {
  theme: {
    extend: {
      fontFamily: {
        'mono-brutal': ['Courier New', 'monospace'],
      }
    }
  }
}
```

### 3.4 코드 예시

#### Button (Brutalism-Bold)

```tsx
import { Button } from "@/components/ui/button"

// Neon Accent 버튼
<Button className="bg-accent text-accent-foreground font-mono-brutal uppercase border-2 border-accent hover:scale-105 transition-transform duration-100 shadow-none">
  CLICK
</Button>

// Black Border 버튼
<Button variant="outline" className="border-2 border-foreground text-foreground font-mono-brutal uppercase hover:bg-foreground hover:text-background transition-all duration-100">
  SUBMIT
</Button>
```

#### Card (Brutalism-Bold)

```tsx
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"

export function BrutalCard() {
  return (
    <Card className="border-2 border-foreground shadow-none rounded-none">
      <CardHeader className="space-y-2 border-b-2 border-foreground">
        <CardTitle className="font-mono-brutal text-xl uppercase text-foreground">
          BOLD STATEMENT
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 px-4 py-4">
        <p className="font-mono-brutal text-sm text-foreground">
          Raw, unpolished, and unapologetically direct.
        </p>
        <Button className="bg-accent text-accent-foreground font-mono-brutal uppercase border-2 border-accent hover:scale-105 transition-transform duration-100">
          ACTION
        </Button>
      </CardContent>
    </Card>
  )
}
```

#### Hero Section (Brutalism-Bold)

```tsx
export function BrutalHero() {
  return (
    <section className="min-h-screen flex items-center justify-center bg-background px-4 py-12">
      <div className="max-w-4xl w-full border-4 border-foreground p-8 space-y-4">
        {/* Monospace Uppercase Heading */}
        <h1 className="font-mono-brutal text-4xl md:text-6xl uppercase text-foreground leading-tight">
          MAKE IT BOLD
        </h1>

        {/* Neon Accent Line */}
        <div className="h-1 w-full bg-accent" />

        {/* Body Text */}
        <p className="font-mono-brutal text-base text-foreground">
          No compromises. No subtlety. Just pure impact.
        </p>

        {/* CTA */}
        <div className="flex gap-4 pt-4">
          <Button className="bg-accent text-accent-foreground font-mono-brutal uppercase border-2 border-accent hover:scale-105 transition-transform duration-100">
            START NOW
          </Button>
          <Button variant="outline" className="border-2 border-foreground text-foreground font-mono-brutal uppercase hover:bg-foreground hover:text-background">
            LEARN MORE
          </Button>
        </div>
      </div>
    </section>
  )
}
```

---

## 🚀 4. Retro-Futurism (독특한 브랜드)

### 4.1 사용 시기

**적합한 프로젝트**:
- 게임 (Y2K, 80년대 테마)
- 엔터테인먼트
- 독특한 브랜드
- 노스탤지어 마케팅

**Purpose & Tone**:
- Purpose: 독창성, 노스탤지어, 미래상
- Tone: 재미, 에너지, 복고

### 4.2 디자인 특징

```yaml
Typography:
  - Heading: Orbitron (Retro Sci-Fi), font-bold
  - Body: Inter (기존, 가독성 유지)
  - 특징: Retro Font로 강렬한 인상

Color:
  - Dominant: Dark Background (#0A0A0A)
  - Accent: Electric Blue (#00D9FF) + Hot Pink (#FF006E)
  - 원칙: Neon 색상, Glow 효과

Motion:
  - Glitch: keyframe animations
  - Neon Glow: shadow effects
  - 원칙: 실험적, 눈에 띄는 전환

Spacing:
  - 비대칭: asymmetric grid, diagonal elements
  - 원칙: 예상 밖의 레이아웃
```

### 4.3 Setup (Retro-Futurism)

#### Google Fonts 추가

```tsx
// app/layout.tsx
import { Orbitron } from 'next/font/google'

const orbitron = Orbitron({
  subsets: ['latin'],
  weight: ['700'],
  variable: '--font-retro',
})

export default function RootLayout({ children }) {
  return (
    <html lang="ko" className={orbitron.variable}>
      <body>{children}</body>
    </html>
  )
}
```

#### CSS Variables 확장

```css
/* globals.css */
:root {
  /* Retro-Futurism: Dark Background */
  --background: 240 6% 4%;  /* #0A0A0A (Very Dark) */
  --foreground: 0 0% 100%;  /* White */

  /* Electric Blue Accent */
  --accent: 190 100% 50%;  /* #00D9FF (Electric Blue) */
  --accent-foreground: 240 6% 4%;  /* Dark background on Blue */

  /* Hot Pink Secondary */
  --retro-pink: 334 100% 51%;  /* #FF006E */
}

/* Neon Glow Utility */
.neon-glow {
  text-shadow: 0 0 10px currentColor, 0 0 20px currentColor;
}

.neon-glow-box {
  box-shadow: 0 0 20px hsl(var(--accent)), 0 0 40px hsl(var(--accent));
}
```

#### Tailwind Config 확장

```typescript
// tailwind.config.ts
export default {
  theme: {
    extend: {
      fontFamily: {
        retro: ['var(--font-retro)'],
      },
      colors: {
        'retro-pink': 'hsl(var(--retro-pink))',
      }
    }
  }
}
```

### 4.4 코드 예시

#### Button (Retro-Futurism)

```tsx
import { Button } from "@/components/ui/button"

// Electric Blue 버튼 (Neon Glow)
<Button className="bg-accent text-accent-foreground font-retro uppercase neon-glow-box hover:scale-105 transition-transform duration-200">
  ENTER
</Button>

// Hot Pink 버튼
<Button className="bg-retro-pink text-white font-retro uppercase shadow-[0_0_20px_#FF006E] hover:shadow-[0_0_40px_#FF006E]">
  PLAY
</Button>
```

#### Card (Retro-Futurism)

```tsx
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"

export function RetroCard() {
  return (
    <Card className="border-accent neon-glow-box bg-background/50 backdrop-blur">
      <CardHeader className="border-b border-accent/50">
        <CardTitle className="font-retro text-2xl text-accent neon-glow">
          CYBER TITLE
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4 pt-6">
        <p className="text-foreground/80 text-sm">
          Experience the future of yesterday, reimagined for today.
        </p>
        <div className="flex gap-4">
          <Button className="bg-accent text-accent-foreground font-retro uppercase neon-glow-box">
            ENTER
          </Button>
          <Button variant="outline" className="border-retro-pink text-retro-pink font-retro uppercase hover:bg-retro-pink hover:text-white">
            EXPLORE
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
```

#### Hero Section (Retro-Futurism)

```tsx
export function RetroHero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center bg-background px-6 py-12 overflow-hidden">
      {/* Diagonal Background Element */}
      <div className="absolute inset-0 bg-gradient-to-br from-accent/10 to-retro-pink/10 transform -skew-y-6" />

      <div className="relative z-10 max-w-4xl mx-auto text-center space-y-8">
        {/* Retro Heading with Neon Glow */}
        <h1 className="font-retro text-5xl md:text-7xl text-accent neon-glow uppercase leading-tight">
          WELCOME TO THE FUTURE
        </h1>

        {/* Accent Lines */}
        <div className="flex justify-center gap-4">
          <div className="h-1 w-24 bg-accent neon-glow-box" />
          <div className="h-1 w-24 bg-retro-pink shadow-[0_0_10px_#FF006E]" />
        </div>

        {/* Body Text */}
        <p className="text-xl text-foreground/80 max-w-2xl mx-auto">
          Step into a world where nostalgia meets innovation. The future is retro.
        </p>

        {/* CTA Buttons */}
        <div className="flex flex-col sm:flex-row gap-4 justify-center items-center pt-6">
          <Button className="bg-accent text-accent-foreground font-retro uppercase neon-glow-box hover:scale-105 transition-transform px-8 py-6 text-lg">
            START GAME
          </Button>
          <Button className="bg-retro-pink text-white font-retro uppercase shadow-[0_0_20px_#FF006E] hover:shadow-[0_0_40px_#FF006E] px-8 py-6 text-lg">
            EXPLORE
          </Button>
        </div>
      </div>

      {/* Decorative Elements */}
      <div className="absolute top-1/4 left-10 w-32 h-32 border-2 border-accent/30 rotate-45" />
      <div className="absolute bottom-1/4 right-10 w-24 h-24 border-2 border-retro-pink/30 rotate-12" />
    </section>
  )
}
```

---

## 🎯 선택 가이드라인

### 질문 체크리스트

**Step 1: Purpose (목적)**
```yaml
질문:
  - What is this interface meant to accomplish?
  - Who is the target audience?

선택 가이드:
  - 효율성, 데이터 중심 → Minimalism-Tech
  - 신뢰감, 프리미엄 → Luxury-Professional
  - 인상적, 독창적 → Brutalism-Bold
  - 재미, 노스탤지어 → Retro-Futurism
```

**Step 2: Tone (톤)**
```yaml
질문:
  - What emotional response should this evoke?
  - Professional? Playful? Luxurious? Edgy?

선택 가이드:
  - 전문적, 신뢰감 → Minimalism-Tech
  - 우아함, 세련됨 → Luxury-Professional
  - 대담함, 실험적 → Brutalism-Bold
  - 에너지, 재미 → Retro-Futurism
```

**Step 3: Constraints (제약)**
```yaml
고려 사항:
  - Technical: shadcn/ui 컴포넌트 재사용 필수
  - Brand: 기존 CSS Variables 유지 (확장 가능)
  - Accessibility: WCAG 2.1 AA 준수 필수 (Color Contrast 4.5:1)
  - Performance: 60fps 유지 (transform, opacity만)
```

### 의사결정 트리

```
타겟 사용자는?
├─ B2B 비즈니스 → Minimalism-Tech (80% 케이스)
├─ 럭셔리 고객 → Luxury-Professional
├─ 크리에이티브 업계 → Brutalism-Bold
└─ 젊은 세대 (Gen Z) → Retro-Futurism

브랜드 톤은?
├─ 전문적, 효율적 → Minimalism-Tech
├─ 우아함, 품격 → Luxury-Professional
├─ 대담함, 날것 → Brutalism-Bold
└─ 재미, 노스탤지어 → Retro-Futurism

목적은?
├─ 데이터 분석, 작업 효율 → Minimalism-Tech
├─ 신뢰 구축, 프리미엄 경험 → Luxury-Professional
├─ 강렬한 인상, 기억에 남음 → Brutalism-Bold
└─ 엔터테인먼트, 독창성 → Retro-Futurism
```

---

## ✅ 기본 원칙

### 필수 규칙 (모든 방향 공통)

```yaml
1. shadcn/ui 컴포넌트 재사용 필수
   - ✅ Button, Card, Input 등 기존 컴포넌트 활용
   - ❌ 직접 구현 금지 (일관성 유지)

2. CSS Variables 사용 (Design Tokens)
   - ✅ --accent, --primary, --foreground 등 활용
   - ❌ 하드코딩 색상 금지 (bg-blue-500)

3. Accessibility 절대 타협 불가
   - ✅ WCAG 2.1 AA 준수 (Color Contrast 4.5:1)
   - ✅ Keyboard Navigation, ARIA labels
   - ❌ 미학 vs Accessibility 트레이드오프 금지

4. prefers-reduced-motion 지원
   - ✅ 모든 애니메이션에 조건부 적용
   - ❌ 강제 애니메이션 금지

5. Radix UI primitives 유지
   - ✅ 접근성 자동 보장 (Dialog, Dropdown)
   - ❌ ARIA 속성 제거 금지
```

### 권장 사항

```yaml
의심스러우면 Minimalism-Tech (안전):
  - 80% 케이스에 적합
  - 검증된 패턴
  - 낮은 위험도

브랜드 가이드라인 우선:
  - 기존 브랜드 색상 → CSS Variables 재정의
  - 브랜드 폰트 → Google Fonts 추가

점진적 적용:
  - Phase 1: Minimalism-Tech 기본 적용
  - Phase 2: 특정 페이지에 Luxury/Brutalism 실험
  - Phase 3: 성공 사례 확장
```

---

## 🚨 자주 발생하는 실수

### 1. ❌ Accessibility 위반

```tsx
// ❌ 잘못된 예: Color Contrast 부족
// Gold (#D4AF37) on White → 3.2:1 (WCAG AA 실패)
<div className="bg-white text-[#D4AF37]">Text</div>

// ✅ 올바른 예: Darker Gold 사용
// Dark Goldenrod (#B8860B) on White → 4.6:1 (WCAG AA 통과)
:root {
  --accent: 43 74% 36%;  /* #B8860B */
}
<div className="bg-white text-accent">Text</div>
```

### 2. ❌ shadcn/ui 컴포넌트 무시

```tsx
// ❌ 잘못된 예: 직접 구현
<button className="px-4 py-2 bg-accent text-white rounded">
  Click
</button>

// ✅ 올바른 예: shadcn/ui Button 재사용
import { Button } from "@/components/ui/button"
<Button className="bg-accent text-accent-foreground">
  Click
</Button>
```

### 3. ❌ prefers-reduced-motion 미지원

```tsx
// ❌ 잘못된 예: 강제 애니메이션
<div className="animate-pulse">Content</div>

// ✅ 올바른 예: 조건부 애니메이션
<div className="motion-safe:animate-pulse">Content</div>
```

### 4. ❌ 하드코딩 색상

```tsx
// ❌ 잘못된 예
<div className="bg-[#00FF41] text-black">Neon</div>

// ✅ 올바른 예: CSS Variables
:root {
  --accent: 130 100% 50%;  /* #00FF41 */
}
<div className="bg-accent text-accent-foreground">Neon</div>
```

---

## 📚 참조

- **Anthropic Skills frontend-design**: https://github.com/anthropics/skills/tree/main/frontend-design
- **shadcn/ui 공식 문서**: https://ui.shadcn.com/docs
- **WCAG 2.1 가이드라인**: https://www.w3.org/WAI/WCAG21/quickref/
- **Google Fonts**: https://fonts.google.com/
- **프로젝트 UI Design System**: @docs/guides/ui-design-system.md
- **Accessibility Guidelines**: @docs/guides/accessibility-guidelines.md

---

**버전**: 1.0.0
**작성일**: 2025-11-18
**기반**: Anthropic Skills frontend-design + shadcn/ui
**유지보수**: UI/UX 팀
