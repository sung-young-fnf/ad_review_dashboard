---
name: report-generator
description: "MCP 데이터 기반 전문 보고서 생성 — 차트 포함 HTML 아티팩트 + PDF/DOCX 다운로드"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch, WebSearch, mcp__*
user-invocable: true
context: fork
effort: medium
---

# Report Generator

> MCP 도구로 데이터를 수집하고, matplotlib 차트를 포함한 전문 보고서를 HTML 아티팩트로 생성한다.
> 프론트엔드에서 PDF/DOCX 다운로드를 지원한다.

## WHY

보고서 품질은 "포맷"이 아니라 "워크플로우"가 결정한다.
데이터 수집 → 수치 도출 → 차트 생성 → 문서 조립 파이프라인을 강제하면,
LLM이 대충 텍스트로 끝내지 못하고 깊은 분석을 수행하게 된다.

## 실행 조건

- 사용자가 "보고서", "리포트", "분석 보고서", "진단 보고서" 등을 요청할 때
- MCP 도구로 접근 가능한 데이터 소스가 있을 때
- `/report-generator` 직접 호출 시

## 5-Step 워크플로우 (반드시 이 순서를 따를 것)

### Step 1: 데이터 수집 (MCP 도구 호출)

**목표**: 보고서에 필요한 원시 데이터를 MCP에서 수집

1. 사용자 요청에서 분석 대상과 범위를 파악
2. 사용 가능한 MCP 도구를 확인 (어떤 데이터에 접근 가능한지)
3. MCP 도구를 호출하여 원시 데이터 수집
4. 수집한 데이터를 구조화된 형태로 정리

**주의**:
- 없는 데이터를 추론하거나 가정하지 말 것
- MCP에서 얻을 수 없는 데이터는 "데이터 미확보"로 명시
- 가능한 모든 관련 MCP 도구를 호출하여 교차 검증

### Step 2: 분석 프레임워크 적용

**목표**: 수집 데이터에 적절한 분석 프레임워크를 적용하여 인사이트 도출

프레임워크 선택 (요청 유형에 따라):
- **개발 생산성**: DORA 4 Metrics + SPACE Framework
- **조직 구조**: Team Topologies (4팀 유형 + 3 인터랙션 모드)
- **프로세스**: Value Stream Mapping (대기 시간 vs 작업 시간)
- **운영 효율**: Toil 분석 (Google SRE)
- **일반 분석**: 적절한 프레임워크 선택

**출력**: 수치화된 분석 결과 (예: Toil 52%, 리드타임 30일, 변경실패율 15%)

### Step 3: 차트 생성 (matplotlib → base64 PNG)

**목표**: 분석 결과를 시각화한 차트를 base64 인코딩된 PNG로 생성

Python 스크립트를 Bash로 실행하여 차트 생성:

```python
import matplotlib
matplotlib.use('Agg')  # 반드시 맨 위에
import matplotlib.pyplot as plt
import base64
from io import BytesIO

# 한글 폰트 설정 (sandbox에 Noto Sans CJK 설치됨)
plt.rcParams['font.family'] = 'Noto Sans CJK KR'
plt.rcParams['axes.unicode_minus'] = False

# 차트 생성 (예시)
fig, ax = plt.subplots(figsize=(10, 6))
ax.bar(['항목1', '항목2', '항목3'], [30, 50, 20])
ax.set_title('분석 결과')

# base64로 인코딩
buf = BytesIO()
fig.savefig(buf, format='png', dpi=150, bbox_inches='tight', facecolor='white')
buf.seek(0)
b64 = base64.b64encode(buf.read()).decode('utf-8')
plt.close(fig)

print(f'<img src="data:image/png;base64,{b64}" style="max-width:100%;">')
```

