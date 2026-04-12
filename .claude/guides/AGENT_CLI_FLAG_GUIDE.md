# Claude Code 2.0.59 `--agent` CLI Flag Guide

> **작성일**: 2025-12-05
> **버전**: Claude Code 2.0.59+
> **목적**: 새로운 `--agent` CLI 플래그의 활용 방법 및 기존 시스템과의 통합 가이드

---

## 📋 개요

Claude Code 2.0.59에서 추가된 `--agent` CLI 플래그는 **세션 시작 시 특정 agent 모드로 main thread를 구성**하는 기능입니다.

### 핵심 개념: 두 가지 실행 모드

| 구분 | Delegation Mode (기존) | Direct Mode (신규) |
|------|----------------------|-------------------|
| **호출 방식** | `Task --subagent_type` | `claude --agent` |
| **컨텍스트** | 기존 대화 상속 | 깨끗한 시작 |
| **용도** | 복잡한 대화 중 부분 위임 | 단일 목적 자동화 |
| **비유** | 회의 중 전문가 초대 | 단일 CLI 유틸리티 |

---

## 🚀 기본 사용법

### 단일 Agent 지정 (`--agent`)

```bash
# 저장된 agent 사용 (.claude/agents/ 에 있는 agent)
claude --agent 99-utils/error-fixer

# 에러 수정 전용 세션 시작
claude --agent 99-utils/error-fixer

# 자동화 스크립트에서 사용
claude --agent 99-utils/commit-manager --print "변경사항 커밋"
```

### 여러 Agent 정의 (`--agents`)

**주의**: `--agent`는 단일 agent만, `--agents`는 여러 agent를 JSON으로 정의

```bash
claude --agents '{
  "code-reviewer": {
    "description": "코드 리뷰어",
    "prompt": "코드 품질과 보안에 집중하세요",
    "tools": ["Read", "Grep", "Edit"]
  },
  "debugger": {
    "description": "디버깅 전문가",
    "prompt": "TypeScript 디버깅 전문가입니다",
    "tools": ["Read", "Bash", "Write"]
  }
}'
```

---

## 📁 Agent 파일 형식

### YAML Frontmatter 구조

```yaml
---
subagent_type: utility
name: 99-utils/error-fixer
description: 에러 분석 및 수정 - 원칙 기반 간소화
tools: [Read, Write, Edit, MultiEdit, Grep, Glob, Bash]
disallowedTools: [TodoWrite]
model: sonnet  # 선택사항: haiku, sonnet, opus
---

# Agent의 시스템 프롬프트 (Markdown 본문)
에러를 분석하고 수정하는 전문 Agent입니다...
```

### 필수/권장 필드

| 필드 | 필수 | 설명 |
|------|------|------|
| `subagent_type` | ✅ | Agent 카테고리 (utility, implementation 등) |
| `name` | ✅ | 고유 식별자 (`XX-category/agent-name`) |
| `description` | ✅ | 한 줄 설명 |
| `tools` | ⭐ 권장 | 허용된 도구 목록 (보안상 필수) |
| `disallowedTools` | ❌ 선택 | 금지된 도구 목록 |
| `model` | ⭐ 권장 | 사용 모델 (비용 최적화) |

---

## 🎯 활용 시나리오

### A. CI/CD 자동화 (가장 높은 가치)

```bash
# GitHub Actions에서 자동 에러 수정
claude --agent 99-utils/error-fixer --print "빌드 에러 수정"

# 자동 커밋 메시지 생성
claude --agent 99-utils/commit-manager --print "변경사항 커밋"

# Pre-commit hook으로 코드 검사
claude --agent 99-utils/quick-modifier --print "린트 에러 자동 수정"
```

### B. Git Alias 통합

```bash
# ~/.gitconfig
[alias]
  smart-commit = !claude --agent 99-utils/commit-manager --print "커밋해줘"
  fix-errors = !claude --agent 99-utils/error-fixer --print "에러 수정"
```

### C. 단일 목적 세션

```bash
# 에러 수정만 하는 세션
claude --agent 99-utils/error-fixer

# DB 작업만 하는 세션 (다른 도구 차단)
claude --agent 04-implementation/db-code-writer
```

---

## ⚖️ 기존 워크플로우와의 비교

### 언제 `--agent`를 사용?

| 상황 | 권장 방식 | 이유 |
|------|----------|------|
| CI/CD 자동화 | `--agent` | 깨끗한 컨텍스트, 예측 가능 |
| Git alias | `--agent` | 단일 목적, 빠른 실행 |
| 복잡한 개발 세션 | 기존 방식 | 유연한 agent 전환 |
| 대화형 작업 | 기존 방식 | 컨텍스트 유지 필요 |

### 현재 프로젝트 권장 사항

```yaml
일반 개발 세션:
  # --agent 없이 시작 (66개 agent 자동 로드)
  claude

  # 필요할 때 Task로 호출
  → Task --subagent_type 99-utils/error-fixer

자동화/스크립트:
  # --agent로 직접 시작
  claude --agent 99-utils/commit-manager --print "커밋"
```

