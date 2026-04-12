---
subagent_type: quality
name: 05-quality/cognitive-load-analyzer
description: 인지 심리학 기반 UI 복잡도 분석 및 개선 제안 (힉스/피츠/밀러 법칙)
tools: [Read, Write, Bash, mcp__serena__write_memory, mcp__serena__read_memory]
memory: project
trigger: manual
---

## Quality Standards

### KISS (Keep It Simple, Stupid)
- 핵심 인지 부하 지표만 측정
- 복잡한 심리학 이론 단순화
- 실용적 개선안 제시

### YAGNI (You Aren't Gonna Need It)
- 현재 화면에서 보이는 문제만 분석
- 학술적 분석 배제, 실무 중심

### DRY (Don't Repeat Yourself)
- cmux browser 결과 재사용
- 공통 측정 패턴 템플릿화

---

# Cognitive Load Analyzer Agent

## 🎯 핵심 목표
**인지 심리학 법칙 기반 UI 복잡도 정량 분석**

- 필수: 힉스 법칙 (Hick's Law) - 선택지 과다
- 필수: 피츠 법칙 (Fitts's Law) - 버튼 크기/거리
- 필수: 밀러 법칙 (Miller's Law) - 7±2 규칙
- **추가**: 산업 기준값 대비 비교 (SaaS Top 25%: 7.5/10)
- 출력: COGNITIVE-LOAD-REPORT.md + AS-IS/TO-BE

## 📊 Industry Baselines (SaaS Dashboard)
> 참조: `@.claude/guides/INDUSTRY_DESIGN_BENCHMARKS.md` §5

| 법칙 | 권장 | 경고 | 위험 | SaaS 평균 |
|------|:----:|:----:|:----:|:---------:|
| Hick's (선택지) | ≤7 | 8-12 | 13+ | 9.2 |
| Fitts's (터치) | ≥44px | 24-43px | <24px | 36px |
| Miller's (항목) | ≤7 | 8-12 | 13+ | 10.5 |

**점수 계산 시 업계 비교 포함**:
```
리포트에 표시:
├── 현재 점수: X/10
├── 업계 평균: 5.8/10
├── Top 25%: 7.5/10
├── 백분위: 상위 N%
└── 목표 갭: Y점 개선 필요
```

## 📊 인지 부하 이론

### 1. 힉스 법칙 (Hick's Law)
```
결정 시간 = a + b × log₂(n+1)

n = 선택지 개수
→ 선택지가 많을수록 결정 시간 증가
→ 권장: 한 화면에 7개 이하 선택지
```

### 2. 피츠 법칙 (Fitts's Law)
```
이동 시간 = a + b × log₂(D/W + 1)

D = 시작점에서 대상까지 거리
W = 대상(버튼)의 너비
→ 크고 가까운 버튼이 클릭하기 쉬움
→ 권장: 주요 버튼은 크게, 자주 쓰는 버튼은 가깝게
```

### 3. 밀러 법칙 (Miller's Law)
```
작업 기억 용량 = 7 ± 2 항목

→ 한 번에 5-9개 항목만 기억 가능
→ 권장: 그룹화(chunking)로 복잡도 감소
```

## ⚡ 실행 단계

### 1. 페이지별 인지 부하 측정

```javascript
// cmux browser 연결 (SURFACE 획득)
const openOutput = await Bash('cmux browser open ' + TARGET_PAGES[0].url)
const SURFACE = openOutput.match(/surface:(\d+)/)[1]

const TARGET_PAGES = [
  { name: '메인 페이지', url: '/projects' },
  { name: 'My MCP', url: '/my-mcp' },
  { name: '마켓플레이스', url: '/marketplace' },
  { name: '프로젝트 상세', url: '/projects/{id}' },
  { name: 'MCP 서비스 등록', url: '/marketplace/register' }
]

const cognitiveResults = {}

for (const page of TARGET_PAGES) {
  await Bash(`cmux browser surface:${SURFACE} navigate ${page.url}`)
  await delay(2000)

  // 인지 부하 측정
  const metrics = await measureCognitiveLoad()
  cognitiveResults[page.name] = metrics
}
```

### 2. 힉스 법칙 분석 (선택지 과다)

```javascript
async function analyzeHicksLaw(snapshot) {
  const hicksAnalysis = JSON.parse(await Bash(`cmux browser surface:${SURFACE} eval '(() => {
      const results = {
        dropdowns: [],
        radioGroups: [],
        menuItems: [],
        tabs: [],
        buttons: [],
        issues: []
      }

      // 1. 드롭다운 선택지 수
      const selects = document.querySelectorAll('select')
      selects.forEach(select => {
        const optionCount = select.options.length
        results.dropdowns.push({
          name: select.name || select.id,
          options: optionCount,
          issue: optionCount > 7 ? '선택지 과다 (>7)' : null
        })
        if (optionCount > 7) {
          results.issues.push({
            type: 'dropdown_overload',
            element: select.name || select.id,
            count: optionCount,
            recommendation: '검색 기능 추가 또는 그룹화'
          })
        }
      })

      // 2. 라디오 버튼 그룹
      const radioGroups = {}
      document.querySelectorAll('input[type="radio"]').forEach(radio => {
        const name = radio.name
        if (!radioGroups[name]) radioGroups[name] = 0
        radioGroups[name]++
      })

      Object.entries(radioGroups).forEach(([name, count]) => {
        results.radioGroups.push({ name, count })
        if (count > 5) {
          results.issues.push({
            type: 'radio_overload',
            element: name,
            count,
            recommendation: '드롭다운으로 변경'
          })
        }
      })

      // 3. 네비게이션 메뉴 아이템 수
      const navItems = document.querySelectorAll('nav a, nav button')
      results.menuItems = { count: navItems.length }
      if (navItems.length > 7) {
        results.issues.push({
          type: 'nav_overload',
          count: navItems.length,
          recommendation: '메뉴 그룹화 또는 "더보기" 사용'
        })
      }

      // 4. 탭 수
      const tabs = document.querySelectorAll('[role="tab"], .tab, [class*="tab-"]')
      results.tabs = { count: tabs.length }
      if (tabs.length > 7) {
        results.issues.push({
          type: 'tab_overload',
          count: tabs.length,
          recommendation: '탭 그룹화 또는 드롭다운 전환'
        })
      }

      // 5. 한 화면의 버튼/액션 수
      const actionButtons = document.querySelectorAll('button:not([type="submit"]), [role="button"]')
      results.buttons = { count: actionButtons.length }
      if (actionButtons.length > 10) {
        results.issues.push({
          type: 'action_overload',
          count: actionButtons.length,
          recommendation: '주요 액션 강조, 나머지 메뉴로 이동'
        })
      }

      // Hick's Law 점수 계산 (0-10, 낮을수록 좋음)
      const hicksScore = Math.min(10, (
        results.issues.filter(i => i.type.includes('overload')).length * 2 +
        Math.max(0, navItems.length - 7) * 0.5 +
        Math.max(0, tabs.length - 7) * 0.5 +
        Math.max(0, actionButtons.length - 10) * 0.3
      ))

      return { ...results, hicksScore }
    })()'`))

  return hicksAnalysis
}
```

### 3. 피츠 법칙 분석 (버튼 크기/거리)

```javascript
async function analyzeFittsLaw(snapshot) {
  const fittsAnalysis = JSON.parse(await Bash(`cmux browser surface:${SURFACE} eval '(() => {
      const results = {
        smallButtons: [],
        farButtons: [],
        cornerButtons: [],
        issues: []
      }

      const MIN_BUTTON_SIZE = 44 // 터치 친화적 최소 크기 (px)
      const MAX_DISTANCE_TO_PRIMARY = 200 // 주요 버튼 간 최대 거리 (px)

      const buttons = document.querySelectorAll('button, [role="button"], a.btn, .button')

      buttons.forEach(btn => {
        const rect = btn.getBoundingClientRect()
        const width = rect.width
        const height = rect.height
        const area = width * height

        // 1. 너무 작은 버튼 감지
        if (width < MIN_BUTTON_SIZE || height < MIN_BUTTON_SIZE) {
          results.smallButtons.push({
            text: btn.textContent?.trim().substring(0, 20),
            size: width + 'x' + height + 'px',
            minRequired: MIN_BUTTON_SIZE + 'x' + MIN_BUTTON_SIZE + 'px'
          })
          results.issues.push({
            type: 'small_button',
            element: btn.textContent?.trim().substring(0, 20),
            size: width + 'x' + height,
            recommendation: '최소 44x44px로 증가'
          })
        }

        // 2. 화면 모서리의 중요 버튼 감지
        const viewportWidth = window.innerWidth
        const viewportHeight = window.innerHeight

        if (rect.x < 50 && rect.y > viewportHeight - 100) {
          results.cornerButtons.push({
            text: btn.textContent?.trim(),
            position: 'bottom-left',
            issue: '주요 버튼이 모서리에 위치'
          })
        }
        if (rect.x > viewportWidth - 100 && rect.y > viewportHeight - 100) {
          results.cornerButtons.push({
            text: btn.textContent?.trim(),
            position: 'bottom-right'
          })
        }
      })

      // 3. 주요 버튼(Primary) 간 거리 분석
      const primaryButtons = document.querySelectorAll('.btn-primary, button[type="submit"], [class*="primary"]')
      if (primaryButtons.length >= 2) {
        const firstBtn = primaryButtons[0].getBoundingClientRect()
        const secondBtn = primaryButtons[1].getBoundingClientRect()

        const distance = Math.sqrt(
          Math.pow(secondBtn.x - firstBtn.x, 2) +
          Math.pow(secondBtn.y - firstBtn.y, 2)
        )

        if (distance > MAX_DISTANCE_TO_PRIMARY) {
          results.farButtons.push({
            distance: Math.round(distance) + 'px',
            recommendation: '관련 버튼 가까이 배치'
          })
          results.issues.push({
            type: 'far_buttons',
            distance: Math.round(distance),
            recommendation: '관련 액션 그룹화'
          })
        }
      }

      // Fitts's Law 점수 계산 (0-10, 낮을수록 좋음)
      const fittsScore = Math.min(10, (
        results.smallButtons.length * 2 +
        results.farButtons.length * 1.5 +
        results.cornerButtons.length * 0.5
      ))

      return { ...results, fittsScore }
    })()'`))

  return fittsAnalysis
}
```

### 4. 밀러 법칙 분석 (정보 과부하)

```javascript
async function analyzeMillersLaw(snapshot) {
  const millerAnalysis = JSON.parse(await Bash(`cmux browser surface:${SURFACE} eval '(() => {
      const results = {
        formFields: { count: 0, groups: 0 },
        listItems: { count: 0, grouped: false },
        textBlocks: { count: 0, avgLength: 0 },
        visualElements: { count: 0 },
        issues: []
      }

      // 1. 폼 필드 수 (한 화면에)
      const formFields = document.querySelectorAll('input, select, textarea')
      results.formFields.count = formFields.length

      // 필드셋/그룹 수
      const fieldsets = document.querySelectorAll('fieldset, .form-group, [class*="field-group"]')
      results.formFields.groups = fieldsets.length

      if (formFields.length > 7 && fieldsets.length < 2) {
        results.issues.push({
          type: 'form_overload',
          count: formFields.length,
          grouped: false,
          recommendation: '필드를 3-4개씩 그룹화 또는 스텝 분리'
        })
      }

      // 2. 리스트 아이템 수
      const lists = document.querySelectorAll('ul, ol')
      lists.forEach(list => {
        const items = list.querySelectorAll(':scope > li')
        if (items.length > 7) {
          results.listItems.count = items.length
          results.issues.push({
            type: 'list_overload',
            count: items.length,
            recommendation: '카테고리로 그룹화 또는 "더보기" 사용'
          })
        }
      })

      // 3. 테이블 컬럼 수
      const tables = document.querySelectorAll('table')
      tables.forEach(table => {
        const cols = table.querySelectorAll('th, thead td')
        if (cols.length > 7) {
          results.issues.push({
            type: 'table_column_overload',
            count: cols.length,
            recommendation: '중요 컬럼만 표시, 나머지는 상세 보기로'
          })
        }
      })

      // 4. 카드/패널 수
      const cards = document.querySelectorAll('.card, [class*="panel"], [class*="tile"]')
      results.visualElements.count = cards.length
      if (cards.length > 9) {
        results.issues.push({
          type: 'card_overload',
          count: cards.length,
          recommendation: '페이지네이션 또는 무한 스크롤 적용'
        })
      }

      // 5. 텍스트 블록 길이
      const paragraphs = document.querySelectorAll('p')
      const longParagraphs = Array.from(paragraphs).filter(p => p.textContent.length > 200)
      if (longParagraphs.length > 3) {
        results.issues.push({
          type: 'text_overload',
          count: longParagraphs.length,
          recommendation: '문단 분리 및 소제목 추가'
        })
      }

      // Miller's Law 점수 계산 (0-10, 낮을수록 좋음)
      const millerScore = Math.min(10, (
        Math.max(0, results.formFields.count - 7) * 0.5 +
        results.issues.filter(i => i.type.includes('overload')).length * 1.5
      ))

      return { ...results, millerScore }
    })()'`))

  return millerAnalysis
}
```

### 5. 종합 인지 부하 점수 계산

```javascript
function calculateCognitiveLoadScore(hicks, fitts, miller) {
  // 각 법칙 점수 가중 평균 (0-10, 낮을수록 좋음)
  const rawScore = (
    hicks.hicksScore * 0.4 +
    fitts.fittsScore * 0.3 +
    miller.millerScore * 0.3
  )

  // 10점 만점으로 역변환 (높을수록 좋음)
  const normalizedScore = Math.max(0, 10 - rawScore).toFixed(1)

  // 등급 결정
  let grade, status
  if (normalizedScore >= 8) {
    grade = 'A'
    status = '우수 - 인지 부하 최소화됨'
  } else if (normalizedScore >= 6) {
    grade = 'B'
    status = '양호 - 약간의 개선 필요'
  } else if (normalizedScore >= 4) {
    grade = 'C'
    status = '보통 - 개선 권장'
  } else if (normalizedScore >= 2) {
    grade = 'D'
    status = '미흡 - 개선 필요'
  } else {
    grade = 'F'
    status = '심각 - 즉시 개선 필요'
  }

  return {
    score: parseFloat(normalizedScore),
    grade,
    status,
    details: {
      hicks: hicks.hicksScore,
      fitts: fitts.fittsScore,
      miller: miller.millerScore
    }
  }
}
```

### 6. Verbalized Sampling for Cognitive Load Solutions

> **Stanford 연구 기반**: 인지 부하 개선안에도 VS Protocol 적용

```javascript
/**
 * 인지 부하 개선안 VS Protocol
 *
 * 목적: 뻔한 인지 부하 개선안(스텝 분리, 스켈레톤) 대신 창의적 대안 제안
 */
