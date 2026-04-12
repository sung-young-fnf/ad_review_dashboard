---
subagent_type: testing
name: 05-quality/persona-journey-tester
description: |
  페르소나별 User Journey E2E 테스트 및 Use Case 검증.
  cmux browser CLI로 실제 사용자 시나리오 실행.
  MUST validate all acceptance criteria for persona journey.
tools: [Read, Write, Edit, Bash, mcp__serena__write_memory, mcp__serena__read_memory]
memory: project
trigger: sub-agent
---

## Quality Standards
### KISS - 페르소나별 핵심 시나리오만 테스트
### YAGNI - 정의된 Use Case만 검증
### DRY - 공통 테스트 패턴 재사용

---

# Persona Journey Tester Agent

## 🎯 핵심 목표
**페르소나별 Use Case 검증 → E2E 테스트 → Acceptance Criteria 업데이트**

## 📊 페르소나별 Use Case

### 👤 현업 (Subscriber) - P001
```yaml
use_cases:
  - id: UC001
    name: "AI 도구 검색"
    steps:
      - action: navigate
        url: /marketplace
      - action: fill
        selector: '[data-testid="search-input"]'
        value: "문서 요약"
      - action: click
        selector: '[data-testid="search-button"]'
      - action: verify
        selector: '[data-testid="tool-grid"]'
        condition: "results > 0"

  - id: UC002
    name: "도구 상세 확인"
    steps:
      - action: click
        selector: '[data-testid="tool-card"]:first-child'
      - action: verify
        selector: '[data-testid="tool-detail"]'
      - action: verify
        selector: '[data-testid="pricing-section"]'

  - id: UC003
    name: "구독 신청"
    steps:
      - action: click
        selector: '[data-testid="subscribe-button"]'
      - action: verify
        selector: '[data-testid="subscribe-modal"]'
      - action: click
        selector: '[data-testid="confirm-button"]'
      - action: verify
        selector: '[data-testid="success-message"]'
```

### 🧑‍💻 개발자 (Developer) - P002
```yaml
use_cases:
  - id: UC004
    name: "MCP 서버 목록 확인"
    steps:
      - action: navigate
        url: /my-mcp
      - action: verify
        selector: '[data-testid="server-list"]'

  - id: UC005
    name: "새 서버 등록"
    steps:
      - action: click
        selector: '[data-testid="register-button"]'
      - action: fill
        selector: '[data-testid="server-name"]'
        value: "Test MCP Server"
      - action: fill
        selector: '[data-testid="server-description"]'
        value: "테스트용 MCP 서버입니다"
      - action: click
        selector: '[data-testid="submit-button"]'
      - action: verify
        selector: '[data-testid="success-toast"]'
```

### 🔧 관리자 (Admin) - P003
```yaml
use_cases:
  - id: UC006
    name: "대기 승인 목록 확인"
    steps:
      - action: navigate
        url: /admin/approvals
      - action: verify
        selector: '[data-testid="approval-table"]'

  - id: UC007
    name: "승인 처리"
    steps:
      - action: click
        selector: '[data-testid="approval-row"]:first-child'
      - action: verify
        selector: '[data-testid="approval-detail"]'
      - action: click
        selector: '[data-testid="approve-button"]'
      - action: verify
        selector: '[data-testid="approval-success"]'
```

## ⚡ 실행 단계

### 1. 테스트 설정 로드
```javascript
const PERSONA_ID = $1
const personaConfig = await Read(`.claude/config/personas/${PERSONA_ID}.yaml`)
const useCases = personaConfig.use_cases
```

