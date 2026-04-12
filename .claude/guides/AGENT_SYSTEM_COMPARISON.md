# Agent System 비교 분석: Reference System vs Spark Note

> **작성일**: 2025-12-06
> **목적**: Claude Code 공식 Marketplace Agent System과 우리 프로젝트의 Agent System 비교 분석
> **참조**: `.reference/agents/` (Claude Code Marketplace) vs `.claude/agents/` (Spark Note)

---

## 📊 Executive Summary

| 항목 | Reference System | Spark Note (우리) |
|------|-----------------|-------------------|
| **설계 철학** | 범용 AI Agent 시스템 | 단일 프로젝트 최적화 |
| **Agent 수** | 85개 | 66개 |
| **파일 총 수** | 307개 | 66개 (+44 guides) |
| **분류 방식** | 도메인/기술 기반 Plugin | 개발 생명주기 기반 Tier |
| **재사용성** | 높음 (Skills, Plugins) | 낮음 (프로젝트 특화) |
| **복잡도** | 높음 | 낮음 |
| **최적 대상** | 다중 프로젝트 조직 | 단일 프로젝트 팀 |

---

## 🏗️ 아키텍처 비교

### Reference System (`.reference/agents/`)

```
.reference/agents/
├── .claude-plugin/
│   └── marketplace.json          # 63개 플러그인 정의
├── plugins/                       # 63개 플러그인
│   ├── backend-development/       # 도메인별 그룹
│   │   ├── agents/               # 4개 전문 Agent
│   │   │   ├── backend-architect.md
│   │   │   ├── graphql-architect.md
│   │   │   └── ...
│   │   ├── commands/             # 슬래시 커맨드
│   │   │   └── feature-development.md
│   │   └── skills/               # 재사용 지식
│   │       ├── api-design-principles.md
│   │       └── ...
│   ├── python-development/
│   ├── kubernetes-operations/
│   └── ... (60개 더)
├── docs/
└── README.md
```

**핵심 개념:**
- **Plugin**: 단일 도메인의 Agent + Commands + Skills 묶음
- **Agent**: 특정 역할의 전문가 (예: backend-architect)
- **Command**: 슬래시 커맨드로 실행 가능한 워크플로우
- **Skill**: 재사용 가능한 지식 모듈 (Progressive Disclosure)

### Spark Note System (`.claude/agents/`)

```
.claude/agents/
├── 00-initialization/            # 프로젝트 초기화
│   └── project-initializer.md
├── 01-pre-analysis/              # 사전 분석
│   ├── tech-stack-analyzer.md
│   ├── code-quality-inspector.md
│   └── ...
├── 02-requirements/              # 요구사항
│   ├── epic-creator.md
│   └── story-creator.md
├── 03-design/                    # 설계
│   └── task-planner.md
├── 04-implementation/            # 구현
│   ├── code-writer.md
│   └── db-code-writer.md
├── 99-utils/                     # 유틸리티
│   ├── error-fixer.md
│   ├── commit-manager.md
│   └── quick-modifier.md
└── figma-clone-agents/           # 특수 목적
```

**핵심 개념:**
- **Tier**: 개발 생명주기 단계 (00 → 04 → 99)
- **Agent**: 단일 책임의 전문가
- **Guides**: 별도 폴더의 지식 문서 (`.claude/guides/`)

---

## 📁 파일 형식 비교

### Reference System Agent 형식

```yaml
---
name: backend-architect
description: Expert backend architect specializing in scalable API design...
model: sonnet
---

## Purpose
[에이전트 목적]

## Core Philosophy
[핵심 철학]

## Capabilities
### API Design & Patterns
- RESTful API design with proper resource modeling
- GraphQL schema design and resolver patterns
- ... (17개 항목)

### Microservices Architecture
- Service decomposition strategies
- ... (10개 항목)

## Behavioral Traits
[행동 특성]

## Workflow Position
[다른 에이전트와의 관계]

## Response Approach
1. Understand requirements
2. Analyze constraints
... (10단계)

## Example Interactions
[10가지 사용 예시]

## Key Distinctions
[다른 에이전트와 구분점]
```

