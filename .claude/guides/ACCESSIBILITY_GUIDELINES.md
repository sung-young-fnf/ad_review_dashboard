# Accessibility Guidelines (접근성 가이드라인)

> **프로젝트**: okr2 (autumn_template)
> **기준**: WCAG 2.1 Level AA
> **목적**: 모든 사용자가 접근 가능한 웹 애플리케이션 구축

---

## 🎯 핵심 원칙 (POUR)

### 1. Perceivable (인지 가능)
사용자가 정보를 인지할 수 있어야 함

### 2. Operable (작동 가능)
사용자가 UI 컴포넌트를 조작할 수 있어야 함

### 3. Understandable (이해 가능)
정보와 UI 작동 방식이 이해 가능해야 함

### 4. Robust (견고성)
다양한 보조 기술에서 작동해야 함

---

## ♿ WCAG 2.1 Level AA 준수 사항

### 1. Color Contrast (색상 대비)

#### 최소 대비율
```yaml
Normal Text (18pt 미만):
  - 최소 비율: 4.5:1
  - 예시: #212121 (text) on #FFFFFF (bg) = 16.1:1 ✅

Large Text (18pt+ 또는 14pt+ bold):
  - 최소 비율: 3.0:1
  - 예시: #616161 (text) on #FFFFFF (bg) = 7.0:1 ✅

UI Components (버튼, 입력 필드 등):
  - 최소 비율: 3.0:1
  - 예시: Border color vs Background
```

#### 자동 검증 방법
```typescript
// shared/utils/accessibility/colorContrast.ts
export function getContrastRatio(color1: string, color2: string): number {
  const l1 = getLuminance(color1);
  const l2 = getLuminance(color2);
  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

export function meetsWCAG_AA(ratio: number, isLargeText: boolean): boolean {
  return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
}

// 사용 예시
const ratio = getContrastRatio('#212121', '#FFFFFF');
const passes = meetsWCAG_AA(ratio, false); // true
```

#### Chrome DevTools Lighthouse 활용
```bash
# ui-tester에서 자동 실행
lighthouse http://localhost:3001 \
  --only-categories=accessibility \
  --output=json \
  --output-path=./test-results/accessibility-report.json
```

---

### 2. Keyboard Navigation (키보드 탐색)

#### 필수 구현 사항

**Focus Indicator (포커스 표시)**:
```css
/* 모든 인터랙티브 요소에 필수 */
button:focus,
a:focus,
input:focus,
select:focus,
textarea:focus {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
}

/* 또는 Custom Focus Ring */
.custom-focus:focus {
  outline: none;
  box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.3);
}
```

**Tab Order (탭 순서)**:
```tsx
// ✅ 올바른 탭 순서 (tabIndex 불필요)
<form>
  <input type="text" name="email" />
  <input type="password" name="password" />
  <button type="submit">로그인</button>
</form>

// ❌ 잘못된 탭 순서 (tabIndex 남용)
<div tabIndex={1}>첫 번째</div>
<div tabIndex={3}>세 번째</div>
<div tabIndex={2}>두 번째</div>
```

**Keyboard Shortcuts (키보드 단축키)**:
```typescript
// shared/hooks/useKeyboardShortcut.ts
export function useKeyboardShortcut(
  key: string,
  callback: () => void,
  options?: { ctrl?: boolean; shift?: boolean }
) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === key) {
        if (options?.ctrl && !e.ctrlKey) return;
        if (options?.shift && !e.shiftKey) return;
        e.preventDefault();
        callback();
      }
    };

    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [key, callback, options]);
}

// 사용 예시
useKeyboardShortcut('Escape', () => closeModal());
useKeyboardShortcut('s', () => saveForm(), { ctrl: true });
```

**Skip Links (스킵 링크)**:
```tsx
// app/layout.tsx
export default function RootLayout({ children }) {
  return (
    <html lang="ko">
      <body>
        <a href="#main-content" className="skip-link">
          본문으로 건너뛰기
        </a>
        <Header />
        <main id="main-content">{children}</main>
      </body>
    </html>
  );
}
```

