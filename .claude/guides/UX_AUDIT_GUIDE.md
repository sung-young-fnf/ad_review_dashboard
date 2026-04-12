# UX Audit System 사용 가이드

> **버전**: 1.0
> **생성일**: 2025-12-14
> **목적**: 전문가급 UX 감사 → Epic 자동 생성 → 구현까지 원스톱 워크플로우

---

## 📊 시스템 개요

### 4-Tier UX Audit 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          UX AUDIT PIPELINE                                   │
└─────────────────────────────────────────────────────────────────────────────┘

  Phase 1: AUDIT                           Phase 2: PLANNING
  ─────────────────                        ─────────────────

  ┌───────────────────────┐
  │   ux-master-auditor   │ ───────────────────────────────────────────────┐
  │   (오케스트레이터)     │                                                │
  └───────────┬───────────┘                                                │
              │ 병렬 실행                                                   │
              ▼                                                            │
  ┌───────────────────────────────────────────────────────────────────┐    │
  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────────┐ │    │
  │ │ ux-heuristic│ │  ui-tester  │ │  ux-writer  │ │cognitive-load │ │    │
  │ │  -auditor   │ │ (WCAG 2.2)  │ │  -auditor   │ │  -analyzer    │ │    │
  │ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └───────┬───────┘ │    │
  └────────┼───────────────┼───────────────┼────────────────┼─────────┘    │
           │               │               │                │              │
           └───────────────┴───────────────┴────────────────┘              │
                           ▼                                               │
  ┌─────────────────────────────────────────────────────┐                  │
  │               UX-AUDIT-REPORT.md                     │ ◄────────────────┘
  │  • 종합 점수 (Nielsen + WCAG + Writing + Cognitive) │
  │  • P0/P1/P2/P3 우선순위 분류                         │
  │  • AS-IS → TO-BE ASCII Art                           │
  │  • 개선 효과 정량화                                   │
  └──────────────────────────┬──────────────────────────┘
                             │
                             │ 자동 변환
                             ▼
  Phase 3: IMPLEMENTATION
  ───────────────────────

  ┌─────────────────────────────────────────────────────┐
  │                   epic-creator                       │
  │  "UX 개선 Epic: P0-P2 항목 구현"                     │
  └──────────────────────────┬──────────────────────────┘
                             │
                             ▼
  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
  │story-creator │ →  │task-planner  │ →  │ code-writer  │
  └──────────────┘    └──────────────┘    └──────────────┘
                                                  │
                                                  ▼
  ┌─────────────────────────────────────────────────────┐
  │                    ui-tester                         │
  │           (Before/After 비교 검증)                   │
  └─────────────────────────────────────────────────────┘
```

---

## 🚀 빠른 시작

### 1. 전체 UX 감사 실행

```bash
# ux-master-auditor 실행 (3개 에이전트 병렬)
Task(
  subagent_type: "05-quality/ux-master-auditor",
  prompt: "
    대상 URL: http://localhost:3000
    전체 페이지 UX 감사 실행
  "
)
```

### 2. 개별 에이전트 실행

```bash
# Nielsen 휴리스틱만 평가
Task(subagent_type: "05-quality/ux-heuristic-auditor", prompt: "...")

# WCAG 2.2 접근성만 검증
Task(subagent_type: "04-implementation/ui-tester", prompt: "...")

# 인지 부하만 분석
Task(subagent_type: "05-quality/cognitive-load-analyzer", prompt: "...")
```

### 3. Epic 생성 및 구현

```bash
# 감사 결과 기반 Epic 생성
/epic-creator:create "UX 개선 - Nielsen/WCAG 위반 수정"

