# Industry Design Benchmarks (Enterprise AI SaaS)

> Pro Max 산업 데이터 기반 큐레이션. UX Agent가 감사/제안 시 참조하는 벤치마크.
> Source: `.reference/ui-ux-pro-max-skill/src/ui-ux-pro-max/data/`

---

## 1. Color Palettes (산업별 기준)

### 우리 프로젝트 적합 팔레트 (AI + SaaS + Dashboard)

| 산업 | Primary | Secondary | CTA | Background | Text | Border | 무드 |
|------|---------|-----------|-----|------------|------|--------|------|
| **SaaS (General)** | `#2563EB` | `#3B82F6` | `#F97316` | `#F8FAFC` | `#1E293B` | `#E2E8F0` | Trust blue + orange CTA |
| **AI/Chatbot Platform** | `#7C3AED` | `#A78BFA` | `#06B6D4` | `#FAF5FF` | `#1E1B4B` | `#DDD6FE` | AI purple + cyan |
| **Analytics Dashboard** | `#1E40AF` | `#3B82F6` | `#F59E0B` | `#F8FAFC` | `#1E3A8A` | `#DBEAFE` | Blue data + amber |
| **Financial Dashboard** | `#0F172A` | `#1E293B` | `#22C55E` | `#020617` | `#F8FAFC` | `#334155` | Dark bg + green |
| **Developer Tool** | `#1E293B` | `#334155` | `#22C55E` | `#0F172A` | `#F8FAFC` | `#475569` | Code dark + run green |
| **B2B Service** | `#0F172A` | `#334155` | `#0369A1` | `#F8FAFC` | `#020617` | `#E2E8F0` | Navy + blue CTA |
| **Productivity Tool** | `#0D9488` | `#14B8A6` | `#F97316` | `#F0FDFA` | `#134E4A` | `#99F6E4` | Teal + action orange |
| **Collaboration Tool** | `#6366F1` | `#818CF8` | `#10B981` | `#F5F3FF` | `#312E81` | `#E0E7FF` | Calm indigo + success |

### 색상 선택 원칙

```
Enterprise AI SaaS 권장 조합:
├── Primary: Trust Blue (#2563EB) 또는 AI Purple (#7C3AED)
├── CTA: Contrast Orange (#F97316) 또는 Cyan (#06B6D4)
├── Success: Green (#22C55E)
├── Warning: Amber (#F59E0B)
├── Error: Red (#EF4444)
├── Background: Light (#F8FAFC) / Dark (#0F172A)
└── Text: Dark (#1E293B) / Light (#F8FAFC)

WCAG 대비율 최소:
├── 일반 텍스트: 4.5:1 (AA)
├── 큰 텍스트 (18px+): 3:1 (AA)
└── UI 요소: 3:1 (AA)
```

### Anti-Pattern (피해야 할 색상)

| 금지 | 이유 |
|------|------|
| 네온 핑크/그린 조합 | 엔터프라이즈 신뢰도 저하 |
| 과도한 그라데이션 | 정보 가독성 저하 |
| 저대비 회색 텍스트 | WCAG 위반 (4.5:1 미달) |
| 모든 요소에 색상 | 정보 계층 파괴 → 인지 과부하 |

---

## 2. Typography Pairings (추천 폰트)

### Enterprise AI SaaS 추천 Top 5

| 순위 | 이름 | Heading | Body | 적합 분야 | Tailwind Config |
|:----:|------|---------|------|-----------|-----------------|
| 1 | **Minimal Swiss** | Inter | Inter | 대시보드, 어드민, 디자인 시스템 | `{ sans: ['Inter', 'sans-serif'] }` |
| 2 | **Tech Startup** | Space Grotesk | DM Sans | AI 제품, SaaS, 개발자 도구 | `{ heading: ['Space Grotesk'], body: ['DM Sans'] }` |
| 3 | **Dashboard Data** | Fira Code | Fira Sans | 데이터 시각화, 분석 패널 | `{ mono: ['Fira Code'], sans: ['Fira Sans'] }` |
| 4 | **Developer Mono** | JetBrains Mono | IBM Plex Sans | 개발자 도구, 코드 에디터 | `{ mono: ['JetBrains Mono'], sans: ['IBM Plex Sans'] }` |
| 5 | **Friendly SaaS** | Plus Jakarta Sans | Plus Jakarta Sans | 웹앱, B2B 생산성 도구 | `{ sans: ['Plus Jakarta Sans'] }` |

