# Agent System Portability Guide

> **목적**: `.claude` Agent 시스템을 다른 프로젝트에 재사용할 때 필요한 파일 분류 및 초기화 가이드

---

## 📁 파일 분류: 범용 vs 프로젝트별

### 🟢 `.claude/` - 범용 시스템 (그대로 복사)

**Agent 엔진 및 워크플로우** - 모든 프로젝트에서 재사용 가능:
- `agents/` - 69개 Agent 정의 (01-pre-analysis, 02-requirements, 03-design, 04-implementation, 99-utils)
- `commands/` - Slash Command 정의
- `hooks/` - Reddit Hook System (pre/post hooks)
- `guides/` - Agent 개발 가이드라인 (범용)
- `templates/` - Agent 템플릿
- `utils/` - 유틸리티 스크립트

**설정 파일**:
- `CLAUDE.md` - Agent 시스템 규칙 (범용)
- `AGENT_CATALOG.md` - Agent 카탈로그
- `CLAUDE_INTEGRATION_GUIDE.md` - 통합 가이드

**재사용 방식**: 전체 디렉토리 복사 → 프로젝트별 초기화

---

### 🔴 `docs/` - 프로젝트별 컨텍스트 (새 프로젝트마다 생성)

#### ✅ `.claude/`로 이동해야 하는 파일 (범용 가이드)

**1. UI/UX 디자인 시스템** - `docs/guides/` → `.claude/guides/`
```
✅ 이동 필요:
- docs/guides/ui-design-system.md         → .claude/guides/UI_DESIGN_SYSTEM.md
- docs/guides/aesthetic-directions.md      → .claude/guides/AESTHETIC_DIRECTIONS.md
- docs/guides/accessibility-guidelines.md  → .claude/guides/ACCESSIBILITY_GUIDELINES.md

이유: shadcn/ui 기반 디자인 시스템은 범용 가이드
     (프로젝트별 커스텀 테마만 docs/analysis/ui-theme.md에 작성)
```

**2. 공통 코딩 패턴** - `docs/patterns/` → `.claude/patterns/` (새 디렉토리)
```
✅ 이동 필요:
- docs/patterns/INDEX.md                   → .claude/patterns/INDEX.md
- docs/patterns/README.md                  → .claude/patterns/README.md
- docs/patterns/fsd-pattern.md             → .claude/patterns/fsd-pattern.md
- docs/patterns/nextauth-pattern.md        → .claude/patterns/nextauth-pattern.md
- docs/patterns/prisma-pattern.md          → .claude/patterns/prisma-pattern.md
- docs/patterns/fullstack/                 → .claude/patterns/fullstack/
  - admin-impersonation.md
  - environment-variables.md
  - api-routes.md
  - api-route-data-transformation.md
- docs/patterns/frontend/                  → .claude/patterns/frontend/
  - react-component-type-safety.md
- docs/patterns/backend/                   → .claude/patterns/backend/
  - jwt-authentication-error-handling.md
- docs/patterns/debugging/                 → .claude/patterns/debugging/
  - api-response-field-mapping.md

이유: Next.js, NestJS, Prisma 등 범용 프레임워크 패턴
     (프로젝트별 커스텀 패턴만 docs/patterns/custom/에 작성)
```

#### ❌ `docs/`에 남겨야 하는 파일 (프로젝트별)

**1. 프로젝트 분석 결과** - `docs/analysis/`
```
❌ 이동 불가 (프로젝트별):
- code-structure.md          - 현재 프로젝트 아키텍처
- tech-stack.md              - 현재 프로젝트 기술 스택
- database-schema.md         - 현재 프로젝트 DB 스키마 (sparknote)
- business-domain.md         - 현재 프로젝트 비즈니스 도메인
- debugging-workflow.md      - 현재 프로젝트 디버깅 워크플로우
- screenshot-analysis-workflow.md
- data-fetching-patterns.md  - 프로젝트별 데이터 페칭 전략

이유: 새 프로젝트는 01-pre-analysis Agent로 새로 생성
```

**2. 프로젝트 히스토리** - `docs/epics/`, `docs/stories/`, `docs/tasks/`
```
❌ 이동 불가 (프로젝트별):
- epics/                     - Epic 문서 (EP001, EP002, ...)
- stories/                   - Story 문서 (S001, S002, ...)
- tasks/                     - Task 문서 (T001, T002, ...)
- _archived/                 - 완료된 Epic/Story/Task

이유: 현재 프로젝트 개발 히스토리 (새 프로젝트는 빈 폴더로 시작)
```

