# UI 패턴 가이드 (Square UI + Industry Benchmarks)

> 엔터프라이즈급 UI를 위한 핵심 패턴.
> 참조: `.reference/square-ui/` | 산업 벤치마크: `@.claude/guides/INDUSTRY_DESIGN_BENCHMARKS.md`

---

## 1. Shadow → Subtle Hover

**문제**: `hover:shadow-lg`는 구식 느낌을 줌

```tsx
// ❌ 피하기
<Card className="hover:shadow-lg transition-shadow">

// ✅ 권장
<Card className="hover:bg-muted/50 transition-colors">

// ✅ 테두리 강조가 필요한 경우
<Card className="ring-1 ring-border hover:ring-foreground/20 transition-all">
```

**원칙**: Shadow 대신 `bg-muted/50` 또는 `ring` 테두리로 depth 표현

---

## 2. Skeleton 로딩

**문제**: 스피너만 사용하면 체감 속도 저하

```tsx
// ❌ 피하기
<div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />

// ✅ 권장: Skeleton으로 레이아웃 유지
import { Skeleton } from '@/components/ui/skeleton';

// 카드 로딩
<Card>
  <CardHeader>
    <Skeleton className="h-5 w-1/3" />
    <Skeleton className="h-4 w-2/3 mt-2" />
  </CardHeader>
  <CardContent>
    <Skeleton className="h-[120px] w-full rounded-md" />
  </CardContent>
</Card>

// 테이블 로딩
<TableRow>
  <TableCell><Skeleton className="h-4 w-24" /></TableCell>
  <TableCell><Skeleton className="h-4 w-32" /></TableCell>
  <TableCell><Skeleton className="h-4 w-16" /></TableCell>
</TableRow>
```

**원칙**: 로딩 시 최종 레이아웃과 동일한 구조 유지

---

## 3. Spacing 시스템

**문제**: gap-2, gap-4, gap-6 무질서 혼용 → 시각적 불안정

```tsx
// ✅ 일관된 Spacing 규칙
// 4px  (gap-1)   - 아이콘과 텍스트 사이
// 8px  (gap-2)   - 관련 요소 그룹 내
// 16px (gap-4)   - 섹션 내 요소 간
// 24px (gap-6)   - 섹션 간
// 32px (gap-8)   - 주요 영역 간

// 예시
<div className="space-y-6">           {/* 섹션 간 */}
  <section className="space-y-4">     {/* 섹션 내 */}
    <div className="flex gap-2">      {/* 요소 그룹 */}
      <Icon className="h-4 w-4" />    {/* 아이콘 */}
      <span>텍스트</span>
    </div>
  </section>
</div>
```

**원칙**: 4/8/16/24/32px 리듬 유지

---

## 4. 접근성 패턴

**문제**: aria 속성 부재 → 스크린리더 미지원

```tsx
// ✅ 폼 요소
<Input
  aria-invalid={!!error}
  aria-describedby={error ? "error-message" : undefined}
/>
{error && <p id="error-message" className="text-sm text-destructive">{error}</p>}

// ✅ 토글/확장 요소
<Button
  aria-expanded={isOpen}
  aria-controls="dropdown-content"
  onClick={() => setIsOpen(!isOpen)}
>
  메뉴
</Button>
<div id="dropdown-content" hidden={!isOpen}>...</div>

// ✅ 비활성 상태
<Button disabled className="disabled:opacity-50 disabled:pointer-events-none">
  저장 중...
</Button>

// ✅ 포커스 표시 (키보드 네비게이션)
<Button className="focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2">
  클릭
</Button>
```

**원칙**: `aria-*` 속성으로 상태 명시, `focus-visible` 스타일 필수

---

## 5. 미세 인터랙션

**문제**: hover 피드백만 있으면 "죽은" 느낌

