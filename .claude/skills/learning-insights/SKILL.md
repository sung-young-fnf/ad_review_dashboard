---
name: learning-insights
description: "Self-Improving Agent 학습 인사이트 대시보드 — HTML 보고서 자동 생성 + 브라우저 열기"
effort: medium
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
context: fork
user-invocable: true
---

# /learning-insights — Self-Improving Agent 대시보드

> Agent 학습 루프의 에러/교정/승격/건강도를 분석하고, 차트 포함 HTML 보고서를 생성하여 브라우저에서 바로 열어준다.

## 실행 조건

- `/learning-insights` 호출 시
- "학습 현황", "에이전트 인사이트", "learning dashboard" 등 요청 시

## 워크플로우

### Step 1: 데이터 수집

`.claude/learnings/` 디렉토리의 4개 파일에서 데이터 수집:

```
ERRORS.md      → Agent별 에러 횟수, 에러 유형, 시간대
LEARNINGS.md   → 사용자 교정 내역, 카테고리, Count, Confidence, Promoted 상태
CHANGELOG.md   → Agent별 변경 이력, 커밋 매핑
IMPROVEMENTS.md → 개선 항목 및 완료 상태
```

추가 데이터:
```bash
# 최근 30일 Agent 커밋 통계
git log --oneline --since="30 days ago" --grep="\[agent:"

# Learning Loop 건강도 (5개 컴포넌트)
# 1. ERRORS.md 존재
# 2. LEARNINGS.md 존재
# 3. Retrieval Hook 활성 (subagent-start.sh inject_learnings)
# 4. Correction Detector 활성 (user-correction-detector.sh)
# 5. Repeat Detection 활성 (self-improve-recorder.sh detect_repeats_and_promote)
```

### Step 2: 지표 계산

4개 핵심 지표:

| 지표 | 공식 | 목표 |
|------|------|------|
| Error Recurrence Rate | (재발 에러) / (전체 에러) × 100% | < 10% |
| Correction Decay | (이번 주 교정) / (지난 주 교정) × 100% | < 80% |
| Rule Promotion Ratio | (승격 규칙) / (전체 규칙) × 100% | > 30% |
| Health Score | 5개 컴포넌트 활성 여부 | 5/5 |

### Step 3: 차트 생성 (matplotlib → base64 PNG)

Python 스크립트로 4개 차트 생성:

1. **Agent별 에러 분포** — 가로 바 차트 (ERRORS.md 파싱)
2. **교정 카테고리 분포** — 도넛 차트 (LEARNINGS.md 파싱)
3. **학습 타임라인** — 라인 차트 (날짜별 에러/교정 추이)
4. **Rule Promotion 파이프라인** — 퍼널 차트 (none → suggested → promoted)

```python
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import base64
from io import BytesIO

# 한글 폰트 (macOS)
plt.rcParams['font.family'] = ['Apple SD Gothic Neo', 'Noto Sans CJK KR', 'sans-serif']
plt.rcParams['axes.unicode_minus'] = False

# 색상 팔레트
COLORS = {
  'primary': '#2196F3',
  'success': '#4CAF50',
  'warning': '#FF9800',
  'danger': '#F44336',
  'purple': '#9C27B0',
  'bg': '#F5F5F5'
}
```

### Step 4: HTML 보고서 생성

생성된 차트를 base64로 임베딩한 HTML 파일을 `.claude/learnings/report.html`에 저장.

HTML 구조:

```html
<!-- INSIGHTS_REPORT -->
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>Self-Improving Agent Insights</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, 'Apple SD Gothic Neo', sans-serif;
      background: #0f172a; color: #e2e8f0;
      min-height: 100vh; padding: 2rem;
    }
    .container { max-width: 1200px; margin: 0 auto; }

    /* 헤더 */
    .header { text-align: center; margin-bottom: 3rem; }
    .header h1 {
      font-size: 2.5rem; font-weight: 800;
      background: linear-gradient(135deg, #60a5fa, #a78bfa);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .header .subtitle { color: #94a3b8; font-size: 0.9rem; margin-top: 0.5rem; }

    /* 메트릭 카드 그리드 */
    .metrics { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1.5rem; margin-bottom: 3rem; }
    .metric-card {
      background: #1e293b; border-radius: 16px; padding: 1.5rem;
      border: 1px solid #334155; position: relative; overflow: hidden;
    }
    .metric-card::before {
      content: ''; position: absolute; top: 0; left: 0; right: 0; height: 3px;
    }
    .metric-card.blue::before { background: linear-gradient(90deg, #3b82f6, #60a5fa); }
    .metric-card.green::before { background: linear-gradient(90deg, #22c55e, #4ade80); }
    .metric-card.orange::before { background: linear-gradient(90deg, #f59e0b, #fbbf24); }
    .metric-card.purple::before { background: linear-gradient(90deg, #8b5cf6, #a78bfa); }
    .metric-value { font-size: 2.5rem; font-weight: 800; margin: 0.5rem 0; }
    .metric-label { font-size: 0.85rem; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; }
    .metric-target { font-size: 0.75rem; color: #64748b; margin-top: 0.5rem; }

    /* 차트 섹션 */
    .charts { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1.5rem; margin-bottom: 3rem; }
    .chart-card {
      background: #1e293b; border-radius: 16px; padding: 1.5rem;
      border: 1px solid #334155;
    }
    .chart-card h3 { font-size: 1.1rem; margin-bottom: 1rem; color: #f1f5f9; }
    .chart-card img { width: 100%; border-radius: 8px; }

    /* 테이블 */
    .detail-section {
      background: #1e293b; border-radius: 16px; padding: 1.5rem;
      border: 1px solid #334155; margin-bottom: 1.5rem;
    }
    .detail-section h3 { font-size: 1.1rem; margin-bottom: 1rem; color: #f1f5f9; }
    table { width: 100%; border-collapse: collapse; }
    th { background: #334155; color: #94a3b8; text-align: left; padding: 0.75rem 1rem; font-size: 0.8rem; text-transform: uppercase; }
    td { padding: 0.75rem 1rem; border-bottom: 1px solid #334155; font-size: 0.9rem; }

    /* 건강도 바 */
    .health-bar { display: flex; gap: 0.5rem; margin-top: 1rem; }
    .health-dot { width: 24px; height: 24px; border-radius: 50%; }
    .health-dot.active { background: #22c55e; box-shadow: 0 0 8px #22c55e55; }
    .health-dot.inactive { background: #334155; }

    /* 프로모션 파이프라인 */
    .pipeline { display: flex; align-items: center; gap: 0; margin: 1rem 0; }
    .pipeline-stage {
      flex: 1; text-align: center; padding: 1rem;
      clip-path: polygon(0 0, 90% 0, 100% 50%, 90% 100%, 0 100%, 10% 50%);
    }
    .pipeline-stage:first-child { clip-path: polygon(0 0, 90% 0, 100% 50%, 90% 100%, 0 100%); }
    .pipeline-stage .count { font-size: 1.5rem; font-weight: 700; }
    .pipeline-stage .label { font-size: 0.75rem; color: #94a3b8; }

    /* 반응형 */
    @media (max-width: 768px) {
      .metrics { grid-template-columns: repeat(2, 1fr); }
      .charts { grid-template-columns: 1fr; }
    }

    /* 인쇄 */
    @media print {
      body { background: white; color: #333; padding: 10mm; }
      .metric-card, .chart-card, .detail-section { border: 1px solid #ddd; }
    }

    /* 푸터 */
    .footer { text-align: center; color: #475569; font-size: 0.8rem; margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #334155; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Self-Improving Agent Insights</h1>
      <div class="subtitle">Generated: {날짜} | Project: mcp-orch</div>
    </div>

    <!-- 4개 메트릭 카드 -->
    <div class="metrics">
      <div class="metric-card blue">
        <div class="metric-label">Total Errors</div>
        <div class="metric-value">{total_errors}</div>
        <div class="metric-target">에러 재발률 목표: < 10%</div>
      </div>
      <div class="metric-card green">
        <div class="metric-label">Corrections</div>
        <div class="metric-value">{total_corrections}</div>
        <div class="metric-target">주간 감소율 목표: 20%+</div>
      </div>
      <div class="metric-card orange">
        <div class="metric-label">Promotion Rate</div>
        <div class="metric-value">{promotion_rate}%</div>
        <div class="metric-target">규칙 승격률 목표: > 30%</div>
      </div>
      <div class="metric-card purple">
        <div class="metric-label">Health Score</div>
        <div class="metric-value">{health}/5</div>
        <div class="metric-target">
          <div class="health-bar">
            <!-- 5개 dot -->
          </div>
        </div>
      </div>
    </div>

    <!-- 차트 2x2 그리드 -->
    <div class="charts">
      <div class="chart-card"><h3>Agent별 에러 분포</h3><img src="data:image/png;base64,{chart1}"></div>
      <div class="chart-card"><h3>교정 카테고리</h3><img src="data:image/png;base64,{chart2}"></div>
      <div class="chart-card"><h3>학습 타임라인</h3><img src="data:image/png;base64,{chart3}"></div>
      <div class="chart-card"><h3>Rule Promotion 파이프라인</h3><img src="data:image/png;base64,{chart4}"></div>
    </div>

    <!-- 상세 테이블 -->
    <div class="detail-section">
      <h3>최근 에러 기록</h3>
      <table>
        <tr><th>날짜</th><th>Agent</th><th>에러</th><th>커밋</th></tr>
        <!-- 동적 생성 -->
      </table>
    </div>

    <div class="detail-section">
      <h3>사용자 교정 기록</h3>
      <table>
        <tr><th>날짜</th><th>카테고리</th><th>트리거</th><th>규칙</th><th>Count</th><th>상태</th></tr>
        <!-- 동적 생성 -->
      </table>
    </div>

    <div class="detail-section">
      <h3>Rule Promotion 후보</h3>
      <table>
        <tr><th>규칙</th><th>반복 횟수</th><th>Confidence</th><th>제안 위치</th></tr>
        <!-- Count 3+ 항목만 -->
      </table>
    </div>

    <div class="footer">
      Self-Improving Agent Learning Loop v1.0 — Powered by Claude Code
    </div>
  </div>
</body>
</html>
```