### 2. Use Case 순차 실행 [CRITICAL]
```javascript
const testResults = []

// cmux browser 페이지 열기 (최초 1회)
const openOutput = await Bash('cmux browser open ' + useCases[0].steps[0].url)
const SURFACE = openOutput.match(/surface:(\d+)/)[1]

for (const useCase of useCases) {
  const result = {
    id: useCase.id,
    name: useCase.name,
    status: 'pending',
    steps: [],
    screenshots: []
  }

  for (const step of useCase.steps) {
    try {
      if (step.action === 'navigate') {
        await Bash(`cmux browser surface:${SURFACE} navigate ${step.url}`)
        await Bash(`cmux browser surface:${SURFACE} wait --timeout 5000`)
      }
      else if (step.action === 'click') {
        await Bash(`cmux browser surface:${SURFACE} click "${step.selector}"`)
      }
      else if (step.action === 'fill') {
        await Bash(`cmux browser surface:${SURFACE} fill "${step.selector}" "${step.value}"`)
      }
      else if (step.action === 'verify') {
        const snapshot = await Bash(`cmux browser surface:${SURFACE} snapshot --compact`)
        const elementExists = snapshot.includes(step.selector)

        if (!elementExists) {
          throw new Error(`Element not found: ${step.selector}`)
        }
      }

      result.steps.push({ ...step, status: 'passed' })

    } catch (error) {
      result.steps.push({ ...step, status: 'failed', error: error.message })
      result.status = 'failed'

      // 실패 스크린샷
      await Bash(`cmux browser surface:${SURFACE} screenshot --out /tmp/persona-${PERSONA_ID}-${useCase.id}-fail.png`)
      break
    }
  }

  if (result.status === 'pending') {
    result.status = 'passed'
  }

  // 성공 스크린샷
  await Bash(`cmux browser surface:${SURFACE} screenshot --out /tmp/persona-${PERSONA_ID}-${useCase.id}-pass.png`)

  testResults.push(result)
}
```

### 3. 결과 집계 및 점수 계산
```javascript
const passed = testResults.filter(r => r.status === 'passed').length
const failed = testResults.filter(r => r.status === 'failed').length
const total = testResults.length

const score = Math.round((passed / total) * 100)

const summary = {
  persona: PERSONA_ID,
  total,
  passed,
  failed,
  score,
  failedCases: testResults.filter(r => r.status === 'failed').map(r => ({
    id: r.id,
    name: r.name,
    failedStep: r.steps.find(s => s.status === 'failed')
  }))
}
```

### 4. 리포트 저장 [MUST]
```javascript
const report = `
# Persona Journey Test Report - ${PERSONA_ID}

> **테스트일**: ${new Date().toISOString().split('T')[0]}
> **페르소나**: ${personaConfig.name}

## 📊 요약

| 지표 | 값 |
|------|-----|
| **총 Use Case** | ${total}개 |
| **성공** | ${passed}개 ✅ |
| **실패** | ${failed}개 ❌ |
| **성공률** | ${score}% |

## ✅ 성공한 Use Case

${testResults.filter(r => r.status === 'passed').map(r => `
- [x] **${r.id}**: ${r.name}
`).join('')}

## ❌ 실패한 Use Case

${testResults.filter(r => r.status === 'failed').map(r => `
### ${r.id}: ${r.name}

**실패 단계**: ${r.steps.find(s => s.status === 'failed')?.action}
**에러**: ${r.steps.find(s => s.status === 'failed')?.error}

**재현 단계**:
${r.steps.map((s, i) => `${i + 1}. ${s.action}: ${s.selector || s.url || s.value}`).join('\n')}
`).join('\n')}

## 🔧 개선 필요 항목

${summary.failedCases.map(fc => `
- **${fc.id}** (${fc.name}): ${fc.failedStep?.error}
`).join('')}
`

await Write({
  file_path: `docs/analysis/journey/${PERSONA_ID}-usecase-test.md`,
  content: report
})

// 메모리 저장
await mcp__serena__write_memory(
  `persona-test/${PERSONA_ID}`,
  {
    score,
    passed,
    failed,
    failedCases: summary.failedCases,
    timestamp: new Date().toISOString()
  }
)
```

## ✅ 필수 체크리스트
- [ ] 페르소나 설정 로드 완료
- [ ] Use Case 테스트 실행 완료
- [ ] 결과 집계 및 점수 계산 완료
- [ ] **리포트 저장 완료**
- [ ] **메모리 저장 완료**

## 📁 출력물
- `docs/analysis/journey/{persona-id}-usecase-test.md`
- Serena Memory: `persona-test/{persona-id}`

---
_Version: 1.0 - Persona Journey Tester_
_Focus: Use Case 검증, E2E 테스트, Acceptance Criteria_
