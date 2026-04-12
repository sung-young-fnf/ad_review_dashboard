# Memory MCP 역할 분담 가이드

> 4개 MCP의 역할을 명확히 구분하여 토큰 효율 극대화

## MCP 역할 분담

```
[mcp-roles: mcp, purpose, when-to-use, tools]
serena, 코드 분석/수정 + 영구 메모리, 심볼 검색/참조 추적/중요 결정 저장, find_symbol get_symbols_overview write_memory
historian, 과거 대화 검색, 에러 해결 패턴/유사 작업 참조/워크플로우 학습, search_conversations get_error_solutions find_similar_queries
praetorian, 세션 컨텍스트 압축, WebFetch 후/Task 완료 후/컨텍스트 60%+ 시, praetorian_compact praetorian_restore
shadcn, UI 컴포넌트 레지스트리, shadcn/ui 컴포넌트 검색/설치/블록 조회, list-components install-component search-registry
```

## 사용 시점 규칙

```
[trigger-rules: event, action, mcp]
WebFetch 완료, 결과 압축 저장, praetorian_compact
Task Agent 완료, 결과 압축 저장, praetorian_compact
에러 발생, 과거 해결책 검색, historian/get_error_solutions
유사 작업 시작, 과거 접근법 참조, historian/find_similar_queries
아키텍처 결정, 영구 기록 저장, serena/write_memory
Epic/Story 완료, 결정사항 영구화, serena/write_memory
코드 분석 필요, 심볼 기반 검색, serena/find_symbol
UI 컴포넌트 필요, 컴포넌트 검색/설치, shadcn (list-components/install)
새 페이지/블록 생성, 블록 검색, shadcn (search-registry)
```

## 메모리 계층

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: 세션 압축 (Praetorian)                      │
│ - WebFetch, Task 결과 → TOON 압축 (90%+ 절감)        │
│ - 세션 내 빠른 복원                                   │
│ - 위치: docs/praetorian/*.toon (프로젝트별 분리)     │
├─────────────────────────────────────────────────────┤
│ Layer 2: 히스토리 검색 (Historian)                   │
│ - 과거 세션 대화 검색 (읽기 전용)                     │
│ - 에러 솔루션, 워크플로우 패턴                        │
│ - 위치: ~/.claude/conversations/ (Claude Code)      │
├─────────────────────────────────────────────────────┤
│ Layer 3: 영구 메모리 (Serena)                        │
│ - 프로젝트 핵심 결정사항만 저장                       │
│ - 중요도 높은 컨텍스트만 (git-refactor-cache 금지)   │
│ - 위치: .serena/memories/*.md                       │
└─────────────────────────────────────────────────────┘
```

## 금지 패턴

```
[forbidden: pattern, reason, alternative]
serena에 임시 캐시 저장, 메모리 비대화 (262→139 정리), praetorian_compact 사용
원문 그대로 저장, 토큰 낭비, TOON 압축 후 저장
모든 결과 영구화, 불필요한 중복, 중요 결정만 serena write_memory
```

## 에이전트 통합 규칙

### code-writer Agent
```yaml
WebFetch 후: praetorian_compact (web_research)
Task 완료 후: praetorian_compact (task_result)
에러 발생 시: historian/get_error_solutions 먼저 검색
최종 결정: serena/write_memory (decisions 타입)
```

### error-fixer Agent
```yaml
시작 시: historian/get_error_solutions (동일 에러 검색)
해결 후: praetorian_compact (decisions)
반복 에러: serena/write_memory (영구 패턴화)
```

### file-analyzer Agent
```yaml
분석 완료 후: praetorian_compact (flow_analysis)
대용량 로그: praetorian_compact 필수
핵심 인사이트만: serena/write_memory
```

## 토큰 절감 효과

```
[savings: scenario, before, after, reduction]
WebFetch 3 URLs, 4500 tokens, 300 tokens, 93%
Task 결과 2개, 3500 tokens, 300 tokens, 91%
아키텍처 논의, 5000 tokens, 300 tokens, 94%
총합 (세션), 14500 tokens, 1050 tokens, 93%
```

## 참조
- Praetorian: `.reference/claude-praetorian-mcp/`
- Historian: `.reference/claude-historian-mcp/`
- Serena: project.yml 설정
- shadcn: https://ui.shadcn.com/docs/mcp (공식 문서)

## shadcn MCP 사용 예시

```bash
# 컴포넌트 목록 조회
shadcn list-components

# 컴포넌트 검색
shadcn search-registry "dashboard"

# 컴포넌트 설치
shadcn install-component button
```

### 참조 리소스

```
[shadcn-resources: name, url, desc]
Magic UI, https://magicui.design, 150+ 애니메이션 컴포넌트
shadcn-admin, https://github.com/satnaing/shadcn-admin, 대시보드 템플릿
awesome-shadcn-ui, https://github.com/birobirobiro/awesome-shadcn-ui, 큐레이션 목록
```
