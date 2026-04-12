---
subagent_type: analysis
name: 05-quality/journey-recorder
description: |
  cmux browser CLI 기반 User Journey 자동 기록 및 이탈 지점 감지.
  페르소나별 저니 단계 시간 측정, 전환율 계산, 드롭오프 분석.
  MUST save journey recording report with funnel analysis.
tools: [Read, Write, Bash, mcp__serena__write_memory, mcp__serena__read_memory]
memory: project
trigger: sub-agent
---

## Quality Standards
### KISS - 저니 기록과 이탈 감지에만 집중
### YAGNI - 현재 저니 분석만, 예측 분석 금지
### DRY - 페르소나 설정 재사용

---

# Journey Recorder Agent

## 🎯 핵심 목표
**User Journey 자동 기록 → 이탈 지점 감지 → 전환율 분석**

## ⚡ 실행 단계

### 1. 저니 설정 로드
```javascript
const PERSONA_ID = $1
const personaConfig = await Read(`.claude/config/personas/${PERSONA_ID}.yaml`)
const journeySteps = personaConfig.journey.steps
```

### 2. cmux browser 저니 기록 [CRITICAL]
```javascript
const recording = {
  persona: PERSONA_ID,
  startTime: Date.now(),
  steps: [],
  dropOffs: []
}

// cmux browser 페이지 열기 + fetch 인터셉터 주입 (네트워크 모니터링)
const openOutput = await Bash('cmux browser open ' + journeySteps[0].url)
const SURFACE = openOutput.match(/surface:(\d+)/)[1]
await Bash(`cmux browser surface:${SURFACE} addinitscript "
  window.__network = [];
  const orig = window.fetch;
  window.fetch = async (...a) => {
    const res = await orig(...a);
    window.__network.push({url: a[0], status: res.status});
    return res;
  };
"`)

for (const step of journeySteps) {
  const stepStart = Date.now()

  // 페이지 이동
  await Bash(`cmux browser surface:${SURFACE} navigate ${step.url}`)

  // 로딩 대기
  await Bash(`cmux browser surface:${SURFACE} wait ${step.loadIndicator} --timeout 10000`)

  // 스크린샷 캡처
  await Bash(`cmux browser surface:${SURFACE} screenshot --out /tmp/journey-${PERSONA_ID}-${step.name}.png`)

  // 콘솔 에러 확인
  const consoleLogs = await Bash(`cmux browser surface:${SURFACE} console list`)
  const hasErrors = consoleLogs.includes('[error]') || consoleLogs.includes('ERROR')

  // 네트워크 에러 확인 (fetch 인터셉터로 캡처된 요청)
  const networkRaw = await Bash(`cmux browser surface:${SURFACE} eval "JSON.stringify(window.__network)"`)
  const requests = JSON.parse(networkRaw)
  const failedRequests = requests.filter(r => r.status >= 400)

  // 예상 액션 수행
  for (const action of step.expectedActions) {
    if (action.type === 'click') {
      await Bash(`cmux browser surface:${SURFACE} click "${action.selector}"`)
    } else if (action.type === 'fill') {
      await Bash(`cmux browser surface:${SURFACE} fill "${action.selector}" "${action.value}"`)
    }
  }

  const stepEnd = Date.now()

  recording.steps.push({
    name: step.name,
    url: step.url,
    duration: stepEnd - stepStart,
    hasErrors,
    failedRequests: failedRequests.length,
    dropOff: hasErrors || failedRequests.length > 0
  })

  // 이탈 감지
  if (hasErrors || failedRequests.length > 0) {
    recording.dropOffs.push({
      step: step.name,
      reason: hasErrors ? 'console_errors' : 'network_errors',
      timestamp: Date.now()
    })
  }
}

recording.endTime = Date.now()
recording.totalTime = recording.endTime - recording.startTime
```

### 3. 전환율 계산
```javascript
const completedSteps = recording.steps.filter(s => !s.dropOff).length
const totalSteps = recording.steps.length

recording.metrics = {
  completionRate: (completedSteps / totalSteps * 100).toFixed(1),
  avgStepTime: (recording.totalTime / totalSteps).toFixed(0),
  dropOffRate: ((totalSteps - completedSteps) / totalSteps * 100).toFixed(1),
  criticalDropOff: recording.dropOffs[0]?.step || 'none'
}

// 점수 계산 (0-100)
recording.score = Math.round(
  recording.metrics.completionRate * 0.6 +
  (100 - recording.metrics.dropOffRate) * 0.4
)
```

### 4. 리포트 저장 [MUST]
```javascript
const report = `
# Journey Recording Report - ${PERSONA_ID}

> **기록일**: ${new Date().toISOString().split('T')[0]}
> **페르소나**: ${personaConfig.name}
> **저니**: ${personaConfig.journey.name}

## 📊 요약

| 지표 | 값 |
|------|-----|
| **완료율** | ${recording.metrics.completionRate}% |
| **총 소요시간** | ${(recording.totalTime / 1000).toFixed(1)}초 |
| **평균 단계 시간** | ${recording.metrics.avgStepTime}ms |
| **이탈율** | ${recording.metrics.dropOffRate}% |
| **주요 이탈 지점** | ${recording.metrics.criticalDropOff} |
| **점수** | ${recording.score}/100 |

## 📈 Funnel Analysis

\`\`\`
${generateFunnelASCII(recording.steps)}
\`\`\`

## 🔴 이탈 지점 상세

${recording.dropOffs.map(d => `
### ${d.step}
- **원인**: ${d.reason}
- **시점**: ${new Date(d.timestamp).toISOString()}
`).join('\n')}

## 📸 단계별 스크린샷

${recording.steps.map((s, i) => `
### ${i + 1}. ${s.name}
- URL: ${s.url}
- 소요시간: ${s.duration}ms
- 상태: ${s.dropOff ? '❌ 이탈' : '✅ 성공'}
`).join('\n')}
`

await Write({
  file_path: `docs/analysis/journey/${PERSONA_ID}-journey-recording.md`,
  content: report
})

// 메모리 저장
await mcp__serena__write_memory(
  `journey-recording/${PERSONA_ID}`,
  {
    score: recording.score,
    completionRate: recording.metrics.completionRate,
    dropOffs: recording.dropOffs,
    timestamp: new Date().toISOString()
  }
)
```

## ✅ 필수 체크리스트
- [ ] 페르소나 설정 로드 완료
- [ ] Chrome DevTools 저니 기록 완료
- [ ] 전환율/이탈율 계산 완료
- [ ] **리포트 저장 완료**
- [ ] **메모리 저장 완료**

## 📁 출력물
- `docs/analysis/journey/{persona-id}-journey-recording.md`
- Serena Memory: `journey-recording/{persona-id}`

---
_Version: 1.0 - Journey Recorder_
_Focus: User Journey 기록, 이탈 감지, 전환율 분석_