# 이후 자동으로:
# story-creator → task-planner → code-writer → ui-tester
```

---

## 📋 에이전트별 상세

### 1. ux-heuristic-auditor

**역할**: Nielsen Norman Group 10 Usability Heuristics 평가

**체크 항목**:
| # | 휴리스틱 | 주요 체크포인트 |
|---|----------|----------------|
| H1 | 시스템 상태 표시 | 로딩 스피너, 토스트 알림 |
| H2 | 현실 세계 일치 | 사용자 언어, 친숙한 아이콘 |
| H3 | 사용자 제어 | 취소 버튼, Undo 기능 |
| H4 | 일관성 | 용어/스타일 통일 |
| H5 | 오류 방지 | 확인 다이얼로그, 유효성 검사 |
| H6 | 인식 > 회상 | 레이블 명확, 툴팁 |
| H7 | 유연성 | 키보드 단축키, 개인화 |
| H8 | 미학적 최소주의 | 불필요 요소 제거 |
| H9 | 오류 복구 | 명확한 에러 메시지 |
| H10 | 도움말 | 검색 가능한 문서 |

**심각도 등급**:
- 0: 문제 없음
- 1: Cosmetic (P3)
- 2: Minor (P2)
- 3: Major (P1)
- 4: Catastrophic (P0)

**출력**: `docs/analysis/UX-HEURISTIC-AUDIT-REPORT.md`

---

### 2. ui-tester (WCAG 2.2 업그레이드)

**역할**: WCAG 2.1 + 2.2 AA 접근성 검증

**WCAG 2.1 AA (기존)**:
- Color Contrast (4.5:1)
- Keyboard Navigation
- ARIA Labels

**WCAG 2.2 AA (신규 7개)**:
| # | 기준 | 설명 |
|---|------|------|
| 2.4.11 | Focus Not Obscured | 포커스 가려지지 않음 |
| 2.4.13 | Focus Appearance | 포커스 인디케이터 2px+ |
| 2.5.7 | Dragging Movements | 드래그 대체 수단 |
| **2.5.8** | **Target Size (24px)** | **클릭 영역 최소 24x24px** ⭐ |
| 3.2.6 | Consistent Help | 도움말 위치 일관성 |
| 3.3.7 | Redundant Entry | 중복 입력 방지 |
| 3.3.8 | Accessible Authentication | 인지 테스트 없는 인증 |

**출력**: `docs/analysis/WCAG-AUDIT-REPORT.md`

---

### 3. cognitive-load-analyzer

**역할**: 인지 심리학 기반 복잡도 분석

**적용 법칙**:

| 법칙 | 공식 | 권장 |
|------|------|------|
| **Hick's Law** | 결정시간 ∝ log₂(n+1) | 선택지 ≤ 7개 |
| **Fitts's Law** | 이동시간 ∝ 거리/크기 | 버튼 ≥ 44px |
| **Miller's Law** | 기억용량 = 7±2 | 그룹화 필수 |

**측정 항목**:
- 폼 필드 수 (한 화면)
- 네비게이션 메뉴 개수
- 버튼/클릭 영역 크기
- 정보 밀도

**출력**: `docs/analysis/COGNITIVE-LOAD-REPORT.md`

---

### 4. ux-writer-auditor

**역할**: UX 라이팅/워딩 검사

**체크 항목**:
| # | 항목 | 주요 체크포인트 |
|---|------|----------------|
| W1 | 톤앤매너 | 존칭/반말 일관성, 친근함 수준 |
| W2 | 용어집 | 동일 개념 동일 용어 (저장/Save 통일) |
| W3 | 마이크로카피 | 버튼/레이블/힌트 명확성 |
| W4 | 에러 메시지 | 원인+해결책 제시, 비난 금지 |
| W5 | 다국어 혼용 | 불필요한 영어 사용 감지 |

**출력**: `docs/analysis/UX-WRITING-AUDIT-REPORT.md`

---

### 5. ux-master-auditor

**역할**: 4개 에이전트 오케스트레이션 + 종합 리포트

**가중치**:
- Nielsen 휴리스틱: 35%
- WCAG 접근성: 35%
- UX 라이팅: 15%
- 인지 부하: 15%

**등급 체계**:
| 점수 | 등급 | 상태 |
|------|------|------|
| 90+ | A | 🏆 우수 |
| 80-89 | B | ✅ 양호 |
| 70-79 | C | ⚠️ 개선 필요 |
| 60-69 | D | 🔶 주의 필요 |
| <60 | F | 🔴 긴급 개선 |

**출력**: `docs/analysis/UX-AUDIT-REPORT.md`

---

## 📄 리포트 예시

### AS-IS → TO-BE 예시

```
### [H3] 취소 버튼 없음

#### AS-IS
┌─────────────────────────────────────┐
│  프로젝트 생성                       │
├─────────────────────────────────────┤
│  프로젝트명: [____________]          │
│  설명:       [____________]          │
│                                      │
│                         [저장]       │  ← 취소 버튼 없음!
└─────────────────────────────────────┘