**3. 프로젝트별 커스텀 패턴** - `docs/patterns/custom/` (새 디렉토리)
```
❌ 이동 불가 (프로젝트별):
- api-auth-pattern.md        - 현재 프로젝트 인증 패턴 (MS Entra ID)
- component-reuse-pattern.md - SparkNoteSidebar 재사용 케이스

이유: 프로젝트별 특수한 패턴 (범용 아님)
```

**4. 기타 프로젝트별 문서**
```
❌ 이동 불가:
- PROGRESS.md                - 현재 진행 상황
- figma-migration/           - Figma 마이그레이션 문서
- deployment/                - 배포 문서
- design/                    - 디자인 문서
- reference/                 - Reference 문서
- requirements/              - 요구사항 문서
```

---

## 🚀 새 프로젝트 초기화 워크플로우

### Step 1: Agent 시스템 복사
```bash
# 1. .claude 디렉토리 전체 복사
cp -r /path/to/okr2/.claude /path/to/new-project/.claude

# 2. 범용 가이드 추가 (okr2에서 이동)
mkdir -p /path/to/new-project/.claude/guides
cp /path/to/okr2/docs/guides/*.md /path/to/new-project/.claude/guides/

# 3. 범용 패턴 추가 (okr2에서 이동)
mkdir -p /path/to/new-project/.claude/patterns
cp -r /path/to/okr2/docs/patterns/* /path/to/new-project/.claude/patterns/
# (custom/ 제외)
```

### Step 2: 프로젝트별 docs 초기화
```bash
# 1. docs 기본 구조 생성
mkdir -p /path/to/new-project/docs/{analysis,epics,stories,tasks,patterns/custom,_archived}

# 2. PROGRESS.md 생성
cat > /path/to/new-project/docs/PROGRESS.md << 'EOF'
# Project Progress Tracker

## Active Epics
(없음)

## Completed Epics
(없음)

## Backlog
(없음)
EOF
```

### Step 3: 프로젝트 분석 (Agent 자동 실행)
```bash
# 01-pre-analysis Agent 체인 자동 실행
Task --subagent_type "01-pre-analysis/tech-stack-analyzer" --prompt "새 프로젝트 기술 스택 분석"
# → docs/analysis/tech-stack.md 생성

Task --subagent_type "01-pre-analysis/code-structure-analyzer" --prompt "코드 구조 분석"
# → docs/analysis/code-structure.md 생성

Task --subagent_type "01-pre-analysis/comprehensive-db-analyzer" --prompt "데이터베이스 분석"
# → docs/analysis/database-schema.md 생성

Task --subagent_type "01-pre-analysis/business-analyzer" --prompt "비즈니스 도메인 분석"
# → docs/analysis/business-domain.md 생성
```

### Step 4: 프로젝트별 설정 업데이트
```bash
# 1. DATABASE_SCHEMA_RULES.md 업데이트
# .claude/guides/DATABASE_SCHEMA_RULES.md에서 스키마명 변경:
#   sparknote → {new_project_schema}

# 2. CLAUDE.md 프로젝트명 업데이트
# CLAUDE.md 상단 프로젝트명 변경

# 3. .serena/project.yml 업데이트 (프로젝트 경로)
```

---

## 📋 체크리스트: 새 프로젝트 준비 완료

### ✅ 범용 시스템 (복사 완료)
- [ ] `.claude/agents/` - 69개 Agent 정의
- [ ] `.claude/commands/` - Slash Command
- [ ] `.claude/hooks/` - Reddit Hook System
- [ ] `.claude/guides/` - Agent 개발 가이드 + UI/UX 가이드
- [ ] `.claude/patterns/` - 범용 코딩 패턴
- [ ] `.claude/templates/` - Agent 템플릿
- [ ] `.claude/utils/` - 유틸리티

### ✅ 프로젝트별 초기화 (Agent 자동 생성)
- [ ] `docs/analysis/tech-stack.md` - 기술 스택 분석
- [ ] `docs/analysis/code-structure.md` - 코드 구조 분석
- [ ] `docs/analysis/database-schema.md` - DB 스키마 분석
- [ ] `docs/analysis/business-domain.md` - 비즈니스 도메인
- [ ] `docs/PROGRESS.md` - 진행 상황 추적
- [ ] `docs/epics/`, `docs/stories/`, `docs/tasks/` - 빈 폴더

### ✅ 프로젝트별 설정 업데이트
- [ ] `.claude/guides/DATABASE_SCHEMA_RULES.md` - 스키마명 변경
- [ ] `CLAUDE.md` - 프로젝트명 변경
- [ ] `.serena/project.yml` - 프로젝트 경로 업데이트

---

## 🎯 핵심 원칙