```css
/* Skip Link 스타일 */
.skip-link {
  position: absolute;
  left: -9999px;
  z-index: 9999;
  padding: var(--spacing-sm) var(--spacing-md);
  background-color: var(--color-primary-500);
  color: var(--color-neutral-0);
}

.skip-link:focus {
  left: 0;
  top: 0;
}
```

---

### 3. Screen Reader (스크린 리더)

#### Alt Text (대체 텍스트)
```tsx
// ✅ 의미 있는 이미지
<img src="/profile.jpg" alt="김철수님의 프로필 사진" />

// ✅ 장식용 이미지
<img src="/bg-pattern.png" alt="" role="presentation" />

// ❌ 잘못된 예
<img src="/profile.jpg" alt="이미지" />
<img src="/profile.jpg" /> {/* alt 누락 */}
```

#### ARIA Labels
```tsx
// 버튼에 명확한 레이블 제공
<button aria-label="알림 닫기" onClick={closeNotification}>
  <X size={16} />
</button>

// 폼 입력 필드
<input
  type="text"
  aria-label="이메일 주소"
  aria-required="true"
  aria-invalid={!!error}
  aria-describedby="email-error"
/>
{error && (
  <span id="email-error" role="alert">
    {error}
  </span>
)}

// 네비게이션
<nav aria-label="주요 네비게이션">
  <ul>
    <li><a href="/home">홈</a></li>
    <li><a href="/about">소개</a></li>
  </ul>
</nav>
```

#### Semantic HTML
```tsx
// ✅ 시맨틱 HTML 사용
<header>
  <nav aria-label="주요 메뉴">...</nav>
</header>
<main>
  <article>
    <h1>제목</h1>
    <section>
      <h2>부제목</h2>
      <p>본문...</p>
    </section>
  </article>
</main>
<footer>...</footer>

// ❌ Non-semantic HTML (피해야 함)
<div className="header">
  <div className="nav">...</div>
</div>
<div className="main">
  <div className="article">
    <div className="title">제목</div>
    <div className="section">...</div>
  </div>
</div>
```

#### Heading Hierarchy (제목 계층)
```tsx
// ✅ 올바른 제목 계층 (순차적)
<h1>페이지 제목</h1>
<h2>섹션 1</h2>
<h3>섹션 1-1</h3>
<h3>섹션 1-2</h3>
<h2>섹션 2</h2>

// ❌ 잘못된 제목 계층 (h2 → h4)
<h1>페이지 제목</h1>
<h2>섹션 1</h2>
<h4>섹션 1-1</h4> {/* h3 누락 */}
```

---

### 4. Motion & Animation (움직임)

#### prefers-reduced-motion 지원
```css
/* 기본 애니메이션 */
.card {
  transition: transform 200ms ease-out;
}

.card:hover {
  transform: translateY(-4px);
}

/* 움직임 축소 설정 시 애니메이션 비활성화 */
@media (prefers-reduced-motion: reduce) {
  .card {
    transition: none;
  }

  .card:hover {
    transform: none;
  }
}
```

#### React Hook 구현
```typescript
// shared/hooks/usePrefersReducedMotion.ts
export function usePrefersReducedMotion(): boolean {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    setPrefersReducedMotion(mediaQuery.matches);

    const handler = (e: MediaQueryListEvent) => {
      setPrefersReducedMotion(e.matches);
    };

    mediaQuery.addEventListener('change', handler);
    return () => mediaQuery.removeEventListener('change', handler);
  }, []);

  return prefersReducedMotion;
}

// 사용 예시
const Card = () => {
  const reducedMotion = usePrefersReducedMotion();

  return (
    <div
      className="card"
      style={{
        transition: reducedMotion ? 'none' : 'transform 200ms ease-out'
      }}
    >
      ...
    </div>
  );
};
```