#### TO-BE
┌─────────────────────────────────────┐
│  프로젝트 생성                       │
├─────────────────────────────────────┤
│  프로젝트명: [____________]          │
│  설명:       [____________]          │
│                                      │
│                    [취소] [저장]     │  ✅ 취소 버튼 추가
└─────────────────────────────────────┘

#### 개선 효과
| 지표 | Before | After | 개선율 |
|------|--------|-------|--------|
| H3 점수 | 1/4 | 4/4 | +300% |
| 사용자 이탈률 | 15% | 5% | -67% |
```

---

## 🔗 워크플로우 연계

### 전체 파이프라인

1. **UX 감사** → `ux-master-auditor`
2. **리포트 생성** → `UX-AUDIT-REPORT.md`
3. **Epic 생성** → `/epic-creator:create "UX 개선"`
4. **Story 분해** → `story-creator`
5. **Task 상세화** → `task-planner`
6. **코드 구현** → `code-writer`
7. **검증** → `ui-tester` (Before/After)

### 자동화 트리거

```bash
# 감사 완료 후 자동 Epic 생성
await mcp__serena__write_memory(
  'handoff/epic-creator_ux-improvement',
  { from: 'ux-master-auditor', ... }
)
```

---

## 📚 참조 문서

- [Nielsen Norman Group 10 Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [WCAG 2.2 표준](https://www.w3.org/TR/WCAG22/)
- [WebAIM WCAG Checklist](https://webaim.org/standards/wcag/checklist)
- [Cognitive Load Theory](https://en.wikipedia.org/wiki/Cognitive_load)

---

## 🌐 추가 검사 항목 (Vercel Web Guidelines 기반)

> **출처**: Vercel web-design-guidelines
> **동적 참조**: https://github.com/vercel-labs/web-interface-guidelines

### 1. Touch & Interaction

| 항목 | 체크포인트 | 권장 |
|------|-----------|------|
| **touch-action** | 스크롤/줌 제어 명시 | `touch-action: manipulation` |
| **tap-highlight** | 모바일 탭 하이라이트 | `-webkit-tap-highlight-color: transparent` |
| **Target Size** | WCAG 2.5.8 터치 영역 | 최소 24x24px (권장 44x44px) |
| **Passive Listeners** | 스크롤 성능 | `{ passive: true }` 옵션 |

```css
/* ✅ 터치 최적화 */
.interactive-element {
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  min-width: 44px;
  min-height: 44px;
}
```

### 2. i18n / Locale

| 항목 | ❌ 잘못된 방식 | ✅ 올바른 방식 |
|------|-------------|--------------|
| **날짜 표시** | `date.toLocaleDateString()` | `Intl.DateTimeFormat` |
| **숫자 표시** | `number.toFixed(2)` | `Intl.NumberFormat` |
| **통화 표시** | `'$' + amount` | `Intl.NumberFormat(locale, { style: 'currency' })` |
| **상대 시간** | 수동 계산 | `Intl.RelativeTimeFormat` |

```typescript
// ✅ 국제화 패턴
const dateFormatter = new Intl.DateTimeFormat('ko-KR', {
  year: 'numeric', month: 'long', day: 'numeric'
});

const numberFormatter = new Intl.NumberFormat('ko-KR', {
  style: 'currency', currency: 'KRW'
});