### Step 5: 브라우저에서 열기

```bash
# HTML 파일 저장 후 브라우저 자동 열기
open .claude/learnings/report.html    # macOS
# xdg-open .claude/learnings/report.html  # Linux
```

## 실행 순서 (필수)

1. `Read` — ERRORS.md, LEARNINGS.md, CHANGELOG.md, IMPROVEMENTS.md 읽기
2. `Bash` — git log 통계 수집
3. 지표 계산 (재발률, 감소율, 승격률, 건강도)
4. `Bash` — Python matplotlib 스크립트 실행하여 4개 차트를 base64 PNG로 생성
5. HTML 템플릿에 데이터 + 차트 삽입
6. `Write` — `.claude/learnings/report.html` 저장
7. `Bash` — `open .claude/learnings/report.html` 실행
8. 사용자에게 핵심 인사이트 요약 출력

## 차트 생성 Python 스크립트

실행 시 아래 패턴을 기반으로 4개 차트를 한 번에 생성하는 Python 스크립트를 작성한다.
`/tmp/insights_charts.py`에 저장 후 `python3 /tmp/insights_charts.py`로 실행.

스크립트는 4개 차트의 base64 문자열을 JSON으로 stdout에 출력한다:
```json
{
  "chart1": "base64...",
  "chart2": "base64...",
  "chart3": "base64...",
  "chart4": "base64..."
}
```

차트 스타일:
- 다크 테마 배경 (`#1e293b`) — HTML 보고서 배경과 통일
- 글자 색상: `#e2e8f0`
- 그리드: `#334155`
- 악센트 색상: `#3b82f6`, `#22c55e`, `#f59e0b`, `#8b5cf6`

## 제약 사항

- 없는 데이터를 추론하지 말 것 — 빈 파일이면 "데이터 없음" 표시
- matplotlib 없으면 차트 없이 HTML만 생성 (텍스트 기반 통계)
- HTML 파일은 항상 `.claude/learnings/report.html`에 덮어쓰기
- 생성 후 반드시 `open` 명령으로 브라우저 열기
