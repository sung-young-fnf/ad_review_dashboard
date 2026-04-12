# Design Tokens (상세)

> **상위 문서**: @.claude/guides/UI_DESIGN_SYSTEM.md
> **용도**: shadcn/ui CSS Variables 상세 참조

---

## 색상 시스템 (Color System)

### 기본 구조 (Background/Foreground Convention)

```typescript
// tailwind.config.ts (프로젝트 설정)
export default {
  theme: {
    extend: {
      colors: {
        background: 'hsl(var(--background))',      // 페이지 배경색
        foreground: 'hsl(var(--foreground))',      // 기본 텍스트 색
        primary: {
          DEFAULT: 'hsl(var(--primary))',          // 주요 액션
          foreground: 'hsl(var(--primary-foreground))'
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary))',        // 보조 요소
          foreground: 'hsl(var(--secondary-foreground))'
        },
        muted: {
          DEFAULT: 'hsl(var(--muted))',            // 비활성/배경
          foreground: 'hsl(var(--muted-foreground))'
        },
        accent: {
          DEFAULT: 'hsl(var(--accent))',           // 강조
          foreground: 'hsl(var(--accent-foreground))'
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',      // 위험/삭제
          foreground: 'hsl(var(--destructive-foreground))'
        },
        border: 'hsl(var(--border))',              // 테두리
        input: 'hsl(var(--input))',                // 입력 필드 테두리
        ring: 'hsl(var(--ring))'                   // 포커스 링
      }
    }
  }
}
```

### CSS Variables 정의 (globals.css)

```css
/* Light Mode */
:root {
  --background: 0 0% 100%;          /* hsl(0, 0%, 100%) = #FFFFFF */
  --foreground: 222.2 47.4% 11.2%;  /* 진한 텍스트 */

  --primary: 222.2 47.4% 11.2%;
  --primary-foreground: 210 40% 98%;

  --secondary: 210 40% 96.1%;
  --secondary-foreground: 222.2 47.4% 11.2%;

  --muted: 210 40% 96.1%;
  --muted-foreground: 215.4 16.3% 46.9%;

  --accent: 210 40% 96.1%;
  --accent-foreground: 222.2 47.4% 11.2%;

  --destructive: 0 100% 50%;        /* 빨강 */
  --destructive-foreground: 210 40% 98%;

  --border: 214.3 31.8% 91.4%;
  --input: 214.3 31.8% 91.4%;
  --ring: 222.2 47.4% 11.2%;

  --radius: 0.5rem;                 /* 8px */
}

/* Dark Mode */
.dark {
  --background: 224 71% 4%;
  --foreground: 213 31% 91%;

  --primary: 210 40% 98%;
  --primary-foreground: 222.2 47.4% 1.2%;

  --secondary: 222.2 47.4% 11.2%;
  --secondary-foreground: 210 40% 98%;

  --muted: 223 47% 11%;
  --muted-foreground: 215.4 16.3% 56.9%;

  --accent: 216 34% 17%;
  --accent-foreground: 210 40% 98%;

  --destructive: 0 63% 31%;
  --destructive-foreground: 210 40% 98%;

  --border: 216 34% 17%;
  --input: 216 34% 17%;
  --ring: 216 34% 17%;
}
```

### 사용 예시

```tsx
// ✅ shadcn/ui 권장 패턴
<div className="bg-primary text-primary-foreground">
  주요 액션 버튼
</div>

<div className="bg-muted text-muted-foreground">
  비활성 상태
</div>

// ❌ 하드코딩 금지
<div className="bg-blue-500 text-white">잘못된 예</div>
```

---

## 커스텀 색상 추가 (OKLCH 권장)

### OKLCH 색상 공간 (Tailwind v4+)

```css
/* globals.css */
:root {
  --warning: oklch(0.84 0.16 84);          /* 밝은 노랑 */
  --warning-foreground: oklch(0.28 0.07 46);

  --success: oklch(0.70 0.20 150);         /* 녹색 */
  --success-foreground: oklch(0.99 0.02 95);
}

.dark {
  --warning: oklch(0.41 0.11 46);
  --warning-foreground: oklch(0.99 0.02 95);

  --success: oklch(0.50 0.18 150);
  --success-foreground: oklch(0.99 0.02 95);
}

/* Tailwind v4 inline directive */
@theme inline {
  --color-warning: var(--warning);
  --color-warning-foreground: var(--warning-foreground);
  --color-success: var(--success);
  --color-success-foreground: var(--success-foreground);
}
```

### tailwind.config.ts 확장

```typescript
export default {
  theme: {
    extend: {
      colors: {
        // 기존 색상...
        warning: {
          DEFAULT: 'hsl(var(--warning))',
          foreground: 'hsl(var(--warning-foreground))'
        },
        success: {
          DEFAULT: 'hsl(var(--success))',
          foreground: 'hsl(var(--success-foreground))'
        }
      }
    }
  }
}
```

---

## Border Radius (프로젝트 기본값)

```typescript
// tailwind.config.ts
borderRadius: {
  lg: 'var(--radius)',              // 8px
  md: 'calc(var(--radius) - 2px)',  // 6px
  sm: 'calc(var(--radius) - 4px)'   // 4px
}
```

```css
:root {
  --radius: 0.5rem;  /* 8px - 프로젝트 기본값 */
}
```

---

**버전**: 1.0.0
**작성일**: 2025-12-01
