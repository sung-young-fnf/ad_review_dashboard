---
name: changelog
description: "Claude SDK/Code changelog 분석 및 코드베이스 영향 평가. Use when: SDK 업그레이드, 새 버전 확인, Claude Code 업데이트 후 변경사항 파악"
effort: medium
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - WebFetch
  - WebSearch
  - Agent
  - mcp__serena__write_memory
  - mcp__serena__read_memory
  - mcp__praetorian__praetorian_compact
user-invocable: true
context: fork
---

# Changelog Skill

> "Claude SDK/Code 버전 Changelog을 한 명령으로 분석 -> 영향평가 -> 적용까지 완료"

## WHY

Claude Code/SDK 업데이트 분석은 반복적 수작업:
1. GitHub Releases 또는 npm에서 changelog 찾기
2. 변경사항 하나하나 읽기
3. 코드베이스에서 영향받는 곳 검색
4. 적용 여부 판단
5. 코드 수정 + 테스트

6회+ 수동 반복된 워크플로우를 **원커맨드로 자동화**한다.

**기존 스킬과의 관계:**
- `/dep-upgrade`: 범용 패키지 업그레이드 (npm 전체 대상)
- `/analyze-release-notes`: `/release-notes` 실행 후 사후 분석 (패치노트 입력 필요)
- `/changelog` (이 스킬): Claude SDK/Code 전문 + fetch부터 적용까지 원스톱

## 사용법

```bash
# 특정 버전 분석
/changelog 2.1.105

# 최신 버전 자동 감지 — Claude Code + Agent SDK 둘 다 분석
/changelog

# 버전 범위 분석
/changelog 2.1.100..2.1.105

# Agent SDK만 분석
/changelog sdk 0.2.99

# Claude Code만 분석
/changelog cc 2.1.105

# 로컬 파일로 분석 (fetch 실패 시)
/changelog --file /path/to/changelog.md
```

## 4-Phase 워크플로우

### Phase 1: Version Detect (현재 상태 파악)

$ARGUMENTS를 파싱하여 분석 대상 결정:

**인자 파싱 규칙:**
- 숫자로 시작 (예: `2.1.105`) -> Claude Code 특정 버전
- `cc` + 버전 (예: `cc 2.1.105`) -> Claude Code만 특정 버전
- `sdk` + 버전 (예: `sdk 0.2.99`) -> Agent SDK만 특정 버전
- 범위 (예: `2.1.100..2.1.105`) -> 해당 범위 전체
- `--file {path}` -> 로컬 파일에서 changelog 읽기
- **인자 없음 -> Claude Code + Agent SDK 둘 다 자동 분석** (현재 설치 버전 감지 → 최신 비교)

**현재 버전 감지:**
```bash
# Claude Code 버전
claude --version 2>/dev/null || echo "claude CLI not found"

# Agent SDK 버전 (ai-agent + sandbox에서 사용)
Grep "@anthropic-ai/claude-agent-sdk" --glob "apps/**/package.json" --output_mode content
```

**인자 없음일 때 동작:**
1. Claude Code 현재 버전 감지 → npm latest와 비교 → 차이 있으면 분석
2. Agent SDK 현재 버전 감지 → npm latest와 비교 → 차이 있으면 분석
3. 둘 다 최신이면 "모두 최신 버전입니다" 안내
4. 하나라도 차이 있으면 각각 Phase 2~4 수행 후 **통합 리포트** 출력

**이미 분석된 버전 확인:**
```bash
# serena 메모리에서 기존 분석 확인
mcp__serena__read_memory({ name: "changelog-analysis-v{version}" })
```
- 이미 분석됨 -> "v{version}은 {날짜}에 분석 완료. 재분석할까요?" 안내
- 미분석 -> Phase 2 진행

### Phase 2: Changelog Fetch

**소스별 fetch 전략:**

#### Claude Code
우선순위 순서:
1. **GitHub Releases API**: `WebFetch https://github.com/anthropics/claude-code/releases/tag/%40anthropic-ai%2Fclaude-code%40{version}`
2. **npm changelog**: `WebFetch https://www.npmjs.com/package/@anthropic-ai/claude-code/v/{version}`
3. **CHANGELOG.md 직접**: `WebFetch https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`

#### Agent SDK
우선순위 순서:
1. **GitHub Releases**: `WebFetch https://github.com/anthropics/claude-code/releases/tag/%40anthropic-ai%2Fclaude-agent-sdk%40{version}`
2. **npm**: `WebFetch https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk/v/{version}`

#### Fallback
모든 자동 fetch 실패 시:
```
Changelog를 자동으로 가져오지 못했습니다.
아래 중 하나를 선택하세요:
  A) changelog 직접 붙여넣기
  B) 로컬 파일 경로 제공
  C) WebSearch로 검색 시도
```

**Fetch 결과 파싱:**
- 각 변경사항을 개별 항목으로 분리
- 항목별 카테고리 태깅:
  - `breaking` - API 변경, 삭제, 기본값 변경
  - `feature` - 새 기능, 새 옵션
  - `fix` - 버그 수정
  - `perf` - 성능 개선
  - `docs` - 문서 변경

### Phase 3: Impact Mapping (코드베이스 영향 분석)

각 변경사항에서 키워드를 추출하고 코드베이스 검색:

**키워드 추출 대상:**
- API 이름 (함수, 클래스, 메서드)
- 설정 키 (frontmatter 필드, settings.json 키)
- Hook 이벤트 이름
- CLI 플래그/옵션