---

## 🧩 접근성 컴포넌트 패턴

### 1. 접근 가능한 모달 (Accessible Modal)

```tsx
// widgets/Modal/Modal.tsx
import { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}

export const Modal = ({ isOpen, onClose, title, children }: ModalProps) => {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousActiveElement = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      // 이전 포커스 저장
      previousActiveElement.current = document.activeElement as HTMLElement;

      // Body 스크롤 방지
      document.body.style.overflow = 'hidden';

      // 모달 내부로 포커스 이동
      modalRef.current?.focus();

      // 스크린 리더에 알림
      announce(`${title} 다이얼로그가 열렸습니다`);
    }

    return () => {
      // Body 스크롤 복원
      document.body.style.overflow = 'unset';

      // 이전 포커스 복원
      previousActiveElement.current?.focus();
    };
  }, [isOpen, title]);

  // Escape 키로 닫기
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return createPortal(
    <div className="modal-overlay" onClick={onClose}>
      <div
        ref={modalRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
        className="modal-content"
        onClick={(e) => e.stopPropagation()}
        tabIndex={-1}
      >
        <header className="modal-header">
          <h2 id="modal-title">{title}</h2>
          <button
            aria-label="다이얼로그 닫기"
            onClick={onClose}
            className="modal-close"
          >
            ×
          </button>
        </header>
        <div className="modal-body">{children}</div>
      </div>
    </div>,
    document.body
  );
};

// 스크린 리더 알림 유틸리티
function announce(message: string) {
  const liveRegion = document.createElement('div');
  liveRegion.setAttribute('role', 'status');
  liveRegion.setAttribute('aria-live', 'polite');
  liveRegion.setAttribute('aria-atomic', 'true');
  liveRegion.style.position = 'absolute';
  liveRegion.style.left = '-9999px';
  liveRegion.textContent = message;

  document.body.appendChild(liveRegion);
  setTimeout(() => document.body.removeChild(liveRegion), 1000);
}
```

---

### 2. 접근 가능한 탭 (Accessible Tabs)

```tsx
// widgets/Tabs/Tabs.tsx
interface Tab {
  id: string;
  label: string;
  content: React.ReactNode;
}

interface TabsProps {
  tabs: Tab[];
  defaultTabId?: string;
}

export const Tabs = ({ tabs, defaultTabId }: TabsProps) => {
  const [activeTabId, setActiveTabId] = useState(defaultTabId || tabs[0].id);

  const handleKeyDown = (e: React.KeyboardEvent, index: number) => {
    if (e.key === 'ArrowRight') {
      e.preventDefault();
      const nextIndex = (index + 1) % tabs.length;
      setActiveTabId(tabs[nextIndex].id);
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault();
      const prevIndex = (index - 1 + tabs.length) % tabs.length;
      setActiveTabId(tabs[prevIndex].id);
    }
  };

  return (
    <div className="tabs">
      <div role="tablist" aria-label="탭 메뉴">
        {tabs.map((tab, index) => (
          <button
            key={tab.id}
            role="tab"
            id={`tab-${tab.id}`}
            aria-selected={activeTabId === tab.id}
            aria-controls={`panel-${tab.id}`}
            tabIndex={activeTabId === tab.id ? 0 : -1}
            onClick={() => setActiveTabId(tab.id)}
            onKeyDown={(e) => handleKeyDown(e, index)}
          >
            {tab.label}
          </button>
        ))}
      </div>
      {tabs.map((tab) => (
        <div
          key={tab.id}
          role="tabpanel"
          id={`panel-${tab.id}`}
          aria-labelledby={`tab-${tab.id}`}
          hidden={activeTabId !== tab.id}
          tabIndex={0}
        >
          {tab.content}
        </div>
      ))}
    </div>
  );
};
```

---

## 🧪 자동 검증 방법 (ui-tester 통합)

### 1. Lighthouse CI 자동화

