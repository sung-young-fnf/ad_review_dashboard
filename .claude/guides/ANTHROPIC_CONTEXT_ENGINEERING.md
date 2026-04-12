# Anthropic 공식 가이드: Effective Context Engineering for AI Agents

> 출처: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
>
> 생성일: 2025-10-02
>
> **목적**: Agent 설계 시 컨텍스트 최적화를 위한 Anthropic 공식 Best Practice

---

## 📖 정의

### Context Engineering이란?

> "Context engineering refers to the set of strategies for curating and maintaining the optimal set of tokens (information) during LLM inference."

**핵심 목표**: "최소한의 고신호 토큰으로 원하는 결과를 최대화"

---

## 🎯 핵심 원칙

### 1. System Prompts 작성법

**✅ DO:**
- 명확하고 직접적인 언어 사용
- 구체성과 유연성의 균형 유지
- 섹션별 구조화 (`<background_information>`, `<instructions>`)
- 최소한이지만 충분한 정보만 포함

**❌ DON'T:**
- 복잡하고 취약한 로직을 프롬프트에 하드코딩
- 모호하고 추상적인 지침 제공

### 2. Tool 설계 원칙

**도구는 다음을 만족해야 함:**
- **Self-contained**: 독립적으로 동작 가능
- **Robust to errors**: 에러에 강건함
- **Extremely clear**: 의도된 사용법이 매우 명확

**Parameter 설계:**
- Descriptive (설명적)
- Unambiguous (명확함)
- Aligned with model strengths (모델 강점과 정렬)

**❌ 피해야 할 것:**
- 기능이 겹치는 비대한 도구 세트
- 모호한 파라미터 명

### 3. Context Retrieval 전략

#### Just-in-Time Context (권장)
```yaml
approach:
  - 경량 식별자만 유지 (파일 경로, 쿼리)
  - 런타임에 동적 로드
  - 인간의 선택적 정보 검색 방식 모방

benefits:
  - 컨텍스트 윈도우 효율 극대화
  - 필요한 정보만 로드
  - 토큰 낭비 최소화
```

#### Hybrid Retrieval (상황별 적용)
```yaml
strategy:
  - 속도를 위해 일부 데이터 사전 로드
  - 자율적 탐색 가능하도록 설계
  - 작업 요구사항에 따라 전략 조정
```

---

## 🔧 Context 최적화 기법

### 1. Compaction (압축)

**시점**: 컨텍스트 윈도우 한계에 근접할 때

**방법**:
1. 대화 내용을 요약
2. 압축된 요약으로 재시작
3. 중요한 세부사항 보존
4. 중복 정보 제거

**적용 예**:
```markdown
AS-IS (5000 tokens):
- 전체 대화 이력
- 모든 중간 단계
- 반복된 정보

TO-BE (1000 tokens):
- 핵심 결정 사항
- 최종 상태
- 다음 단계 정보
```

### 2. Structured Note-Taking (구조화된 메모)

**패턴**:
1. 컨텍스트 외부에 주기적으로 노트 작성
2. 필요시 노트를 컨텍스트로 재로드
3. 상호작용 간 영구 메모리 유지

**적용 예**:
```yaml
Memory System:
  - Technical Decisions: .serena/memories/tech-decisions.md
  - Architecture Patterns: .serena/memories/architecture.md
  - Debugging History: .serena/memories/debug-log.md

Usage:
  - Write: 중요 결정 시점
  - Read: 관련 작업 시작 시
  - Update: 변경 사항 발생 시
```

### 3. Sub-Agent Architectures (Sub-Agent 아키텍처)

**설계 원칙**:
- 전문화된 Agent로 집중된 작업 수행
- 깨끗한 컨텍스트 윈도우 유지
- 병렬 탐색 가능
- 메인 조정 Agent가 결과 종합

**적용 예**:
```yaml
Main Agent (Coordinator):
  context: 전체 작업 흐름, 의사결정
  role: 작업 분배, 결과 통합

Sub-Agent (Specialist):
  - file-analyzer: 파일 분석만 수행, 요약 반환
  - code-writer: 구현만 수행, 결과 반환
  - test-runner: 테스트만 수행, 결과 반환

benefits:
  - 각 Agent 컨텍스트 < 10K tokens
  - 병렬 처리 가능
  - 실패 격리
```