**검색 범위:**
```bash
# 1. .claude/ 설정 전체
Grep "{keyword}" --glob ".claude/**/*"

# 2. Hook 스크립트
Grep "{keyword}" --glob ".claude/hooks/**/*"

# 3. Agent/Skill 정의
Grep "{keyword}" --glob ".claude/agents/**/*" --glob ".claude/skills/**/*"

# 4. 소스 코드 (SDK 사용처)
Grep "{keyword}" --glob "apps/**/src/**/*.ts" --glob "apps/**/src/**/*.tsx"

# 5. CLAUDE.md 규칙
Grep "{keyword}" --glob "**/CLAUDE.md"
```

**영향도 분류:**

| 영향도 | 기준 | 아이콘 |
|--------|------|--------|
| Breaking | 현재 사용 중인 API/설정이 변경/삭제됨 | 🔴 |
| Adopt | 새 기능이 현재 workaround를 대체 가능 | 🟢 |
| Relevant Fix | 겪고 있던 버그가 수정됨 | 🟡 |
| No Impact | 사용하지 않는 영역의 변경 | ⚪ |

### Phase 4: Report (구조화 출력)

```markdown
## Changelog Impact Analysis: v{version}

분석일: {YYYY-MM-DD}
현재 버전: v{current} -> 대상: v{target}

### 🔴 Breaking Changes (즉시 조치 필요)

| # | 변경사항 | 영향 파일 | 현재 코드 | 필요 조치 |
|---|---------|----------|----------|----------|
| 1 | {설명} | {파일:라인} | {현재 사용 패턴} | {구체적 수정 방법} |

### 🟢 New Features to Adopt (적용 권장)

| # | 변경사항 | 활용 대상 | Before (현재) | After (개선) |
|---|---------|----------|-------------|-------------|
| 1 | {설명} | {파일/설정} | {현재 방식} | {개선 방식} |

### 🟡 Bug Fixes Relevant to Us

| # | 변경사항 | 관련 이슈 | 비고 |
|---|---------|----------|------|
| 1 | {설명} | {우리가 겪은 증상} | {추가 조치 여부} |

### ⚪ No Impact (참고)

- {변경1}: {간단 이유}
- {변경2}: {간단 이유}

---

### 요약

| 분류 | 건수 |
|------|------|
| 🔴 Breaking | {n} |
| 🟢 Adopt | {n} |
| 🟡 Fix | {n} |
| ⚪ Skip | {n} |

### 다음 단계

- "apply" -> 🔴 Breaking + 🟢 Adopt 항목 자동 적용 (code-writer Agent 위임)
- "breaking만" -> 🔴 항목만 적용
- "저장" -> serena 메모리에 분석 결과 저장
- "끝" -> 종료
```

## Apply 모드

사용자가 "apply" 입력 시:

**실행 순서:**
1. 🔴 Breaking Changes 먼저 수정 (순서 보장)
2. 🟢 Adopt 항목 적용
3. 각 변경 후 `pnpm tsc --noEmit` 검증
4. 모든 변경 완료 후 `pnpm build` 최종 검증

**커밋 메시지:**
```
[agent:changelog] feat(deps): apply changelog v{version}

Applied changes:
- [breaking] {항목1}
- [adopt] {항목2}
```

**code-writer Agent 위임:**
대형 변경(5파일+)은 code-writer Agent에 위임하여 처리.
소형 변경(1-4파일)은 직접 Edit으로 적용.

## 이력 관리

분석 완료 후 자동 저장:
```bash
mcp__serena__write_memory({
  memory_file_name: "changelog-analysis-v{version}",
  content: "# Changelog Analysis: v{version}\n\nDate: {date}\nBreaking: {n}\nAdopt: {n}\nFix: {n}\nApplied: [pending/done]\n\n## Key Changes\n{요약}"
})
```

**자동 메모리 레퍼런스 업데이트:**
분석 완료 후 `reference_claude_code_changelog.md` 자동 메모리 파일에도 최신 분석 버전 반영:
```bash
# 기존 자동 메모리 파일 업데이트
# /Users/yun/.claude/projects/-Users-yun-work-ai-mcp-mcp-orch/memory/reference_claude_code_changelog.md
```

## 범위 분석 모드 (버전 범위)

`/changelog 2.1.100..2.1.105` 실행 시:

1. 범위 내 모든 버전 changelog fetch
2. 버전별로 Phase 3 수행
3. 중복 제거 (이전 버전 변경이 이후에 수정된 경우)
4. 통합 Impact Table 출력
5. 버전별 하이라이트 섹션 추가

## 오류 처리

| 상황 | 행동 |
|------|------|
| WebFetch 실패 | Fallback 안내 (붙여넣기/로컬파일/WebSearch) |
| 버전 없음 | "v{version}을 찾을 수 없습니다. 최신 버전: v{latest}" |
| 분석 완료 후 적용 실패 | 실패 항목 보고 + 수동 수정 안내 |
| 이미 분석됨 | "재분석할까요?" 확인 |

## praetorian 압축

분석 완료 후 세션 컨텍스트 압축:
```bash
mcp__praetorian__praetorian_compact({
  summary: "Changelog v{version} 분석 완료. Breaking: {n}, Adopt: {n}, Fix: {n}. Applied: {yes/no}"
})
```