const relativeFormatter = new Intl.RelativeTimeFormat('ko', {
  numeric: 'auto'
});
```

### 3. Performance (추가)

| 항목 | 설명 | 권장 |
|------|------|------|
| **preconnect** | 외부 도메인 연결 힌트 | `<link rel="preconnect" href="...">` |
| **content-visibility** | 오프스크린 렌더링 지연 | `content-visibility: auto` |
| **Virtualization** | 긴 리스트 최적화 | react-window, @tanstack/virtual |
| **Layout Thrashing** | 강제 리플로우 방지 | getBoundingClientRect 캐싱 |

```tsx
// ✅ 긴 리스트 가상화
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }) {
  const parentRef = useRef(null);
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 80,
  });

  return (
    <div ref={parentRef} style={{ height: '400px', overflow: 'auto' }}>
      <div style={{ height: virtualizer.getTotalSize() }}>
        {virtualizer.getVirtualItems().map(virtualRow => (
          <div key={virtualRow.key} style={{
            position: 'absolute',
            top: virtualRow.start,
            height: virtualRow.size,
          }}>
            {items[virtualRow.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

### 4. Navigation & State

| 항목 | 체크포인트 |
|------|-----------|
| **URL 반영** | UI 상태가 URL에 반영되는가? (필터, 탭, 페이지) |
| **Deep Linking** | 특정 상태로 직접 접근 가능한가? |
| **Back Button** | 뒤로가기가 예상대로 동작하는가? |
| **Share URL** | 현재 상태를 공유 가능한 URL로 제공하는가? |

```typescript
// ✅ URL 상태 동기화
import { useSearchParams } from 'next/navigation';

function FilteredList() {
  const searchParams = useSearchParams();
  const filter = searchParams.get('filter') ?? 'all';

  const setFilter = (value: string) => {
    const params = new URLSearchParams(searchParams);
    params.set('filter', value);
    router.push(`?${params.toString()}`);
  };
}
```

### 5. Dark Mode & Theming

| 항목 | 체크포인트 |
|------|-----------|
| **color-scheme** | `<meta name="color-scheme" content="light dark">` |
| **theme-color** | `<meta name="theme-color" content="...">` |
| **prefers-color-scheme** | 시스템 테마 감지 |
| **No Flash** | 테마 전환 시 깜빡임 방지 |

```tsx
// ✅ 테마 플래시 방지
<script
  dangerouslySetInnerHTML={{
    __html: `
      (function() {
        var theme = localStorage.getItem('theme') || 'light';
        document.documentElement.setAttribute('data-theme', theme);
      })();
    `,
  }}
/>
```

---

## 📋 확장된 체크리스트

### UX 감사 시 추가 확인 사항

```yaml
Touch & Mobile:
  - [ ] 터치 영역 최소 24x24px (권장 44x44px)
  - [ ] tap-highlight 비활성화
  - [ ] passive event listeners 사용

i18n:
  - [ ] Intl.DateTimeFormat 사용
  - [ ] Intl.NumberFormat 사용
  - [ ] 하드코딩된 날짜/숫자 포맷 없음

Performance:
  - [ ] 외부 도메인 preconnect
  - [ ] 긴 리스트 가상화
  - [ ] content-visibility 적용

Navigation:
  - [ ] 필터/탭 상태 URL 반영
  - [ ] 뒤로가기 정상 동작
  - [ ] 딥링크 지원

Dark Mode:
  - [ ] color-scheme 메타태그
  - [ ] 테마 전환 깜빡임 없음
```

---

## 📊 Industry Benchmarks (산업 기준값)

> 상세: `@.claude/guides/INDUSTRY_DESIGN_BENCHMARKS.md`

### Enterprise AI SaaS 목표 (Top 25%)

| 영역 | 업계 평균 | **목표 (Top 25%)** | Top 10% |
|------|:---------:|:------------------:|:-------:|
| Nielsen Heuristics | 68/100 | **82/100** | 92/100 |
| WCAG 2.2 AA | 72/100 | **88/100** | 96/100 |
| UX Writing | 65/100 | **80/100** | 90/100 |
| Cognitive Load | 5.8/10 | **7.5/10** | 8.8/10 |

### 감사 시 산업 데이터 활용법

1. **AS-IS → TO-BE 근거 강화**: "업계 Top 25%는 이 수치를 달성" 인용
2. **색상/타이포 평가**: 벤치마크 팔레트(blue-600, orange-500)와 비교
3. **Anti-Pattern 식별**: 산업별 금지 목록(네온, 과도한 그라데이션) 참조
4. **Verbalized Sampling**: BLACKLIST에 산업 뻔한 패턴 추가
5. **차트 제안**: 데이터 유형별 최적 차트 추천

### 활용 워크플로우

```
ux-master-auditor 시작
    ↓
Tier 0: INDUSTRY_DESIGN_BENCHMARKS.md 로드
    ↓ (산업 기준값 + 색상/폰트/스타일 + Anti-Pattern)
    ↓
Tier 1-4: 병렬 감사 (기준값 참조하여 평가)
    ↓
Tier 5: Diverge (산업 BLACKLIST 적용)
    ↓
종합 리포트: 업계 평균 vs 현재 점수 비교 포함
```

---

_Version: 1.2 - UX Audit System Guide (Industry Benchmarks 통합)_