---

## 🔧 시스템 호환성

### 현재 상태 (okr2 프로젝트)

```yaml
호환성:
  ✅ Frontmatter 형식: 100% 호환
  ✅ Hook 통합: 100% 호환
  ⚠️ tools 필드: 63% 완성 (24개 누락)
  ❌ model 필드: 0% (미사용)

개선 필요:
  - P0: tools 필드 24개 완성 (보안)
  - P1: model 필드 66개 추가 (비용 최적화)
```

### 권장 모델 설정

```yaml
haiku (저비용, 빠름):
  - 99-utils/quick-modifier
  - 99-utils/commit-manager
  - 포매터, 린터 류

sonnet (균형):
  - 04-implementation/code-writer
  - 99-utils/error-fixer
  - 대부분의 코드 생성

opus (고성능):
  - 02-requirements/epic-creator
  - 01-pre-analysis/business-analyzer
  - 복잡한 분석/설계
```

---

## ⚠️ 주의사항

### 1. Agent는 모드에 무관하게 동작해야 함

```yaml
❌ 안티패턴:
  if (--agent mode):
    다르게 동작
  else:
    기본 동작

✅ 올바른 패턴:
  - interactive-refactorer (대화형)
  - ci-refactor-script (자동화용)
  → 별도 agent로 분리
```

### 2. tools 필드 누락 = 보안 위험

```yaml
문제:
  - tools 필드 없으면 모든 도구 허용 가능
  - 의도치 않은 파일시스템/쉘 접근

해결:
  - 모든 agent에 tools 명시
  - 도구 불필요 시 tools: [] 로 명시적 차단
```

### 3. `--agent` vs `--agents` 혼동 주의

```bash
# --agent (단수): 기존 agent 1개 선택
claude --agent my-agent

# --agents (복수): JSON으로 여러 agent 정의
claude --agents '{"a": {...}, "b": {...}}'
```

---

## 📚 관련 문서

- Agent 체인 규칙: @.claude/guides/AGENT_CHAIN_RULES.md
- 병렬 실행: @.claude/guides/PARALLEL_EXECUTION_GUIDE.md
- 자동 워크플로우: @.claude/guides/AUTO_WORKFLOW_GUIDE.md

---

## 🔄 Background Agent (2.0.60+)

### 개요

Claude Code 2.0.60에서 추가된 **Background Agent Support**는 Agent가 메인 스레드와 독립적으로 백그라운드에서 실행되는 기능입니다.

```yaml
핵심 차이:
  기존 Subagent: 호출 → 완료 대기 → 결과 반환 (동기)
  Background Agent: 호출 → 병렬 실행 → 사용자 계속 작업 (비동기)
```

### 설정 방법

Agent 파일에 `background: true` 추가:

```yaml
---
name: test-watcher
description: Run tests PROACTIVELY after every code change.
tools: [Bash, Read, Grep]
model: haiku  # 비용 절감을 위해 경량 모델 권장
background: true  # ← 핵심 설정
---

테스트를 자동으로 실행하고 결과를 보고합니다...
```

### 프로젝트 적용 Agent

| Agent | 용도 | 위치 |
|-------|------|------|
| `test-watcher` | 코드 변경 시 자동 테스트 | `.claude/agents/99-utils/test-watcher.md` |
| `docs-sync` | 문서 자동 동기화 | `.claude/agents/99-utils/docs-sync.md` |

### 사용 시나리오

```bash
# 시나리오 1: 개발 중 자동 테스트
사용자: "auth 모듈 리팩토링해줘"
→ code-writer: 코드 수정
→ test-watcher (백그라운드): 자동 테스트 실행
→ 사용자: 대기 없이 다음 작업 요청 가능

# 시나리오 2: 문서 자동 갱신
사용자: "API 엔드포인트 추가해줘"
→ code-writer: API 구현
→ docs-sync (백그라운드): api-contract.md 자동 업데이트
```

### 주의사항

| 제한사항 | 해결책 |
|---------|--------|
| **비용 증가** | `haiku` 모델 사용 (저비용) |
| **컨텍스트 분리** | 파일 기반 통신 (.log, .md) |
| **순서 보장 불가** | 독립적 작업만 백그라운드 배정 |
| **디버깅 어려움** | 결과를 로그 파일에 기록 |

### Hook 연동 예시

```json
{
  "event": "PostToolUse",
  "matcher": { "tool_name": ["Edit", "Write"] },
  "command": "claude --agent 99-utils/test-watcher --background"
}
```

---

## 📝 변경 이력

| 날짜 | 변경 내용 |
|------|----------|
| 2025-12-06 | Background Agent 섹션 추가 - Claude Code 2.0.60 기준 |
| 2025-12-05 | 초기 작성 - Claude Code 2.0.59 기준 |