### Korean 지원

| 이름 | 폰트 | 적합 분야 |
|------|------|-----------|
| **Korean Modern** | Noto Sans KR | 한국어 사이트, K-비즈니스 |
| **추천 조합** | Inter + Noto Sans KR | 영한 혼합 SaaS (우리 프로젝트) |

### 타이포그래피 스케일

```
Font Size Scale (권장):
├── xs:  12px (0.75rem)  — 캡션, 메타
├── sm:  14px (0.875rem) — 부가 텍스트, 레이블
├── base: 16px (1rem)    — 본문
├── lg:  18px (1.125rem) — 서브헤딩
├── xl:  20px (1.25rem)  — 헤딩 3
├── 2xl: 24px (1.5rem)   — 헤딩 2
├── 3xl: 30px (1.875rem) — 헤딩 1
└── 4xl: 36px (2.25rem)  — 페이지 타이틀

Line Height: 1.5 (본문), 1.2 (헤딩)
Letter Spacing: -0.01em (헤딩), 0 (본문)
```

---

## 3. UI Style Priorities (산업별 추론 규칙)

### Enterprise AI SaaS 추천 스타일

| 스타일 | 적합도 | 성능 | 접근성 | Best For |
|--------|:------:|:----:|:------:|----------|
| **Minimalism & Swiss** | ★★★★★ | Excellent | WCAG AAA | 대시보드, 어드민 |
| **Flat Design 3.0** | ★★★★★ | Excellent | WCAG AA | SaaS 전반 |
| **Glassmorphism** | ★★★★☆ | Good | WCAG AA | 카드 오버레이, 모달 |
| **Dark Mode (OLED)** | ★★★★☆ | Excellent | WCAG AA | 대시보드, 개발자 도구 |
| **Data-Dense UI** | ★★★★☆ | Good | WCAG AA | 분석, 모니터링 |

### 스타일별 핵심 속성

```
Minimalism & Swiss:
├── Colors: Monochromatic (#000, #FFF, 1 accent)
├── Effects: Subtle hover (bg-muted/50), No shadows
├── Layout: Grid-based, generous whitespace
├── Complexity: Low
└── CSS: gap, grid-template, color-scheme

Flat Design 3.0:
├── Colors: Bold, limited palette (3-4 colors)
├── Effects: Subtle depth (ring-1), No gradients
├── Layout: Card-based, clear hierarchy
├── Complexity: Low
└── CSS: border-radius, ring, shadow-sm

Glassmorphism (부분 적용):
├── Colors: Semi-transparent backgrounds
├── Effects: backdrop-blur, bg-white/10
├── Layout: Floating cards over content
├── Complexity: Medium
└── CSS: backdrop-filter, bg-opacity, border-opacity
└── ⚠️ 접근성 주의: 텍스트 대비 확보 필수
```

### Anti-Pattern (Enterprise AI에서 피해야 할 스타일)

| 금지 | 이유 | Severity |
|------|------|:--------:|
| Skeuomorphism | 구식 느낌, 엔터프라이즈 신뢰 저하 | HIGH |
| Excessive Neumorphism | 접근성 위험 (낮은 대비) | HIGH |
| Brutalism | 엔터프라이즈 사용자 혼란 | HIGH |
| AI Purple/Pink 과다 | 모든 AI 앱이 비슷해 보임 (Mode Collapse) | MEDIUM |
| 과도한 애니메이션 | 전문성 저하 + 성능 이슈 | MEDIUM |
| 네온/사이버펑크 | B2B 맥락에서 부적절 | HIGH |

---

## 4. UX Reasoning Rules (의사결정 가이드)

### Enterprise AI SaaS 핵심 추론 규칙