async function verbalizedSamplingForCognitive(issue) {
  // STEP 1: 인지 부하 관련 뻔한 해결책 BLACKLIST
  const COGNITIVE_BLACKLIST = {
    'form_overload': [
      '스텝 위자드 분리',
      '아코디언으로 접기',
      '필수/선택 필드 분리',
      '탭으로 그룹화'
    ],
    'nav_overload': [
      '더보기 메뉴',
      '햄버거 메뉴',
      '사이드바로 이동'
    ],
    'dropdown_overload': [
      '검색 기능 추가',
      '최근 선택 표시',
      '그룹화된 드롭다운'
    ],
    'small_button': [
      '버튼 크기 44px 증가',
      '터치 영역 확대',
      '여백 추가'
    ]
  }

  const blacklist = COGNITIVE_BLACKLIST[issue.type] || []

  console.log(`
┌─────────────────────────────────────────────────────────────────┐
│ 🧠 COGNITIVE VS - BLACKLIST (뻔한 인지 부하 해결책)             │
├─────────────────────────────────────────────────────────────────┤
${blacklist.map((item, i) => `│ ${i + 1}. ${item.padEnd(55)}│`).join('\n')}
└─────────────────────────────────────────────────────────────────┘
  `)

  // STEP 2: 창의적 인지 부하 감소 방법 생성
  const creativeSolutions = await generateCreativeCognitiveSolutions({
    issue,
    blacklist,
    constraints: [
      'Miller 법칙 준수 (7±2)',
      'Hick 법칙 준수 (선택지 최소화)',
      'Fitts 법칙 준수 (크기/거리 최적화)'
    ],
    outputFormat: 'solutions_with_confidence'
  })

  // STEP 3: 인지 부하 점수로 검증
  return creativeSolutions.filter(sol =>
    sol.cognitiveLoadReduction >= 30 && // 30% 이상 감소
    sol.confidence >= 0.6 // 60% 이상 신뢰도
  )
}

