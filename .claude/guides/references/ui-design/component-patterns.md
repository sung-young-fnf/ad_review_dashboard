# Component Patterns (상세)

> **상위 문서**: @.claude/guides/UI_DESIGN_SYSTEM.md
> **용도**: shadcn/ui 컴포넌트 패턴 상세 가이드

---

## 버튼 컴포넌트 (CVA 패턴)

### 기존 컴포넌트 (components/ui/button.tsx)

```tsx
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const buttonVariants = cva(
  // Base 스타일
  "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline"
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10"
      }
    },
    defaultVariants: {
      variant: "default",
      size: "default"
    }
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export const Button = ({ className, variant, size, ...props }: ButtonProps) => {
  return (
    <button
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}
```

### 사용 예시

```tsx
// ✅ Variant 활용
<Button variant="default">기본 버튼</Button>
<Button variant="destructive">삭제</Button>
<Button variant="outline" size="sm">작은 버튼</Button>
<Button variant="ghost">투명 버튼</Button>

// ❌ 직접 스타일링 금지
<button className="bg-blue-500 text-white px-4 py-2">잘못된 예</button>
```

---

## 입력 컴포넌트 (Radix UI 통합)

### 기존 컴포넌트 (components/ui/input.tsx)

```tsx
import { cn } from "@/lib/utils"

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {}

export const Input = ({ className, type, ...props }: InputProps) => {
  return (
    <input
      type={type}
      className={cn(
        "flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
}
```

---

## 카드 컴포넌트 (Composition 패턴)

### 기존 컴포넌트 (components/ui/card.tsx)

```tsx
import { cn } from "@/lib/utils"

const Card = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div
    className={cn(
      "rounded-lg border bg-card text-card-foreground shadow-sm",
      className
    )}
    {...props}
  />
)

const CardHeader = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("flex flex-col space-y-1.5 p-6", className)} {...props} />
)

const CardTitle = ({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) => (
  <h3 className={cn("text-2xl font-semibold leading-none tracking-tight", className)} {...props} />
)

const CardContent = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("p-6 pt-0", className)} {...props} />
)

export { Card, CardHeader, CardTitle, CardContent }
```

### 사용 예시 (Composition)

```tsx
// ✅ shadcn/ui Composition 패턴
<Card>
  <CardHeader>
    <CardTitle>카드 제목</CardTitle>
  </CardHeader>
  <CardContent>
    <p>카드 내용</p>
  </CardContent>
</Card>
```

---

## Utility 함수 (`cn`)

### Class Merge (clsx + tailwind-merge)

```typescript
// lib/utils.ts
import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

### 사용 예시

```tsx
// ✅ 조건부 스타일링 + Tailwind 충돌 방지
<div className={cn(
  "bg-primary text-primary-foreground",
  isActive && "bg-accent text-accent-foreground",
  className  // 외부에서 전달된 className 병합
)}>
  내용
</div>
```

---

## Animation (프로젝트 커스텀)

### 기존 애니메이션 (tailwind.config.ts)

```typescript
keyframes: {
  'accordion-down': {
    from: { height: '0' },
    to: { height: 'var(--radix-accordion-content-height)' }
  },
  fadeIn: {
    '0%': { opacity: '0' },
    '100%': { opacity: '1' }
  },
  slideUp: {
    '0%': { transform: 'translateY(20px)', opacity: '0' },
    '100%': { transform: 'translateY(0)', opacity: '1' }
  }
},
animation: {
  'accordion-down': 'accordion-down 0.2s ease-out',
  'fade-in': 'fadeIn 0.2s ease-out',
  'slide-up': 'slideUp 0.3s ease-out'
}
```

### 사용 예시

```tsx
<div className="animate-fade-in">페이드인 효과</div>
<div className="animate-slide-up">슬라이드 업 효과</div>
```

---

**버전**: 1.0.0
**작성일**: 2025-12-01
