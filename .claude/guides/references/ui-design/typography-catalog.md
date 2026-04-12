# Typography Catalog (상세)

> **상위 문서**: @.claude/guides/UI_DESIGN_SYSTEM.md
> **용도**: 폰트 선택 시 상세 참조

---

## 한글 폰트 상세 권장 목록

### SaaS/Tech 전용 (본문용)

| 폰트명 | 출처 | 특징 | 라이선스 |
|-------|------|------|---------|
| **Pretendard** | [GitHub](https://github.com/orioncactus/pretendard) | Apple SD Gothic Neo + Inter 장점 결합, Variable Font 지원 | OFL |
| **SUIT** | [GitHub](https://github.com/orioncactus/SUIT) | Pretendard 제작자가 만든 대안, 더 둥근 느낌 | OFL |
| **Noto Sans KR** | Google Fonts | 범용성 최고, 9가지 굵기 | OFL |
| **Spoqa Han Sans Neo** | [Spoqa](https://spoqa.github.io/spoqa-han-sans/) | 깔끔한 고딕, 숫자 가독성 우수 | OFL |

### Luxury/Elegant (제목/브랜딩용)

| 폰트명 | 출처 | 특징 | 라이선스 |
|-------|------|------|---------|
| **본명조 (Noto Serif KR)** | Google Fonts | Adobe/Google 공동 개발, Pan-CJK 세리프 | OFL |
| **마루부리** | 눈누 | 한국적 감성의 명조체, 고급스러운 느낌 | OFL |
| **KoPub Batang** | 한국출판인회의 | 가독성 좋은 본문용 명조체 | 무료 |

### Creative/Bold (마케팅용)

| 폰트명 | 출처 | 특징 | 라이선스 |
|-------|------|------|---------|
| **Gmarket Sans** | [Gmarket](https://corp.gmarket.com/fonts/) | 기하학적 디자인, Light/Medium/Bold 3가지 | OFL |
| **에스코어드림** | 눈누 | 9가지 굵기, 강렬하고 현대적 | 무료 |
| **여기어때 잘난체** | 눈누 | 귀엽고 친근한 타이틀용 | 무료 |
| **나눔스퀘어라운드** | 네이버 | 부드럽고 둥근 느낌 | OFL |

### Gaming/Futuristic

| 폰트명 | 출처 | 특징 | 라이선스 |
|-------|------|------|---------|
| **SF함박눈** | 눈누 | 미래지향적, 테크 느낌 | 무료 |
| **빛의계승자체** | 스마일게이트 | 게임 타이틀 느낌 | 무료 |
| **넥슨 Lv.1 고딕** | 넥슨 | 게임 UI 최적화 | OFL |

---

## 프로젝트 기본 폰트 설정 (globals.css)

```css
/* Spark Note 프로젝트 권장 설정 */
@import url('https://cdn.jsdelivr.net/gh/orioncactus/pretendard/dist/web/static/pretendard.css');

:root {
  --font-sans: 'Pretendard', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  --font-serif: 'Noto Serif KR', Georgia, serif;
  --font-display: 'Gmarket Sans', var(--font-sans);
}

body {
  font-family: var(--font-sans);
}

h1, h2, h3 {
  font-family: var(--font-display);
}
```

---

## 폰트 선택 가이드

```yaml
SaaS/B2B 프로젝트:
  본문: Pretendard (가독성 최우선)
  제목: Pretendard Bold 또는 Gmarket Sans Bold
  숫자/데이터: Pretendard (숫자 가독성 우수)

마케팅/랜딩 페이지:
  본문: Noto Sans KR
  제목: Gmarket Sans Bold 또는 에스코어드림
  포인트: 여기어때 잘난체 (CTA 버튼 등)

고급/브랜딩:
  본문: 본명조 (Noto Serif KR)
  제목: 마루부리 또는 KoPub Batang
  포인트: Playfair Display (영문 로고 등)
```

---

## CDN 링크 모음

```html
<!-- Pretendard (권장) -->
<link href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard/dist/web/static/pretendard.css" rel="stylesheet" />

<!-- Noto Sans KR (Google Fonts) -->
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet" />

<!-- Noto Serif KR (Google Fonts) -->
<link href="https://fonts.googleapis.com/css2?family=Noto+Serif+KR:wght@400;700&display=swap" rel="stylesheet" />

<!-- Gmarket Sans -->
<link href="https://cdn.jsdelivr.net/gh/webfontworld/gmarket/GmarketSans.css" rel="stylesheet" />
```

---

**버전**: 1.0.0
**작성일**: 2025-12-01