```tsx
// ✅ 부드러운 색상 전환
<Button className="transition-colors hover:bg-primary/90">

// ✅ 테이블 행 하이라이트
<TableRow className="hover:bg-muted/50 transition-colors data-[state=selected]:bg-muted">

// ✅ 카드 선택 피드백
<Card className="transition-all hover:bg-muted/50 data-[selected=true]:ring-2 data-[selected=true]:ring-primary">

// ✅ 아이콘 버튼
<Button variant="ghost" size="icon" className="transition-colors hover:bg-muted">
  <MoreHorizontal className="h-4 w-4" />
</Button>
```

**원칙**: `transition-colors` 또는 `transition-all` 필수, 150ms 기본

---

## 6. Color System (Enterprise AI SaaS)

**기본 팔레트** (산업 벤치마크 기반):
```
Primary:    #2563EB (blue-600)    — Trust, 전문성
Secondary:  #3B82F6 (blue-500)    — 보조 정보
CTA:        #F97316 (orange-500)  — 행동 유도
Success:    #22C55E (green-500)   — 성공, 활성
Warning:    #F59E0B (amber-500)   — 경고, 주의
Error:      #EF4444 (red-500)     — 에러, 위험
Background: #F8FAFC (slate-50)    — 라이트 모드
Surface:    #FFFFFF               — 카드/패널
Text:       #1E293B (slate-800)   — 본문
Muted:      #64748B (slate-500)   — 부가 텍스트
Border:     #E2E8F0 (slate-200)   — 구분선
```

**대비율 필수**:
- 텍스트: 4.5:1 (WCAG AA)
- UI 요소: 3:1 (WCAG AA)
- 아이콘: 3:1 (인접 배경 대비)

---

## 7. Typography System

**프로젝트 기본**: Inter + Noto Sans KR
```tsx
// tailwind.config.ts
fontFamily: {
  sans: ['Inter', 'Noto Sans KR', 'sans-serif'],
  mono: ['JetBrains Mono', 'monospace'],  // 코드 블록용
}
```

**크기 스케일**:
```
text-xs   (12px) — 캡션, 타임스탬프, 메타
text-sm   (14px) — 레이블, 부가 텍스트
text-base (16px) — 본문 (기본)
text-lg   (18px) — 서브헤딩
text-xl   (20px) — 섹션 타이틀
text-2xl  (24px) — 페이지 서브타이틀
text-3xl  (30px) — 페이지 타이틀
```

---

## 8. Chart Guidelines

| 데이터 | 차트 | 색상 규칙 |
|--------|------|----------|
| 시계열 추이 | Line Chart | Primary 1색 + Muted 보조선 |
| 카테고리 비교 | Horizontal Bar | 7개 이하, Semantic colors |
| 비율 (2-4개) | Donut Chart | 6조각 이하, 레이블 필수 |
| KPI 요약 | Stat Card + Sparkline | 3-5개, 변화율 표시 |

---

## 9. Flex Layout & Alignment

**문제**: Toolbar/Input bar에서 `items-center` 누락 → 아이콘·입력·버튼 수직 정렬 불일치

### Toolbar / Input Bar (수평 배치)
```tsx
// ✅ 권장: 아이콘 + 입력 + 버튼이 수평으로 나열되는 경우
<div className="flex items-center gap-2">
  <Button size="icon" className="flex-shrink-0">…</Button>   {/* 고정 크기 */}
  <div className="flex-1 min-w-0">                            {/* 가변 영역 */}
    <Input />
  </div>
  <div className="flex items-center gap-1 flex-shrink-0">     {/* 버튼 그룹 */}
    <Button size="icon">…</Button>
    <Button size="icon">…</Button>
  </div>
</div>
```

### 핵심 규칙

| 상황 | 클래스 | 이유 |
|------|--------|------|
| 아이콘+입력+버튼 수평 배치 | `flex items-center` | 수직 중앙 정렬 |
| 고정 크기 요소 (아이콘, 버튼) | `flex-shrink-0` | 축소 방지 |
| 가변 영역 (입력, 텍스트) | `flex-1 min-w-0` | 남은 공간 채우기 + 오버플로 방지 |
| 관련 버튼 그룹 | `flex items-center gap-1` | 그룹 내 정렬 + 간격 |
| 멀티라인 textarea + 하단 정렬 버튼 | `items-end` | 전송 버튼이 입력 하단에 위치 |

