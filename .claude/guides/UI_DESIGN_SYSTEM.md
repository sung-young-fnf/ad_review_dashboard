# UI Design System (shadcn/ui 기반)

<!--
metadata:
  name: ui-design-system
  version: 3.0.0
  category: frontend
  when_to_use:
    - UI 컴포넌트 구현 시
    - 스타일링 결정 시
    - 폰트/이미지 선택 시
    - shadcn/ui 패턴 확인 시
  keywords: [ui, design, shadcn, tailwind, typography, image, component]
  context_cost: ~5KB (핵심), ~20KB (상세 포함)
  references:
    - ./references/ui-design/typography-catalog.md
    - ./references/ui-design/image-strategy.md
    - ./references/ui-design/design-tokens.md
    - ./references/ui-design/component-patterns.md
-->

> **프로젝트**: okr2 (Spark Note)
> **기술 스택**: shadcn/ui + Tailwind CSS 3.4.1 + Radix UI + CVA
> **컨텍스트 효율**: 핵심 ~5KB / 상세 참조 시 +15KB

---

## 🎯 Quick Reference (80% 케이스 커버)

### 핵심 원칙 4가지

1. **Open Code** - 컴포넌트는 `components/ui/`에 직접 복사 (npm 아님)
2. **Composition** - Radix UI primitives 기반 합성
3. **CSS Variables** - 하드코딩 금지 (`bg-primary` ✅, `bg-blue-500` ❌)
4. **cn() 함수** - className 병합 필수

### 색상 사용 (암기)

```tsx
// ✅ CSS Variables 사용
<div className="bg-primary text-primary-foreground">주요 액션</div>
<div className="bg-muted text-muted-foreground">비활성</div>
<div className="bg-destructive text-destructive-foreground">위험</div>

// ❌ 하드코딩 금지
<div className="bg-blue-500 text-white">잘못된 예</div>
```

### 컴포넌트 사용

```tsx
// ✅ shadcn/ui 재사용
import { Button } from "@/components/ui/button"
<Button variant="default">클릭</Button>
<Button variant="destructive" size="sm">삭제</Button>

// ❌ 직접 스타일링 금지
<button className="px-4 py-2 bg-blue-500">잘못된 예</button>
```

---

## 🔤 Typography Quick Pick

| 용도 | 한글 폰트 | 영문 폰트 |
|------|----------|----------|
| **SaaS/본문** | **Pretendard** | Inter, Satoshi |
| **고급/브랜딩** | 본명조 (Noto Serif KR) | Playfair Display |
| **마케팅/배너** | **Gmarket Sans** | Clash Display |
| **게임/테크** | SF함박눈 | Orbitron |

```css
/* 기본 설정 (globals.css) */
@import url('https://cdn.jsdelivr.net/gh/orioncactus/pretendard/dist/web/static/pretendard.css');

:root {
  --font-sans: 'Pretendard', -apple-system, sans-serif;
}
```

**📚 상세**: @.claude/guides/references/ui-design/typography-catalog.md

---

## 🖼️ Image Quick Pick

| 용도 | 소스 | 예시 |
|------|------|------|
| **실제 사진** | Unsplash Direct URL | `?w=1200&h=800&fit=crop&q=80` |
| **일러스트** | AI 생성 (프롬프트) | Flat design, isometric |
| **아이콘** | Lucide React | `<LucideIcon />` |
| **아바타** | DiceBear | `api.dicebear.com/7.x/avataaars/svg?seed=` |

```tsx
// ✅ Next.js Image 필수
import Image from "next/image"
<Image src="..." alt="설명" width={1200} height={800} priority />

// ❌ 일반 img 금지
<img src="..." />
```

**📚 상세**: @.claude/guides/references/ui-design/image-strategy.md

---

## 🎨 Design Tokens Quick Pick

| 토큰 | Light | Dark | 용도 |
|------|-------|------|------|
| `--primary` | 진한 텍스트 | 밝은 텍스트 | 주요 액션 |
| `--muted` | 밝은 회색 | 어두운 회색 | 비활성/배경 |
| `--destructive` | 빨강 | 어두운 빨강 | 위험/삭제 |
| `--radius` | 0.5rem (8px) | - | 기본 둥글기 |

**📚 상세**: @.claude/guides/references/ui-design/design-tokens.md

---

## 🧩 Component Quick Reference

| 컴포넌트 | Variant | Size |
|---------|---------|------|
| **Button** | default, destructive, outline, secondary, ghost, link | default, sm, lg, icon |
| **Input** | - | default (h-10) |
| **Card** | Card, CardHeader, CardTitle, CardContent | - |

**📚 상세**: @.claude/guides/references/ui-design/component-patterns.md

---

## ✅ Agent 체크리스트

### code-writer UI 구현 시

- [ ] shadcn/ui 컴포넌트 재사용 (`components/ui/`)
- [ ] CSS Variables 사용 (하드코딩 금지)
- [ ] cn() 함수로 className 병합
- [ ] Next.js Image 컴포넌트 사용
- [ ] Dark Mode 지원 (자동)

### 자주 하는 실수

```tsx
// ❌ 하드코딩 색상
<div className="bg-blue-500">

// ❌ 일반 img 태그
<img src="..." />

// ❌ cn() 미사용
<div className={"base " + (active ? "active" : "")}>

// ❌ shadcn/ui 무시
<button className="px-4 py-2">
```

---

## 📱 Responsive (Mobile-First)

```tsx
// ✅ Mobile-First
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
  {/* 모바일: 1열 → 태블릿: 2열 → 데스크톱: 3열 */}
</div>

<Button size="sm" className="w-full md:w-auto">
  {/* 모바일: 전체 너비 → 데스크톱: 자동 */}
</Button>
```

---

## 🗂️ FSD 아키텍처 통합

```
apps/frontend/src/
├── app/                  # Next.js App Router
├── widgets/              # 복합 UI 블록
├── features/             # 기능별 블록
└── components/ui/        # shadcn/ui (23개)
```

**의존성**: app → widgets → features → components/ui

---

## 📚 상세 문서 (필요시 참조)

| 주제 | 파일 | 크기 |
|------|------|------|
| Typography 상세 | @references/ui-design/typography-catalog.md | ~4KB |
| Image 전략 상세 | @references/ui-design/image-strategy.md | ~5KB |
| Design Tokens 상세 | @references/ui-design/design-tokens.md | ~3KB |
| Component 패턴 상세 | @references/ui-design/component-patterns.md | ~4KB |

---

## 📚 외부 참조

- **shadcn/ui**: https://ui.shadcn.com/docs
- **Radix UI**: https://www.radix-ui.com/
- **Tailwind CSS**: https://tailwindcss.com/
- **CVA**: https://cva.style/docs

---

**버전**: 3.0.0 (Progressive Disclosure 적용)
**작성일**: 2025-12-01
**기반**: shadcn/ui + frontend-design-pro + ClaudeKit Progressive Disclosure

### 변경 이력
- **v3.0.0** (2025-12-01): Progressive Disclosure 적용, 메타데이터 추가, 5KB로 경량화
- **v2.2.0** (2025-12-01): 이미지 전략 추가
- **v2.1.0** (2025-12-01): Typography 권장 목록 추가
- **v2.0.0** (2025-11-08): shadcn/ui 전용 문서로 개편