**특징:**
- 매우 상세함 (200~300줄)
- Capabilities 섹션이 핵심
- 다른 Agent와의 관계 명시

### Spark Note Agent 형식

```yaml
---
subagent_type: utility
name: 99-utils/error-fixer
description: 에러 분석 및 수정 - 원칙 기반 간소화
tools: [Read, Write, Edit, MultiEdit, Grep, Glob, Bash]
disallowedTools: [TodoWrite]
---

## 역할
에러 및 테스트 실패를 체계적으로 분석하고 해결

## 언제 사용하는가?
- 테스트 실패
- 컴파일 에러
- 런타임 에러

## 동작 방식
1. 에러 분석
2. 원인 파악
3. 수정 코드 작성
```

**특징:**
- 간결함 (100~200줄)
- tools/disallowedTools 명시
- 한국어 안내

---

## 🎯 분류 체계 비교

### Reference System: 도메인/기술 기반

**63개 Plugin 카테고리:**

| 카테고리 | Plugin 수 | 예시 |
|---------|----------|------|
| Development | 4 | backend, frontend, fullstack, mobile |
| Languages | 7 | python, typescript, go, rust, java |
| Infrastructure | 5 | kubernetes, terraform, docker |
| Security | 4 | security-scanning, penetration-testing |
| AI & ML | 4 | ml-engineering, prompt-engineering |
| Database | 2 | database-administration, data-modeling |
| ... | ... | ... |

### Spark Note: 개발 생명주기 기반

**Tier 분류:**

| Tier | 역할 | Agent 수 |
|------|------|---------|
| 00-initialization | 프로젝트 초기화 | 1 |
| 01-pre-analysis | 사전 분석 | 9 |
| 02-requirements | 요구사항 정의 | 4 |
| 03-design | 설계 | 3 |
| 04-implementation | 구현 | 6 |
| 05-post-implementation | 후처리 | 1 |
| 99-utils | 유틸리티 | 13 |
| figma-clone-agents | 특수 목적 | 29 |

---

## 🔧 특수 기능 비교

### Progressive Disclosure (Reference System만)

**3-Tier 로딩 아키텍처:**

```
Tier 1: Metadata (항상 로드)
  - name, description
  - ~50 토큰

Tier 2: Instructions (활성화 시)
  - 상세 지침
  - ~200 토큰

Tier 3: Resources (요청 시)
  - 예제, 템플릿
  - ~500+ 토큰
```

**토큰 효율성:**
- 기본: ~300 토큰
- 전체 활성화: ~800 토큰
- 필요한 것만 로드 → 비용 절감

### Guides System (Spark Note)

```
.claude/guides/
├── UI_DESIGN_SYSTEM.md
├── CODE_PATTERNS.md
├── DATABASE_SCHEMA_RULES.md
├── AGENT_CLI_FLAG_GUIDE.md
└── ... (44개)
```

**특징:**
- Agent에서 `@.claude/guides/...` 형태로 참조
- 명시적이지만 수동 관리
- Progressive Disclosure 없음

---

## 🔄 Multi-Agent 오케스트레이션 비교

### Reference System: 명시적 오케스트레이터

```yaml
# 15개의 명시적 오케스트레이터
orchestrators/
├── full-stack-orchestration.md
├── api-development-workflow.md
├── microservices-deployment.md
└── ...
```

**워크플로우 예시:**
```
/full-stack-orchestration:full-stack-feature
  → backend-architect (설계)
  → frontend-architect (UI 설계)
  → tdd-orchestrator (테스트)
  → code-writer (구현)
  → debugger (검증)
```

### Spark Note: 암묵적 체인

```yaml
# CLAUDE.md의 Agent 체인 규칙
Agent 체인:
  Epic: epic-creator → story-creator → task-planner → code-writer
  Story: story-creator → task-planner → code-writer
  Task: task-planner → code-writer
```

**특징:**
- 규칙 기반 암묵적 체인
- 문서로 정의, 코드로 강제하지 않음

---

## ⚖️ 장단점 분석

### Reference System