---

## 📊 성능 고려사항

### Context Window의 한계

**사실**:
- LLM은 유한한 "attention budget"을 가짐
- 컨텍스트 윈도우 크기가 성능 그라디언트 생성
- 긴 컨텍스트 = 정보 검색 정밀도 감소

**최적 전략**:
```yaml
Small Context (< 10K tokens):
  - 높은 정밀도
  - 빠른 응답
  - 명확한 집중

Large Context (> 50K tokens):
  - 정보 검색 어려움
  - 중요 정보 누락 가능
  - 응답 지연
```

---

## ⛔ Anti-Patterns (피해야 할 패턴)

### 1. 복잡한 로직 하드코딩
```markdown
❌ BAD:
"If the file is TypeScript and contains React components and has more
than 100 lines and uses hooks, then apply pattern A, otherwise if it's
JavaScript but not JSX..."

✅ GOOD:
"Analyze the file and apply appropriate patterns based on file type
and complexity. Use [tool_name] to determine the best approach."
```

### 2. 모호한 지침
```markdown
❌ BAD:
"Make the code better and follow best practices."

✅ GOOD:
"Apply KISS, YAGNI, DRY principles:
- KISS: Use simple functions over complex patterns
- YAGNI: Only implement current requirements
- DRY: Reuse existing functions, check codebase first"
```

### 3. 중복 기능 도구
```markdown
❌ BAD:
- read_file()
- read_file_content()
- get_file_data()
- load_file()

✅ GOOD:
- Read (단일 파일 읽기 도구)
```

---

## 💡 우리 프로젝트 적용 방안

### 1. System Prompt 개선
**현재**: CLAUDE.md에 모든 지침 포함 (대용량)
**개선**:
- 핵심 원칙만 CLAUDE.md 유지
- 세부 가이드는 별도 파일로 분리
- Just-in-Time으로 필요시 로드

### 2. Tool 최적화
**현재**: 다양한 MCP 도구 혼재
**개선**:
- Chrome DevTools MCP 단일화 (브라우저 작업)
- 전용 도구 우선 사용 (Read, Write, Edit)
- Bash는 터미널 전용으로 제한

### 3. Sub-Agent 활용
**현재**: 이미 적용 중 (file-analyzer, code-writer 등)
**개선**:
- 각 Agent 컨텍스트 10K 이하로 제한
- Memory System 적극 활용 (.serena/memories/)
- Compaction 패턴 적용 (긴 작업 시)

### 4. Context Retrieval
**현재**: 파일 전체 읽기 빈번
**개선**:
- Serena MCP 심볼 기반 조회 우선
- get_symbols_overview → 필요한 심볼만 find_symbol
- 전체 파일 읽기는 최후 수단

---

## 📋 체크리스트

Agent 설계 시 다음을 확인:

- [ ] System Prompt가 10줄 이내로 명확한가?
- [ ] Tool 파라미터가 모호하지 않은가?
- [ ] 중복 기능 Tool이 없는가?
- [ ] Just-in-Time Context 전략을 사용하는가?
- [ ] Sub-Agent로 분리 가능한 작업인가?
- [ ] Memory System을 활용하는가?
- [ ] Anti-Pattern을 피하고 있는가?

---

## 🔗 관련 문서

1. **CLAUDE.md AUTO-WORKFLOW**
   - 위치: `.claude/CLAUDE.md`
   - 내용: Agent 체인 정의, Tool 선택 가이드

2. **debugging-workflow.md**
   - 위치: `docs/analysis/debugging-workflow.md`
   - 내용: Error Recovery 표준 절차

3. **Agent Optimization Guide**
   - 위치: `.claude/guides/AGENT_OPTIMIZATION_GUIDE.md`
   - 내용: 최적화 원칙 및 패턴

4. **Company Agent Standards**
   - 위치: `.claude/guides/COMPANY_AGENT_STANDARDS.md`
   - 내용: 표준 준수 사항

5. **Agent Health Report**
   - 위치: `.claude/reports/latest-agent-health-report.md`
   - 내용: 현재 Agent 품질 현황

---

*이 문서는 Anthropic 공식 가이드를 기반으로 작성되었으며, 우리 프로젝트의 Agent 최적화 기준으로 사용됩니다.*
