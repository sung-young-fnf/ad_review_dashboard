---
name: visual-brainstorming
description: "기획/설계 단계 아이디어 시각적 소통 (Superpowers 5 패턴)"
effort: medium
---

# Visual Brainstorming Skill

> 출처: Superpowers 5 "Visual Brainstorming" 패턴 차용
> WHY: 기획/설계 단계에서 텍스트(Markdown)로만 소통 → 전체 그림 파악 어려움 → 오해 발생
> "ASCII art의 한계를 극복하고, 아이디어를 시각적으로 소통한다" — Jesse Vincent

## 트리거

사용자가 `/visual` 또는 `/brainstorm` 명령 시 실행.
또는 Planning/Design Squad에서 Epic 문서 완성 후 자동 실행.

## 핵심 개념

Agent가 Epic/Story/설계 문서를 기반으로 **시각적 요약 HTML**을 생성하고,
브라우저에서 즉시 확인할 수 있게 한다.

## 워크플로우

```
1. 대상 문서 읽기 (Epic/Story/설계 문서)
    ↓
2. 시각화 유형 결정
    ├─ 아키텍처: 컴포넌트 다이어그램 (Mermaid → HTML)
    ├─ 데이터 흐름: 시퀀스 다이어그램
    ├─ UI 와이어프레임: HTML mockup
    ├─ Story 의존성: 그래프 시각화
    └─ 비교 분석: 테이블/차트
    ↓
3. HTML 파일 생성 (docs/visuals/{name}.html)
    ↓
4. 브라우저에서 열기 (open 명령)
    ↓
5. 사용자 피드백 → 수정 반복
```

## 시각화 유형별 템플릿

### 1. 아키텍처 다이어그램

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>{Epic} - Architecture</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 2rem; background: #0d1117; color: #c9d1d9; }
    .container { max-width: 1200px; margin: 0 auto; }
    h1 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 0.5rem; }
    .mermaid { background: #161b22; border-radius: 8px; padding: 1rem; }
    .legend { display: flex; gap: 1rem; margin-top: 1rem; font-size: 0.9rem; }
    .legend-item { display: flex; align-items: center; gap: 0.5rem; }
    .dot { width: 12px; height: 12px; border-radius: 50%; }
  </style>
</head>
<body>
  <div class="container">
    <h1>{Title}</h1>
    <p>{Description}</p>
    <div class="mermaid">
      {mermaid_diagram}
    </div>
    <div class="legend">
      <!-- 범례 -->
    </div>
  </div>
  <script>mermaid.initialize({theme: 'dark'});</script>
</body>
</html>
```

### 2. UI 와이어프레임

```html
<!-- Tailwind CDN 활용, 실제 레이아웃 프로토타입 -->
<script src="https://cdn.tailwindcss.com"></script>
<!-- 인터랙션 없는 정적 mockup -->
```

### 3. Story 의존성 그래프

```html
<!-- D3.js force-directed graph -->
<script src="https://d3js.org/d3.v7.min.js"></script>
<!-- 노드: Story, 엣지: 의존성, 색상: 상태 -->
```

### 4. 비교 분석 대시보드

```html
<!-- Chart.js 활용 -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<!-- 테이블 + 바 차트 + 레이더 차트 -->
```

## 실행 규칙

### 파일 위치
```
docs/visuals/{epic_id}-{type}.html
docs/visuals/{topic}-comparison.html
```

### 브라우저 열기
```bash
# macOS
open docs/visuals/{name}.html

# 자동 열기 (생성 즉시)
```

### CDN 의존성 (오프라인 고려)
- Mermaid.js: 다이어그램
- Tailwind CSS: UI mockup
- D3.js: 그래프 시각화
- Chart.js: 차트

### .gitignore 설정 (필수 — 스킬 첫 실행 시 자동)
```bash
# docs/visuals/ HTML은 일회성 시각화 — Git 커밋 금지
if ! grep -q "docs/visuals/" .gitignore 2>/dev/null; then
  echo "" >> .gitignore
  echo "# Visual Brainstorming (일회성 시각화)" >> .gitignore
  echo "docs/visuals/*.html" >> .gitignore
fi
```

### 보안 규칙
- 로컬 파일만 (서버 불필요)
- 외부 API 호출 금지
- 사용자 데이터 포함 금지
- CDN 불가 환경: Mermaid/D3 인라인 번들 사용 (사내 네트워크 제한 시)

## Squad 연동

### Planning Squad에서 자동 실행
```
Planner: Epic 문서 완성
    ↓
Visual Brainstorming: 아키텍처 다이어그램 + Story 의존성 그래프 자동 생성
    ↓
사용자: 브라우저에서 확인 → "S03과 S05 합치자" 피드백
    ↓
Planner: 피드백 반영
```

### Gemini Delegate 활용 (권장)

**플로우 (Gemini는 읽기 전용 — Claude가 파일 작성)**:
```
1. Claude → Gemini delegate 위임:
   "Epic 문서를 기반으로 아키텍처 다이어그램 HTML 코드를 텍스트로 생성해줘"
2. Gemini → HTML 코드를 텍스트로 반환 (파일 작성 안 함)
3. Claude → 반환된 HTML 검증 + Write 도구로 docs/visuals/ 에 저장
4. Claude → `open docs/visuals/{name}.html` 실행
```
→ Gemini의 멀티모달 강점으로 더 풍부한 시각화 생성
→ Claude가 최종 검증 후 파일 저장 (CLAUDE.md 규칙 준수)

## 기존 패턴 활용

- `/learning-insights`: 이미 HTML 보고서 → `open` 명령으로 브라우저 오픈 패턴 사용 중
- `design-iterator`: 스크린샷 기반 반복 개선과 시너지 (Visual → 구현 → 스크린샷 검증)

## 제한사항

- 인증 필요한 페이지 접근 불가 (기존 Browser Automation 제한 준수)
- HTML은 일회성 시각화 목적 (프로덕션 코드 아님)
- Git에 커밋하지 않음 (.gitignore에 `docs/visuals/*.html` 추가 권장)