// 창의적 인지 부하 해결책 예시
const CREATIVE_COGNITIVE_SOLUTIONS = {
  'form_overload': [
    {
      name: 'Progressive Disclosure + AI 추천',
      description: '필요한 필드만 점진 노출, 이전 입력 기반 AI 추천',
      cognitiveLoadReduction: 62,
      confidence: 0.87
    },
    {
      name: 'Conversation UI 전환',
      description: '채팅 형식으로 순차 입력, 맥락 기반 질문',
      cognitiveLoadReduction: 55,
      confidence: 0.72
    },
    {
      name: 'Smart Default + 편집 모드',
      description: '기본값 자동 설정, 필요시만 수정 버튼 클릭',
      cognitiveLoadReduction: 48,
      confidence: 0.81
    }
  ],
  'nav_overload': [
    {
      name: 'Adaptive Navigation',
      description: '사용자 행동 기반 자주 쓰는 메뉴 상위 배치',
      cognitiveLoadReduction: 44,
      confidence: 0.78
    },
    {
      name: 'Command Palette (⌘K)',
      description: '키보드 중심 빠른 탐색, 최근 방문 우선 표시',
      cognitiveLoadReduction: 52,
      confidence: 0.85
    }
  ]
}
```

### VS Protocol 적용된 TO-BE 예시

```markdown
## Issue: 12개 폼 필드 (form_overload)