**차트 유형 가이드**:
| 데이터 유형 | 추천 차트 | matplotlib 함수 |
|------------|----------|----------------|
| 비율/구성 | 도넛/파이 | `ax.pie(wedgeprops={'width':0.4})` |
| 시계열 추이 | 라인 | `ax.plot()` |
| 비교 | 가로 바 | `ax.barh()` |
| 프로세스 흐름 | 스택 바 (Value Stream) | `ax.barh(stacked=True)` |
| 의존성 매트릭스 | 히트맵 | `ax.imshow() + annotate` |
| 로드맵 | 간트 | `ax.broken_barh()` |

**차트 스타일 규칙**:
- 색상: 전문적인 톤 사용 (`#2196F3`, `#4CAF50`, `#FF9800`, `#F44336`, `#9C27B0`)
- 폰트 크기: 제목 14pt, 라벨 11pt, 주석 9pt
- 여백: `bbox_inches='tight'`로 여백 최적화
- DPI: 150 (인쇄 품질)

### Step 4: HTML 보고서 조립

**목표**: 차트와 분석 내용을 결합한 HTML 문서 생성

HTML 아티팩트를 생성한다. 반드시 아래 구조를 따를 것:

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <style>
    /* A4 최적화 스타일 */
    body { font-family: -apple-system, 'Noto Sans KR', sans-serif; max-width: 210mm; margin: 0 auto; padding: 20mm; color: #333; line-height: 1.8; }
    h1 { font-size: 24pt; border-bottom: 3px solid #2196F3; padding-bottom: 8px; }
    h2 { font-size: 16pt; color: #1565C0; margin-top: 2em; }
    h3 { font-size: 13pt; color: #424242; }
    table { border-collapse: collapse; width: 100%; margin: 1em 0; }
    th { background: #E3F2FD; font-weight: 600; }
    th, td { border: 1px solid #BBDEFB; padding: 10px 14px; text-align: left; }
    .metric-card { display: inline-block; width: 22%; margin: 1%; padding: 16px; border-radius: 8px; background: #F5F5F5; text-align: center; }
    .metric-value { font-size: 28pt; font-weight: 700; color: #1565C0; }
    .metric-label { font-size: 10pt; color: #757575; }
    .chart-container { margin: 1.5em 0; text-align: center; }
    .chart-container img { max-width: 100%; border: 1px solid #E0E0E0; border-radius: 4px; }
    .insight-box { background: #FFF3E0; border-left: 4px solid #FF9800; padding: 12px 16px; margin: 1em 0; }
    .recommendation { background: #E8F5E9; border-left: 4px solid #4CAF50; padding: 12px 16px; margin: 1em 0; }
    .risk { background: #FFEBEE; border-left: 4px solid #F44336; padding: 12px 16px; margin: 1em 0; }
    @media print { body { padding: 10mm; } .page-break { page-break-before: always; } }
  </style>
</head>
<body>
  <!-- 보고서 제목 -->
  <h1>{보고서 제목}</h1>
  <p style="color:#757575;">작성일: {날짜} | 분석 범위: {범위}</p>

  <!-- Executive Summary -->
  <h2>Executive Summary</h2>
  <div style="display:flex; flex-wrap:wrap;">
    <div class="metric-card">
      <div class="metric-value">{핵심 수치}</div>
      <div class="metric-label">{지표명}</div>
    </div>
    <!-- 3-4개 핵심 지표 카드 -->
  </div>

  <!-- 각 섹션: 분석 + 차트 -->
  <h2>{섹션 제목}</h2>
  <p>{분석 내용}</p>
  <div class="chart-container">
    <img src="data:image/png;base64,{chart_base64}" alt="{차트 설명}">
  </div>

  <!-- 인사이트/권장사항 박스 -->
  <div class="insight-box">
    <strong>인사이트:</strong> {핵심 발견}
  </div>
  <div class="recommendation">
    <strong>권장사항:</strong> {개선 제안}
  </div>

  <!-- 로드맵/실행 계획 -->
  <h2>실행 로드맵</h2>
  <!-- 간트 차트 또는 타임라인 -->

  <!-- 성공 지표 -->
  <h2>성공 지표 (KPI)</h2>
  <table>
    <tr><th>지표</th><th>현재</th><th>목표</th><th>기한</th></tr>
    <!-- KPI 행 -->
  </table>
</body>
</html>
```

### Step 5: 아티팩트로 출력

**목표**: 생성된 HTML을 채팅 아티팩트로 전달

1. 조립된 HTML 전체를 하나의 코드블록으로 출력
2. `<!-- REPORT_ARTIFACT -->` 마커를 HTML 첫 줄에 추가 (프론트엔드 감지용)
3. 사용자에게 "PDF 다운로드" 안내

```
출력 형식:
\`\`\`html
<!-- REPORT_ARTIFACT -->
<!DOCTYPE html>
...전체 HTML...
\`\`\`
```

## 차트 생성 패턴 라이브러리

### 패턴 1: DORA 메트릭 대시보드 (4 카드)
```python
metrics = {
    '배포 빈도': {'value': '주 2회', 'grade': 'Medium', 'color': '#FF9800'},
    '리드 타임': {'value': '15일', 'grade': 'Low', 'color': '#F44336'},
    '변경 실패율': {'value': '12%', 'grade': 'Medium', 'color': '#FF9800'},
    'MTTR': {'value': '4시간', 'grade': 'High', 'color': '#4CAF50'},
}
```

### 패턴 2: Value Stream Map (대기 vs 작업)
```python
stages = ['요청 접수', '분석', '개발', '리뷰', '테스트', '배포']
wait_times = [2, 3, 0, 2, 1, 0.5]  # 대기 시간 (일)
work_times = [0.5, 1, 3, 0.5, 1, 0.2]  # 작업 시간 (일)
# stacked barh로 시각화, 대기=빨간색, 작업=파란색
```

### 패턴 3: 팀 의존성 히트맵
```python
teams = ['EA팀', '인프라팀', '데이터팀', '보안팀']
dependency_matrix = [[0, 3, 2, 1], [3, 0, 1, 2], ...]
# imshow + annotate로 히트맵
```

### 패턴 4: Toil 분석 도넛 차트
```python
categories = ['기능 개발', '운영/유지보수', '장애 대응', '기술 부채', '보안 패치']
percentages = [30, 25, 15, 20, 10]
# pie with wedgeprops={'width': 0.4} for donut
```

### 패턴 5: 6개월 로드맵 간트 차트
```python
tasks = [
    ('Phase 1: 기반 구축', 0, 2),   # (이름, 시작 월, 기간 월)
    ('Phase 2: 자동화', 1, 3),
    ('Phase 3: 최적화', 3, 3),
]
# broken_barh로 간트 차트
```

## 제약 사항

- **없는 데이터를 추론하지 말 것** — MCP에서 얻을 수 없는 데이터는 "N/A" 표시
- **차트 최소 3개** — Executive Summary 외에 최소 3개의 시각화 포함
- **A4 기준 3-5장** — 과도한 분량 금지
- **인과 관계 명시** — "X를 변경하면 Y 지표가 Z만큼 개선" 형식
- **산출물 양 지표 사용 금지** — 커밋 수, PR 수, 스토리 포인트를 성과 지표로 제안하지 말 것

## 출력 예시

사용자: "EA팀 생산성 분석 보고서 만들어줘"

→ Step 1: fnf-ontology-mcp로 EA팀 구성원, 프로젝트, ITSM 티켓, 업무 현황 수집
→ Step 2: DORA + Toil + Value Stream 분석 → 수치 도출
→ Step 3: matplotlib로 4개 차트 생성 (DORA 카드, Value Stream, Toil 도넛, 로드맵)
→ Step 4: HTML 보고서 조립 (차트 base64 임베딩)
→ Step 5: HTML 아티팩트로 출력 + "PDF 다운로드" 안내