```typescript
// .claude/agents/04-implementation/ui-tester.md에서 사용
async function runAccessibilityCheck(url: string) {
  const result = await lighthouse(url, {
    onlyCategories: ['accessibility'],
    output: 'json'
  });

  const score = result.lhr.categories.accessibility.score * 100;
  const audits = result.lhr.audits;

  const issues = [];
  for (const [id, audit] of Object.entries(audits)) {
    if (audit.score < 1) {
      issues.push({
        id,
        title: audit.title,
        description: audit.description,
        severity: audit.score === 0 ? 'high' : 'medium'
      });
    }
  }

  return { score, issues };
}
```

### 2. Chrome DevTools 수동 검증

```bash
# ui-tester에서 실행
mcp__chrome-devtools__evaluate_script({
  function: `() => {
    // Color Contrast 체크
    const elements = document.querySelectorAll('*');
    const contrastIssues = [];

    elements.forEach(el => {
      const style = window.getComputedStyle(el);
      const color = style.color;
      const bgColor = style.backgroundColor;

      if (color && bgColor) {
        const ratio = getContrastRatio(color, bgColor);
        if (ratio < 4.5) {
          contrastIssues.push({
            element: el.tagName,
            color,
            bgColor,
            ratio
          });
        }
      }
    });

    return contrastIssues;
  }`
});
```

---

## ✅ Acceptance Criteria 체크리스트

**code-writer가 UI 구현 시**:
- [ ] ARIA labels 추가 (button, input, nav 등)
- [ ] Semantic HTML 사용 (header, main, nav, article, section)
- [ ] Keyboard navigation 지원 (focus, tabIndex)
- [ ] Color contrast 최소 4.5:1 (normal text)
- [ ] Alt text 제공 (이미지)
- [ ] Skip links 추가 (메인 콘텐츠로 건너뛰기)

**ui-tester가 검증 시**:
- [ ] Lighthouse Accessibility Score >= 90
- [ ] Color contrast 모든 요소 4.5:1 이상
- [ ] Keyboard navigation 모든 인터랙티브 요소 접근 가능
- [ ] Focus indicator 모든 요소 표시
- [ ] Screen reader 호환성 (ARIA labels, semantic HTML)
- [ ] prefers-reduced-motion 지원 (애니메이션 비활성화)

---

## 🚨 자주 발생하는 실수

### 1. ❌ div 버튼 사용
```tsx
// ❌ 잘못된 예
<div onClick={handleClick}>클릭</div>

// ✅ 올바른 예
<button onClick={handleClick}>클릭</button>
```

### 2. ❌ ARIA labels 누락
```tsx
// ❌ 잘못된 예
<button onClick={closeModal}>
  <X size={16} />
</button>

// ✅ 올바른 예
<button aria-label="모달 닫기" onClick={closeModal}>
  <X size={16} />
</button>
```

### 3. ❌ 낮은 색상 대비
```css
/* ❌ 잘못된 예 (1.8:1) */
color: #999999;
background-color: #FFFFFF;

/* ✅ 올바른 예 (7.0:1) */
color: #616161;
background-color: #FFFFFF;
```

### 4. ❌ 키보드 접근 불가
```tsx
// ❌ 잘못된 예 (div는 기본적으로 포커스 불가)
<div onClick={handleClick}>클릭</div>

// ✅ 올바른 예
<button onClick={handleClick}>클릭</button>
```

---

## 📚 참조

- **WCAG 2.1**: https://www.w3.org/WAI/WCAG21/quickref/
- **ARIA 가이드**: https://www.w3.org/WAI/ARIA/apg/
- **Lighthouse**: https://developer.chrome.com/docs/lighthouse
- **원본 가이드**: @.reference/uiuxagent/uiuxagent.md
- **UI Design System**: @docs/guides/ui-design-system.md

---

**버전**: 1.0.0
**작성일**: 2025-11-08
**유지보수**: UI/UX 팀