### 범용 vs 프로젝트별 구분 기준
```yaml
범용 (.claude/):
  - 프레임워크 패턴 (Next.js, NestJS, Prisma)
  - Agent 시스템 규칙
  - 디자인 시스템 (shadcn/ui)
  - 워크플로우 가이드

프로젝트별 (docs/):
  - 현재 프로젝트 아키텍처
  - 기술 스택 (버전, 설정)
  - DB 스키마 (테이블, 관계)
  - 비즈니스 도메인
  - 개발 히스토리 (Epic/Story/Task)
```

### 이동 우선순위 (okr2 → .claude)
1. **High**: UI/UX 디자인 시스템 (3개 파일)
2. **Medium**: 범용 패턴 (14개 파일)
3. **Low**: 프로젝트별 커스텀 패턴 (docs/patterns/custom/으로 분리)

---

## 🔄 마이그레이션 플랜 (okr2 프로젝트)

### Phase 1: 범용 가이드 이동
```bash
# UI/UX 가이드 이동
mv docs/guides/ui-design-system.md .claude/guides/UI_DESIGN_SYSTEM.md
mv docs/guides/aesthetic-directions.md .claude/guides/AESTHETIC_DIRECTIONS.md
mv docs/guides/accessibility-guidelines.md .claude/guides/ACCESSIBILITY_GUIDELINES.md
```

### Phase 2: 범용 패턴 이동
```bash
# 범용 패턴 이동
mkdir -p .claude/patterns/{fullstack,frontend,backend,debugging}
mv docs/patterns/INDEX.md .claude/patterns/
mv docs/patterns/README.md .claude/patterns/
mv docs/patterns/fsd-pattern.md .claude/patterns/
mv docs/patterns/nextauth-pattern.md .claude/patterns/
mv docs/patterns/prisma-pattern.md .claude/patterns/
mv docs/patterns/fullstack/* .claude/patterns/fullstack/
mv docs/patterns/frontend/* .claude/patterns/frontend/
mv docs/patterns/backend/* .claude/patterns/backend/
mv docs/patterns/debugging/* .claude/patterns/debugging/
```

### Phase 3: 프로젝트별 패턴 재구성
```bash
# 프로젝트별 커스텀 패턴 분리
mkdir -p docs/patterns/custom
mv docs/patterns/api-auth-pattern.md docs/patterns/custom/
mv docs/patterns/component-reuse-pattern.md docs/patterns/custom/
```

### Phase 4: 참조 업데이트
```bash
# CLAUDE.md 내 참조 경로 업데이트
# @docs/guides/ → @.claude/guides/
# @docs/patterns/ → @.claude/patterns/ (범용)
#                → @docs/patterns/custom/ (프로젝트별)
```

---

## 📝 예상 효과

### 즉시 효과
- ✅ `.claude` 디렉토리만 복사하면 새 프로젝트 시작 가능
- ✅ Agent 시스템 재사용 시간 95% 절감 (3시간 → 5분)
- ✅ 일관된 개발 경험 (모든 프로젝트 동일한 Agent)

### 중기 효과
- ✅ 범용 가이드/패턴 중앙 집중 관리
- ✅ 프로젝트별 컨텍스트 명확 분리
- ✅ Agent 품질 개선 시 모든 프로젝트 자동 반영

### 장기 효과
- ✅ Agent 시스템 생태계 구축 (회사 표준)
- ✅ 프로젝트 온보딩 시간 70% 절감
- ✅ 개발 생산성 2배 향상 (검증된 Agent 재사용)

---

## 🚨 주의사항

### 절대 복사하지 말 것
- ❌ `docs/analysis/` - 프로젝트별 분석 결과
- ❌ `docs/epics/`, `docs/stories/`, `docs/tasks/` - 개발 히스토리
- ❌ `docs/PROGRESS.md` - 진행 상황
- ❌ `docs/_archived/` - 완료된 작업

### 복사 전 확인 필요
- ⚠️ `.claude/guides/DATABASE_SCHEMA_RULES.md` - 스키마명 변경
- ⚠️ `CLAUDE.md` - 프로젝트명 변경
- ⚠️ `.serena/project.yml` - 프로젝트 경로 변경

---

## 📚 참조

- [DOCUMENTATION_ARCHITECTURE.md](.claude/guides/DOCUMENTATION_ARCHITECTURE.md) - Index + Detail 패턴
- [AUTO_WORKFLOW_GUIDE.md](.claude/guides/AUTO_WORKFLOW_GUIDE.md) - Agent 자동 라우팅
- [AGENT_CATALOG.md](.claude/AGENT_CATALOG.md) - 69개 Agent 카탈로그
