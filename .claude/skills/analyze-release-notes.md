---
description: "Claude Code 패치노트 분석 → 현재 agent/skill/hook 워크플로우 반영 항목 식별"
argument-hint: "버전 범위 (예: 2.1.30~2.1.33) 또는 비워두면 컨텍스트의 /release-notes 사용"
---

# Release Notes Analyzer

> `/release-notes` 실행 후 호출. 패치노트와 현재 `.claude/` 체계를 대조하여 반영할 항목을 식별.

## 실행 순서

### Phase 1: 패치노트 파싱

컨텍스트에 있는 `/release-notes` 출력에서 항목을 추출한다.
$ARGUMENTS가 있으면 해당 버전 범위만 필터링한다.

각 항목을 아래 카테고리로 분류:

| 카테고리 | 설명 | 예시 |
|---------|------|------|
| **Agent/Subagent** | Task tool, agent frontmatter, model 관련 | agent teams, model customization |
| **Skill/Command** | skill frontmatter, slash command 관련 | context: fork, allowed-tools YAML |
| **Hook** | hook event, lifecycle 관련 | SessionStart, PreToolUse |
| **MCP** | MCP server, tool search 관련 | OAuth, streamable HTTP |
| **Permission** | 권한, sandbox, 보안 관련 | wildcard syntax, bash rules |
| **Session** | session management, resume 관련 | named sessions, fork |
| **UI/Terminal** | UI 렌더링, 입력 관련 | 분석 대상 아님 (Skip) |
| **SDK** | SDK 전용 변경 | 분석 대상 아님 (Skip) |
| **Bugfix** | 버그 수정 | 우리가 겪은 이슈면 반영 |

### Phase 2: 현재 체계 스캔

다음 경로를 탐색하여 현재 설정 파악:

```
.claude/
  agents/         → frontmatter (model, tools, memory, hooks, permissionMode)
  skills/         → frontmatter (context, agent, model, allowed-tools)
  hooks/          → hook 이벤트 타입, 설정
  squads/         → 스쿼드 편성 템플릿
  rules/          → 코딩 규칙
  settings.json   → 프로젝트 설정

CLAUDE.md         → 워크플로우 규칙, 라우팅, Memory MCP
.claude/CLAUDE.md → 범용 규칙
```

### Phase 3: 대조 분석

각 패치노트 항목을 현재 체계와 대조:

**판단 기준:**

1. **반영 필수** (Breaking/Deprecation)
   - 기존 설정이 deprecated → 마이그레이션 필요
   - 기본 동작 변경 → 기존 workflow가 깨질 수 있음
   - 보안 취약점 수정 → 즉시 적용

2. **반영 권장** (New Capability)
   - 새 frontmatter 필드 → 기존 agent/skill 개선 가능
   - 새 hook 이벤트 → 워크플로우 자동화 강화
   - 새 기능 → 현재 workaround를 대체 가능

3. **참고** (Nice-to-know)
   - 성능 개선 → 설정 변경 없이 자동 적용
   - 새 도구 → 미래 활용 가능
   - 버그 수정 → 겪지 않은 이슈

4. **무관** (Skip)
   - UI/터미널 렌더링 변경
   - SDK 전용 변경
   - Windows/WSL 전용

### Phase 4: 결과 출력

아래 형식으로 출력한다:

```
============================================================
RELEASE NOTES ANALYSIS: v{from} ~ v{to}
============================================================
분석일: {datetime}
대상 버전: {count}개
총 변경사항: {total}개 (반영필수: {n}, 반영권장: {n}, 참고: {n})

## 반영 필수 (Breaking/Deprecation)

| # | 버전 | 변경사항 | 영향 받는 파일 | 조치 |
|---|------|---------|--------------|------|
| 1 | v2.x | [내용] | .claude/agents/... | [구체적 조치] |

## 반영 권장 (New Capability)

| # | 버전 | 변경사항 | 활용 대상 | 개선 효과 |
|---|------|---------|----------|----------|
| 1 | v2.x | [내용] | [agent/skill/hook] | [효과] |

## 참고 (Nice-to-know)

| # | 버전 | 변경사항 | 비고 |
|---|------|---------|------|
| 1 | v2.x | [내용] | [간단 코멘트] |

## 즉시 실행 가능한 액션

1. [ ] [구체적 조치 1] - 대상: [파일]
2. [ ] [구체적 조치 2] - 대상: [파일]

## CLAUDE.md 업데이트 제안

[CLAUDE.md에 추가/수정할 내용이 있으면 diff 형태로 제안]
============================================================
```

## 분석 시 주의사항

- **현재 체계에 없는 기능은 YAGNI** - "쓸 수 있다"와 "써야 한다"는 다름
- **Workaround 대체 우선** - 기존에 복잡하게 구현한 것을 네이티브로 대체 가능하면 권장
- **Breaking change 최우선** - deprecated 기능을 쓰고 있으면 즉시 알림
- **버전 순서대로 분석** - 이전 버전 변경이 이후 버전에서 수정/보완되었을 수 있음

## 추가 액션 (선택)

분석 결과를 serena memory에 저장할지 물어본다:
- 저장하면 다음 분석 시 이전 결과와 비교 가능
- memory key: `release-notes-analysis-v{latest_version}`