```yaml
SaaS_General:
  pattern: "Hero + Features + CTA"
  style_priority: "Flat Design + Minimalism"
  color_mood: "Trust blue + Accent contrast"
  key_effects: "Subtle hover, Skeleton loading, Smooth transitions 200-250ms"
  anti_patterns: "Excessive animation, Complex gradients, Auto-play video"
  decision_rules:
    if_ux_focused: "prioritize-minimalism"
    if_data_heavy: "add-data-dense-patterns"
    if_accessibility_critical: "increase-contrast"
    if_mobile_first: "reduce-animation"

AI_Platform:
  pattern: "Chat interface + Side panel + Tool results"
  style_priority: "Dark mode + Glassmorphism accents"
  color_mood: "Purple tech + Cyan interactions"
  key_effects: "Streaming text, Thinking indicators, Code highlighting"
  anti_patterns: "Generic chatbot UI, Excessive purple/pink, No loading state"
  decision_rules:
    if_code_output: "add-syntax-highlighting"
    if_streaming: "add-progressive-rendering"
    if_multi_agent: "add-agent-indicators"

Dashboard:
  pattern: "Sidebar nav + KPI cards + Data tables + Charts"
  style_priority: "Data-Dense + Minimalism"
  color_mood: "Neutral base + Semantic colors (green/red/amber)"
  key_effects: "Real-time updates, Sortable tables, Filter chips"
  anti_patterns: "Too many chart types, Rainbow colors, No empty states"
  decision_rules:
    if_real_time: "add-live-indicators"
    if_comparison: "use-consistent-scales"
    if_filtering: "add-filter-chips-not-dropdowns"
```

---

## 5. Industry Scoring Baselines (감사 기준)

### SaaS 대시보드 업계 평균 (UX Agent 감사 시 비교 기준)

| 영역 | 평균 | Top 25% | Top 10% | 출처 |
|------|:----:|:-------:|:-------:|------|
| **Nielsen Heuristics** | 68/100 | 82/100 | 92/100 | NN/g 2024 |
| **WCAG 2.2 AA** | 72/100 | 88/100 | 96/100 | WebAIM 2024 |
| **UX Writing** | 65/100 | 80/100 | 90/100 | Google Material 3 |
| **Cognitive Load** | 5.8/10 | 7.5/10 | 8.8/10 | Miller's Law baseline |

### 인지 부하 기준값 (법칙별)

| 법칙 | 권장 | 경고 | 위험 |
|------|:----:|:----:|:----:|
| **Hick's** (선택지 수) | ≤7 | 8-12 | 13+ |
| **Fitts's** (터치 영역) | ≥44px | 24-43px | <24px |
| **Miller's** (한 화면 항목) | ≤7 | 8-12 | 13+ |

### 인터랙션 기준값

| 항목 | 권장 | 출처 |
|------|------|------|
| **Transition 시간** | 150-300ms | Material Design |
| **Debounce (검색)** | 300ms | UX best practice |
| **Toast 표시** | 3-5초 | Nielsen |
| **로딩 피드백** | 0.1초 이내 시작 | NN/g 응답 시간 |
| **Skeleton 교체** | 1-3초 내 실 데이터 | Perceived performance |

---

## 6. Pre-Delivery Checklist (구현 후 검증)

### Visual Quality
- [ ] Emoji 아이콘 미사용 (SVG/Lucide 사용)
- [ ] 아이콘 크기 일관성 (16/20/24px)
- [ ] Hover 시 레이아웃 시프트 없음
- [ ] WCAG AA 대비율 충족 (4.5:1 텍스트, 3:1 UI)

### Interaction
- [ ] 클릭 가능 요소에 `cursor-pointer`
- [ ] Transition 150-300ms 범위
- [ ] 키보드 탐색 가능 (`focus-visible:ring-2`)
- [ ] `prefers-reduced-motion` 존중

### Layout
- [ ] 반응형: 375px, 768px, 1024px, 1440px
- [ ] 고정 요소(헤더/사이드바) 뒤에 콘텐츠 숨김 없음
- [ ] Floating 요소 적절한 z-index + spacing

### Performance
- [ ] 이미지 lazy loading + srcset
- [ ] 불필요한 리렌더 방지 (React.memo/useMemo)
- [ ] 번들 크기 최적화 (dynamic import)