### ❌ 흔한 실수
```tsx
// ❌ items-center 누락 → 요소들이 상단 정렬되어 어긋남
<div className="flex gap-2">
  <Icon /><Input /><Button />
</div>

// ❌ flex-shrink-0 누락 → 입력이 넓어지면 버튼이 찌그러짐
<div className="flex items-center gap-2">
  <Button>전송</Button>
</div>

// ❌ min-w-0 누락 → 긴 텍스트가 컨테이너 밖으로 넘침
<div className="flex-1">
  <Input />
</div>
```

**원칙**: 수평 배치 = `items-center` 기본. `items-end`는 멀티라인 입력+하단 버튼일 때만.

### Overflow 제어 (가로 스크롤 방지)
```tsx
// ✅ 전체 레이아웃 루트에 overflow-hidden
<div className="flex h-screen overflow-hidden">
  <Sidebar />
  <main className="flex-1 overflow-y-auto overflow-x-hidden min-w-0">
    {children}
  </main>
</div>

// ✅ 고정 폭 사이드 패널에 shrink-0 + overflow-hidden
<div className="w-72 shrink-0 overflow-hidden border-l">
  <ScrollArea>...</ScrollArea>
</div>
```

| 상황 | 클래스 | 이유 |
|------|--------|------|
| 전체 레이아웃 루트 | `overflow-hidden` | 어떤 자식도 뷰포트 밖으로 넘지 못하게 |
| main 영역 | `overflow-y-auto overflow-x-hidden min-w-0` | 세로만 스크롤, 가로 차단 |
| 고정 폭 패널 (sidebar, context) | `shrink-0 overflow-hidden` | 축소/넘침 둘 다 방지 |
| 긴 텍스트 컨테이너 | `break-words` 또는 `truncate` | 단어 단위 줄바꿈 또는 말줄임 |

---

## Quick Reference

| 상황 | 패턴 |
|------|------|
| 카드 hover | `hover:bg-muted/50 transition-colors` |
| 테이블 행 | `hover:bg-muted/50 transition-colors` |
| 버튼 hover | `hover:bg-primary/90 transition-colors` |
| 로딩 | `<Skeleton />` 컴포넌트 |
| 섹션 간격 | `space-y-6` |
| 요소 간격 | `gap-4` |
| 아이콘-텍스트 | `gap-2` |
| 포커스 | `focus-visible:ring-2` |
| 비활성 | `disabled:opacity-50` |
| 수평 배치 (toolbar) | `flex items-center gap-2` |
| 고정 크기 요소 | `flex-shrink-0` |
| 가변 입력 영역 | `flex-1 min-w-0` |
| 버튼 그룹 | `flex items-center gap-1` |

---

## 상세 참조

전체 컴포넌트 구현이 필요한 경우:
```
.reference/square-ui/src/components/ui/
├── button.tsx      # CVA 변형 관리 패턴
├── card.tsx        # 컴포지션 패턴
├── skeleton.tsx    # 로딩 컴포넌트
└── table.tsx       # 테이블 스타일링
```

산업 벤치마크 (색상/폰트/스타일/안티패턴):
```
.claude/guides/INDUSTRY_DESIGN_BENCHMARKS.md
├── Color Palettes (8개 산업별 팔레트)
├── Typography Pairings (Top 5 추천)
├── UI Style Priorities (적합도/성능/접근성)
├── UX Reasoning Rules (의사결정 가이드)
├── Scoring Baselines (감사 기준값)
├── Pre-Delivery Checklist
├── VS BLACKLIST 보강 (뻔한 패턴 회피)
└── Chart Guidelines (데이터별 추천)
```