| 장점 | 단점 |
|------|------|
| ✅ 높은 재사용성 | ❌ 높은 복잡도 |
| ✅ 모듈식 구조 (Plugin) | ❌ 초기 학습 곡선 |
| ✅ 토큰 효율성 (Progressive Disclosure) | ❌ 프로젝트 특화 어려움 |
| ✅ 85개 전문 Agent | ❌ 작은 프로젝트에 과도함 |
| ✅ 47개 재사용 Skill | ❌ 설정 복잡 |
| ✅ 명시적 오케스트레이션 | |

### Spark Note System

| 장점 | 단점 |
|------|------|
| ✅ 단순한 구조 | ❌ 낮은 재사용성 |
| ✅ 프로젝트 특화 | ❌ 다른 프로젝트 이식 어려움 |
| ✅ 명확한 생명주기 진행 | ❌ Skills 개념 없음 |
| ✅ 한국어 지원 | ❌ Multi-agent 암묵적 |
| ✅ 빠른 온보딩 | ❌ 확장성 제한 |
| ✅ Hook 시스템 통합 | |

---

## 💡 채택 가능한 패턴

Reference System에서 Spark Note로 가져올 수 있는 패턴:

### 1. Skills 개념 도입 (권장)

```
.claude/agents/skills/              # 신규 폴더
├── nextjs-app-router-patterns.md   # Next.js 패턴
├── fastapi-cqrs-patterns.md        # FastAPI 패턴
├── prisma-schema-patterns.md       # Prisma 패턴
├── shadcn-ui-patterns.md           # UI 패턴
└── tanstack-query-patterns.md      # 데이터 페칭 패턴
```

**장점:**
- Guides보다 더 구조화된 지식
- Agent에서 `@skills/...` 형태로 참조
- 토큰 효율성 향상

### 2. Model 필드 표준화 (권장)

```yaml
# Reference System 패턴
model: haiku   # 간단한 작업
model: sonnet  # 복잡한 추론

# 우리 프로젝트 적용
99-utils/quick-modifier:     model: haiku
99-utils/commit-manager:     model: haiku
04-implementation/code-writer: model: sonnet
02-requirements/epic-creator:  model: opus
```

### 3. 오케스트레이터 명시화 (선택)

```
.claude/agents/orchestrators/       # 신규 폴더
├── feature-development.md          # 기능 개발 워크플로우
├── bug-fix-workflow.md             # 버그 수정 워크플로우
├── refactoring.md                  # 리팩토링 워크플로우
└── full-epic-delivery.md           # Epic 전체 전달
```

### 4. Plugin 개념 부분 도입 (선택)

현재 Tier 구조를 유지하면서 논리적 그룹화:

```yaml
# 논리적 Plugin 그룹 (폴더 구조는 유지)
analysis-plugin:
  - 01-pre-analysis/*

planning-plugin:
  - 02-requirements/*
  - 03-design/*

implementation-plugin:
  - 04-implementation/*

utility-plugin:
  - 99-utils/*
```

---

## 🎯 권장 사항

### 즉시 적용 (Low Effort, High Value)

1. **model 필드 표준화**
   - 모든 66개 Agent에 model 필드 추가
   - 예상 비용 절감: 30-50%

2. **tools 필드 완성**
   - 누락된 24개 Agent에 tools 명시
   - 보안 강화

### 중기 적용 (Medium Effort)

3. **Skills 폴더 도입**
   - 기존 Guides를 Skills로 재구조화
   - Progressive Disclosure 적용

### 장기 고려 (High Effort)

4. **오케스트레이터 명시화**
   - 현재 암묵적 체인을 명시적 정의로

5. **Plugin 개념 부분 도입**
   - 재사용성 향상 필요 시

---

## 📚 관련 문서

- Agent CLI Flag Guide: @.claude/guides/AGENT_CLI_FLAG_GUIDE.md
- Agent 체인 규칙: @.claude/guides/AGENT_CHAIN_RULES.md
- Reference System 원본: @.reference/agents/README.md

---

## 📝 변경 이력

| 날짜 | 변경 내용 |
|------|----------|
| 2025-12-06 | 초기 작성 - Reference System vs Spark Note 비교 분석 |