### Accessibility
- [ ] 터치 타겟 ≥44x44px (최소 24x24px)
- [ ] `<label>` + `for` 연결
- [ ] `aria-*` 속성 (상태 표시 요소)
- [ ] 아이콘 전용 버튼에 `aria-label`

---

## 7. Verbalized Sampling BLACKLIST 보강

### Enterprise AI SaaS에서 "뻔한" 패턴 (Agent가 회피해야 함)

```yaml
색상:
  - "보라색-파란색 그라데이션" (모든 AI 앱이 동일)
  - "shadcn/ui 기본 primary (#000)" (커스터마이징 없음)
  - "무지개 차트 색상" (정보 과부하)

레이아웃:
  - "왼쪽 사이드바 + 3열 카드 그리드" (디폴트 대시보드)
  - "모달 안에 모달" (인지 과부하)
  - "탭 7개 이상" (Miller 위반)

버튼:
  - "오른쪽 정렬 Primary 버튼만" (맥락 무시)
  - "모달 하단 [취소][확인] 고정" (작업 맥락 무시)

폼:
  - "수직 나열 + 빨간색 에러 + 별표(*) 필수" (기본 패턴)
  - "한 화면에 12개+ 필드" (Miller 위반)

로딩:
  - "회전 스피너 (spin)" (체감 속도 저하)
  - "진행률 표시 없는 프로그레스 바" (불확실성 증가)

차트:
  - "파이 차트 6조각 이상" (인지 과부하)
  - "3D 차트" (정보 왜곡)
```

### 창의적 대안 힌트 (Agent 참고용)

| 뻔한 패턴 | 창의적 대안 | 신뢰도 |
|-----------|------------|:------:|
| 12개 폼 필드 한 화면 | Progressive Disclosure + AI 자동완성 | 87% |
| 왼쪽 사이드바 네비게이션 | Command Palette (⌘K) + Top Nav | 82% |
| 카드 그리드 3열 | Bento Grid (비대칭 크기) + Priority Zones | 78% |
| 모달 확인 다이얼로그 | Inline 확인 + Undo 토스트 | 91% |
| 테이블 페이지네이션 | Virtual Scrolling + 검색 필터 | 85% |
| 드롭다운 5개+ 필터 | Filter Chips (토글) + 저장된 뷰 | 88% |

---

## 8. 차트 유형 가이드

### 데이터별 추천 차트

| 데이터 유형 | 추천 차트 | 라이브러리 | 주의 |
|------------|----------|-----------|------|
| **시계열 추이** | Line Chart | Recharts / Tremor | Y축 0 시작 여부 확인 |
| **카테고리 비교** | Bar Chart (수평) | Recharts | 7개 이하 카테고리 |
| **비율 (2-4)** | Donut Chart | Recharts | 6조각 이상 금지 |
| **분포** | Histogram | Recharts | bin 크기 적절히 |
| **관계** | Scatter Plot | Recharts | 포인트 1000개 이하 |
| **KPI 요약** | Stat Card + Sparkline | Tremor | 3-5개 KPI |
| **실시간** | Streaming Line | Custom | WebSocket + requestAnimationFrame |

---

## Quick Reference

```
우리 프로젝트 (Enterprise AI SaaS) 기본 설정:

Color:    Primary #2563EB (blue-600), CTA #F97316 (orange-500)
Font:     Inter (heading + body) → Noto Sans KR (한국어)
Style:    Minimalism + Flat Design 3.0
Layout:   Sidebar nav + Card-based content
Loading:  Skeleton → 실 데이터 (1-3초)
Spacing:  4/8/16/24/32px 리듬
Radius:   rounded-lg (8px) 기본
Shadow:   shadow-sm 최소 사용, bg-muted/50 hover 선호
Motion:   transition-colors 200ms
Target:   Nielsen 82+, WCAG 88+, Writing 80+, Cognitive 7.5+
```

---

_Source: ui-ux-pro-max-skill v2.0 (MIT) — Curated for mcp-orch project_
_Version: 1.0 — 2026-02-11_
