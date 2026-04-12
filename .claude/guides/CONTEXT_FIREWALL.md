# Context Firewall Enforcement

> **CCPM Pattern**: Sub-Agent는 컨텍스트 축소 도구. 10개 파일 읽기 → 1개 요약 반환 (80-90% 절감)

## MANDATORY Rules - Hard Stop on Violation

### ❌ NEVER use Read tool directly for:

- Log files (`*.log`, `*.out`, `*.err`)
- Test outputs (Jest, Pytest, any test results)
- Error traces and stack traces
- Verbose files (JSON/YAML > 100 lines)
- Build outputs and compilation logs
- Browser console outputs

### ✅ MUST delegate to Sub-Agent:

**file-analyzer** - 모든 로그, 출력, Verbose 파일
```bash
Task --subagent file-analyzer --prompt "Analyze {file} and summarize key findings"
```

**code-analyzer** - 코드 분석, 버그 추적, 로직 플로우
```bash
Task --subagent code-analyzer --prompt "Analyze {component} for {issue}"
```

**test-runner** - 테스트 실행 및 결과 분석
```bash
Task --subagent test-runner --prompt "Run tests and report failures"
```

---

## 🚨 Violation Detection

If you attempt to use Read tool for prohibited files:

```
❌ Context Firewall Violation Detected
You attempted: Read {file}
Required: Task --subagent file-analyzer --prompt "Analyze {file}"

Reason: {file} is a {type} file (Context Firewall Rule #1)
Impact: Direct read would consume 5000+ tokens. Sub-agent reduces to <500 tokens.
```

---

## Why This Matters

| Factor | Direct Read | Sub-Agent |
|--------|-------------|-----------|
| **Tokens** | 5000+ | <500 |
| **Context** | Full dump | Summary |
| **Focus** | Raw data | Key insights |
| **Speed** | Slower | Faster |

### Benefits

- **Context Window**: LLM context is limited. Every token counts.
- **Efficiency**: 80-90% context reduction (CCPM verified)
- **Focus**: Main thread sees summaries, not raw dumps
- **Speed**: Faster responses, less context switching

---

## Legacy Rules (Still Valid)

These guidelines are now **enforced** by Context Firewall:

1. ✅ file-analyzer: 로그 파일, 출력 파일, Verbose 데이터
2. ✅ code-analyzer: 코드 분석, 버그 추적, 로직 플로우
3. ✅ test-runner: 테스트 실행 및 결과 분석

### Additional Benefits

- Full output captured for debugging
- Main conversation stays clean
- Context usage optimized
- All issues properly surfaced
- No approval dialogs interrupt workflow