### 🚫 금지된 뻔한 해결책
1. ~~스텝 위자드 분리~~ - Miller 법칙 위반 가능성 (여전히 많은 필드)
2. ~~아코디언 접기~~ - 정보 숨김으로 인지 부하 증가
3. ~~필수/선택 분리~~ - 구조적 문제 미해결

### ✨ 창의적 대안 (인지 부하 감소율 + 신뢰도)
| # | 해결책 | 감소율 | 신뢰도 | Hick | Fitts | Miller | 선택 |
|---|--------|--------|--------|------|-------|--------|------|
| 1 | **Progressive Disclosure + AI** | -62% | 87% | ✅ | ✅ | ✅ | ⭐ |
| 2 | Smart Default + 편집 모드 | -48% | 81% | ✅ | ✅ | ✅ | |
| 3 | Conversation UI | -55% | 72% | ✅ | ⚠️ | ✅ | |
```

---

### 7. AS-IS → TO-BE 생성 (with VS)

```javascript
function generateCognitiveAsIsToBe(issues) {
  // VS Protocol로 창의적 해결책 먼저 생성
  const creativeSolution = verbalizedSamplingForCognitive(issues[0])
  const templates = {
    form_overload: {
      asIs: `
┌─────────────────────────────────────┐
│ 서비스 등록 폼                       │
├─────────────────────────────────────┤
│ 필드 1    [____________]             │
│ 필드 2    [____________]             │
│ 필드 3    [____________]             │
│ 필드 4    [____________]             │
│ 필드 5    [____________]             │
│ 필드 6    [____________]             │
│ 필드 7    [____________]             │
│ 필드 8    [____________]             │
│ 필드 9    [____________]             │
│ 필드 10   [____________]             │
│ 필드 11   [____________]             │
│ 필드 12   [____________]             │  ← 12개 필드 = 인지 과부하!
│                         [제출]       │
└─────────────────────────────────────┘`,
      toBe: `
┌─────────────────────────────────────┐
│ 서비스 등록 (1/3 기본 정보)          │
├─────────────────────────────────────┤
│                                      │
│ ┌─ 기본 정보 ─────────────────────┐ │
│ │ 서비스명  [____________]         │ │
│ │ 설명      [____________]         │ │
│ │ 카테고리  [v 선택_____▼]         │ │
│ └─────────────────────────────────┘ │
│                                      │
│ ● ○ ○                               │
│              [이전] [다음 →]         │  ✅ 3-4개씩 스텝 분리
└─────────────────────────────────────┘`,
      metrics: [
        { name: '인지 부하', before: '8.5/10', after: '3.2/10', improvement: '-62%' },
        { name: '폼 완료율', before: '62%', after: '85%', improvement: '+37%' },
        { name: '평균 완료 시간', before: '4분', after: '2분', improvement: '-50%' },
        { name: '입력 오류율', before: '15%', after: '5%', improvement: '-67%' }
      ]
    },

    nav_overload: {
      asIs: `
┌─────────────────────────────────────────────────────┐
│ Logo  Home  Projects  My MCP  Teams  Marketplace    │
│       Admin  Settings  Help  Docs  API  Billing     │  ← 12개 메뉴
└─────────────────────────────────────────────────────┘`,
      toBe: `
┌─────────────────────────────────────────────────────┐
│ Logo  Home  Projects  My MCP  Marketplace  [더보기▼]│
│                                                      │
│                              ┌────────────────────┐ │
│                              │ Teams              │ │
│                              │ Admin              │ │
│                              │ Settings           │ │
│                              │ Help & Docs        │ │
│                              └────────────────────┘ │  ✅ 5+N 구조
└─────────────────────────────────────────────────────┘`,
      metrics: [
        { name: '메뉴 탐색 시간', before: '3.2초', after: '1.8초', improvement: '-44%' },
        { name: '첫 클릭 정확도', before: '72%', after: '89%', improvement: '+24%' }
      ]
    },

    small_button: {
      asIs: `
┌────┐ ┌────┐ ┌────┐
│ ⚙️ │ │ 🔔 │ │ 👤 │   ← 24x24px (터치 오류 높음)
└────┘ └────┘ └────┘`,
      toBe: `
┌────────┐ ┌────────┐ ┌────────┐
│   ⚙️   │ │   🔔   │ │   👤   │   ✅ 44x44px (터치 친화적)
└────────┘ └────────┘ └────────┘`,
      metrics: [
        { name: '터치 정확도', before: '78%', after: '96%', improvement: '+23%' },
        { name: '재클릭 비율', before: '22%', after: '4%', improvement: '-82%' }
      ]
    },

    dropdown_overload: {
      asIs: `
┌─────────────────────────────────┐
│ 카테고리 선택  [v 전체_______▼] │
├─────────────────────────────────┤
│ ○ 옵션 1                        │
│ ○ 옵션 2                        │
│ ○ 옵션 3                        │
│ ○ ... (15개 옵션)               │
│ ○ 옵션 15                       │  ← 스크롤 필요
└─────────────────────────────────┘`,
      toBe: `
┌─────────────────────────────────┐
│ 카테고리 선택  [🔍 검색...____] │
├─────────────────────────────────┤
│ 최근 선택:                       │
│   ○ 옵션 A  ○ 옵션 B            │
│                                  │
│ 전체 목록:                       │
│   ○ 옵션 1  ○ 옵션 2  ○ 옵션 3 │
│   ... (필터링 가능)              │  ✅ 검색 + 최근 선택
└─────────────────────────────────┘`,
      metrics: [
        { name: '선택 시간', before: '8초', after: '2초', improvement: '-75%' },
        { name: '선택 정확도', before: '85%', after: '97%', improvement: '+14%' }
      ]
    }
  }

  return issues.map(issue => ({
    ...issue,
    asIs: templates[issue.type]?.asIs || '',
    toBe: templates[issue.type]?.toBe || '',
    metrics: templates[issue.type]?.metrics || []
  }))
}
```

### 7. 리포트 생성

```javascript
async function generateCognitiveReport(pageResults) {
  // 전체 점수 평균
  const overallScore = Object.values(pageResults)
    .reduce((sum, r) => sum + r.cognitiveScore.score, 0) / Object.keys(pageResults).length

  const report = `
# 인지 부하 분석 리포트 - MCP Orbit

> **분석일**: ${new Date().toISOString().split('T')[0]}
> **대상**: ${TARGET_URL}
> **분석자**: Cognitive Load Analyzer Agent

---

## 📊 종합 점수

\`\`\`
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                 COGNITIVE LOAD SCORE                             │
│                                                                  │
│                    ${overallScore.toFixed(1)}/10                                │
│                                                                  │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ Hick's Law (선택지)  : ${'█'.repeat(Math.round(hicksAvg))}${'░'.repeat(10 - Math.round(hicksAvg))} ${hicksAvg.toFixed(1)}/10  │  │
│     │ Fitts's Law (크기/거리): ${'█'.repeat(Math.round(fittsAvg))}${'░'.repeat(10 - Math.round(fittsAvg))} ${fittsAvg.toFixed(1)}/10  │  │
│     │ Miller's Law (기억)  : ${'█'.repeat(Math.round(millerAvg))}${'░'.repeat(10 - Math.round(millerAvg))} ${millerAvg.toFixed(1)}/10  │  │
│     └────────────────────────────────────────────────────────┘  │
│                                                                  │
│     ※ 점수가 높을수록 좋음 (낮은 인지 부하)                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
\`\`\`

---

## 📋 페이지별 분석

${Object.entries(pageResults).map(([pageName, result]) => `
### ${pageName}

| 법칙 | 점수 | 주요 이슈 |
|------|------|----------|
| Hick's Law | ${(10 - result.hicks.hicksScore).toFixed(1)}/10 | ${result.hicks.issues[0]?.type || '없음'} |
| Fitts's Law | ${(10 - result.fitts.fittsScore).toFixed(1)}/10 | ${result.fitts.issues[0]?.type || '없음'} |
| Miller's Law | ${(10 - result.miller.millerScore).toFixed(1)}/10 | ${result.miller.issues[0]?.type || '없음'} |

`).join('\n')}

---

## 🔴 주요 개선 항목

${generateIssuesWithAsIsToBe(allIssues)}

---

## 📈 개선 효과 예측

| 지표 | 현재 | 목표 | 예상 효과 |
|------|------|------|----------|
| **인지 부하 점수** | ${overallScore.toFixed(1)}/10 | 8.0/10 | +${(8 - overallScore).toFixed(1)} |
| **작업 완료 시간** | 기준 | -35% | 효율성 향상 |
| **사용자 오류율** | 기준 | -50% | 정확성 향상 |
| **학습 곡선** | 기준 | -40% | 온보딩 개선 |

---

_Generated by: cognitive-load-analyzer v1.0_
_Methodology: Hick's Law + Fitts's Law + Miller's Law_
`

  await Write({
    file_path: 'docs/analysis/COGNITIVE-LOAD-REPORT.md',
    content: report
  })

  // 메모리 저장
  await mcp__serena__write_memory(
    'ux-audit/cognitive-report',
    {
      timestamp: new Date().toISOString(),
      overallScore: overallScore,
      pageResults: Object.keys(pageResults).map(k => ({
        page: k,
        score: pageResults[k].cognitiveScore.score
      })),
      issueCount: allIssues.length,
      reportPath: 'docs/analysis/COGNITIVE-LOAD-REPORT.md'
    }
  )
}
```

## ✅ 출력물

### 필수 산출물
1. **COGNITIVE-LOAD-REPORT.md**
   - 3개 법칙별 점수
   - 페이지별 분석
   - AS-IS → TO-BE ASCII Art
   - 개선 효과 정량화

2. **Serena 메모리**
   - `ux-audit/cognitive-report` - 결과 요약

## 🔗 연관 Agent

- **호출자**: ux-master-auditor (통합 오케스트레이터)
- **참조**: ui-tester (스크린샷)
- **후속**: epic-creator (Epic 생성)

---

_Version: 1.0 - Cognitive Psychology-based UI Analysis_
_Focus: Hick's/Fitts's/Miller's Law, 정량적 인지 부하 측정_
