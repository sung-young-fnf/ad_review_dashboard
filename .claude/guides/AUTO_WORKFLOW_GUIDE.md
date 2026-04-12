# AUTO-WORKFLOW 자동 라우팅 가이드

> **목적**: 모든 개발 요청에 적절한 Agent 체인 자동 실행
> **원칙**: `--hard-think --delegate` 무조건 적용

---

## 💡 Named Sessions (Claude Code 2.0.64+)

복잡한 Epic/Story 작업 시 세션 이름 지정으로 작업 연속성 확보:

```bash
# 작업 중 세션 이름 지정
/rename EP022-marketplace-improvement

# 나중에 이어서 작업 (REPL에서)
/resume EP022-marketplace-improvement

# 터미널에서 직접 재개
claude --resume EP022-marketplace-improvement
```

**권장 네이밍 패턴**:
- Epic 작업: `EP{번호}-{간단설명}` (예: `EP022-marketplace-ui`)
- 버그 수정: `bugfix-{이슈번호}` (예: `bugfix-123`)
- 리팩토링: `refactor-{대상}` (예: `refactor-auth-module`)

**활용 팁**:
- P(Preview): 세션 미리보기
- R(Rename): 세션 이름 변경
- 포크된 세션 자동 그룹화

---

## 🎯 Step 0: Reference vs Standard 구분 (최우선)

모든 요청 분석 전 먼저 Reference 복제 여부 확인:

### Reference 복제 (Figma, Lovable, v0, 템플릿)

**트리거 키워드**:
```yaml
키워드: "figma", "reference", ".reference", "복제", "lovable", "v0", "템플릿"
Agent 계열: figma-clone-agents/C*/reference-*
```

**예시**:
- "Figma 디자인 복제" → reference-epic-creator
- ".reference 코드 기반 구현" → reference-story-creator
- "Lovable 프로젝트 복제" → reference-epic-creator

### Standard 개발 (일반 요구사항)

**Agent 계열**: 02-requirements/, 03-design/, 04-implementation/

**예시**:
- "새로운 사용자 인증 시스템" → epic-creator
- "API 추가" → story-creator
- "버그 수정" → task-planner

**우선순위**: Reference 트리거 감지 → Reference 계열, 그 외 → Standard 계열

---

## 🎯 Step 0.5: Epic 없는 작업 처리 (_backlog, ADHOC Epic)

**조건**: Epic ID가 명시되지 않은 요청

### 1. 단일 Story/Task (독립적 작업)

```yaml
조건: Epic ID 없음 + 관련 작업 1개

라우팅:
  - 여러 Story로 분해 필요 없음 → story-creator (--backlog-mode)
  - Story 분해 필요 없는 단순 Task → task-planner (--backlog-mode)

출력 경로:
  - Story: docs/epics/_backlog/S##_descriptive-name.md
  - Task: docs/epics/_backlog/T###_descriptive-name.md

예시:
  - "Chrome DevTools 타임아웃 최적화" → S01_chrome-devtools-timeout-optimization.md
  - "User 테이블에 phone_number 컬럼 추가" → T001_add-user-phone-column.md
```

### 2. ADHOC Epic (경량 Epic, 2-3개 Story)

```yaml
조건: Epic ID 없음 + 관련 작업 2-3개 이상

라우팅: epic-creator (--adhoc 플래그)

출력 경로: docs/epics/ADHOC-{nnn}_{descriptive-name}/

체인: epic-creator → story-creator → task-planner → code-writer

예시:
  "로깅 시스템 개선" (3개 관련 작업)
  ├─ S01: Connection Log API 추가
  ├─ S02: Request/Response Log 저장
  └─ S03: 로그 조회 UI

폴더 구조:
  docs/epics/ADHOC-001_logging-improvements/
  ├── epic.md (또는 README.md)
  ├── PROGRESS.md
  ├── stories/
  │   ├── S01_connection-log-api.md
  │   ├── S02_request-response-log.md
  │   └── story-overview.md
  └── tasks/ (선택)
```

### 3. 의사결정 트리

```yaml
User Request
  ├─ Epic ID 명시
  │  └─ story-creator (Regular Mode)
  │     └─ Output: docs/epics/EP{nnn}/stories/S##_*.md
  │
  ├─ Epic ID 없음 & 관련 작업 2-3개 이상
  │  └─ epic-creator (--adhoc)
  │     └─ Output: docs/epics/ADHOC-{nnn}_{descriptive-name}/
  │        └─ 체인: epic-creator → story-creator → task-planner → code-writer
  │
  ├─ Epic ID 없음 & Task 1개만 (Story 분해 불필요)
  │  └─ task-planner (--backlog-mode)
  │     └─ Output: docs/epics/_backlog/T###_descriptive-name.md
  │
  └─ Epic ID 없음 & Story 1개 (독립 기능)
     └─ story-creator (--backlog-mode)
        └─ Output: docs/epics/_backlog/S##_descriptive-name.md
```

### 4. _backlog vs ADHOC Epic 비교

| 비교 항목 | _backlog | ADHOC Epic |
|----------|----------|------------|
| 용도 | Epic 없는 단일 | 경량 Epic (2-3 Story) |
| 소요시간 | 1-2일 | 1-2주 |
| 폴더 구조 | 공용 보관소 | 독립적 Epic 폴더 |
| 파일 형식 | S##_, T###_ | epic.md + stories/ |
| 상태 추적 | story-overview | epic.md + PROGRESS.md |
| 예시 | Chrome DevTools | 로깅 시스템 개선 |
| 생성 조건 | 즉시 실행 | 2-3개 관련 작업 |

**참조**:
- `docs/epics/_backlog/STRUCTURE.md`
- `docs/epics/_backlog/README.md`
- `.claude/agents/02-requirements/BACKLOG_WORKFLOW_EXAMPLES.md`

---

## 🚀 요청 유형별 자동 Agent 선택 (Standard)

### 🏗️ 대형 프로젝트 (Epic Chain)

**키워드**: "새로운 기능", "시스템 구축", "플랫폼", "대규모", "아키텍처"

**자동 실행**: `02-requirements/epic-creator` 부터 시작

**체인**: Epic → Story → Task → Implementation

**예시**:
- "새로운 사용자 인증 시스템"
- "결제 시스템 구축"
- "알림 플랫폼 개발"

---

### 📋 중형 개발 (Story Chain)

**키워드**: "API 추가", "화면 추가", "컴포넌트", "기능 확장", "통합"

**자동 실행**: `02-requirements/story-creator` 부터 시작

**체인**: Story → Task → Implementation

**예시**:
- "로그인 API에 2FA 추가"
- "대시보드에 위젯 추가"
- "기존 폼에 필드 추가"

---

### 🔧 소형 작업 (Task Chain)

**키워드**: "버그 수정", "개선", "테스트 추가", "성능 최적화", "리팩터링"

**자동 실행**: `03-design/task-planner` 부터 시작

**체인**: Task → Implementation

**예시**:
- "비밀번호 validation 버그 수정"
- "로딩 속도 개선"
- "컴포넌트 리팩터링"

---

### 🚨 긴급 상황 (Hotfix Chain)

**키워드**: "긴급", "P0", "장애", "서비스 다운", "핫픽스", "에러", "버그"

**자동 실행**: `99-utils/error-fixer` 즉시 실행

**체인**:
- **단일 에러**: Error Analysis → Quick Fix (3-5분)
- **다중 에러 (3개+)**: Multi-Error Detection → Topic Grouping → Parallel Fix → Unified Verification (5-6분)

**자동 모드 선택**: 에러 개수 기반 (병렬 모드 3배 빠름)

**예시**:
- "서비스 다운, 500 에러 발생"
- "프로덕션 긴급 수정 필요"
- "타입 에러 100개 발생"

---

### ✏️ 간단한 수정 (Quick Modifier)

**키워드**: "간단한 수정", "값 변경", "텍스트 수정", "상수 변경", "설정 변경"

**자동 실행**: `99-utils/quick-modifier`

**체인**: Quick Analysis → Minimal Edit → Verify

**예시**:
- "API URL 값 변경"
- "버튼 텍스트 수정"
- "환경변수 값 업데이트"
- "마감 문구 수정"

---

### 📦 커밋 요청 (Commit Chain)

**키워드**: "커밋", "commit", "푸시", "push"

**자동 실행**: `99-utils/commit-manager`

**체인**: Git Status → Commit Message → Commit → (Optional) Push

**예시**:
- "현재 변경사항 커밋해줘"
- "작업 완료, 커밋"
- "commit and push"

---

### 🗄️ 데이터베이스 (DB Chain)

**키워드**: "스키마", "마이그레이션", "DDL", "알렘빅", "DB"

**자동 실행**: `04-implementation/db-code-writer` 안전 모드

**체인**: DB Planning → Migration → Implementation

**예시**:
- "user 테이블에 컬럼 추가"
- "새로운 테이블 생성"
- "인덱스 최적화"

---

## 📝 기본 실행 규칙

### 1. 모든 개발 요청에 `--hard-think --delegate` 자동 적용

**의미**:
- `--hard-think`: Agent가 심층 분석 수행
- `--delegate`: 하위 Agent 자동 호출 (완전 자동화)

### 2. 병렬 실행 최우선 (CRITICAL)

```yaml
필수 단계:
  1. Task 의존성 자동 분석
  2. 독립적 Task 식별 (서로 다른 파일, 독립 기능)
  3. 병렬 그룹 생성
  4. 단일 메시지로 동시 실행 (여러 Task tool 호출)
  5. 예상 시간 비교 (병렬 vs 순차)

TodoWrite도 병렬 그룹 명시:
  - [병렬] T001, T002, T003
  - (depends: T001-T003) T004

예상 시간은 AI 기준:
  - 병렬: 5분 (3개 Task 동시)
  - 순차: 15분 (3개 Task 순서)
  - 효율: 3배 향상
```

### 3. 키워드 우선순위

**우선순위 체인**:
```
긴급 > DB > 대형 > 중형 > 소형 > 간단수정 > 커밋
```

**예시**:
- "새로운 DB 스키마" + "긴급" → 긴급 우선 (error-fixer)
- "API 추가" + "DB 변경" → DB 우선 (db-code-writer)

### 4. 모호한 요청 처리

**기본값**: 중형 (Story Chain) 선택

**예시**:
- "사용자 관리 개선" → story-creator (중형)
- 구체적 정보 부족 시 사용자에게 질문

### 5. 성공 패턴 재현

**Epic E003 패턴** (성공 사례):
- 동일한 워크플로우 자동 적용
- 검증된 Agent 체인 재사용

---

## 💡 실행 예시

### 예시 1: 대형 프로젝트
```yaml
User: "새로운 사용자 인증 시스템"

분류: 대형 (키워드: "새로운", "시스템")
자동 실행: epic-creator --hard-think --delegate
체인: Epic → Story → Task → code-writer
예상 시간: 30-45분 (AI 기준)
```

### 예시 2: 중형 개발
```yaml
User: "로그인 API에 2FA 추가"

분류: 중형 (키워드: "API 추가")
자동 실행: story-creator --hard-think --delegate
체인: Story → Task → code-writer
예상 시간: 15-20분
```

### 예시 3: 소형 작업
```yaml
User: "비밀번호 validation 버그"

분류: 소형 (키워드: "버그")
자동 실행: task-planner --hard-think --delegate
체인: Task → code-writer
예상 시간: 5-10분
```

### 예시 4: 긴급 상황
```yaml
User: "서비스 다운, 500 에러 발생"

분류: 긴급 (키워드: "서비스 다운", "에러")
자동 실행: error-fixer --hard-think --delegate
모드: 단일 에러 → 순차 (3-5분)
     다중 에러 (3개+) → 병렬 (5-6분)
```

### 예시 5: DB 작업
```yaml
User: "user 테이블에 phone_number 컬럼 추가"

분류: DB (키워드: "테이블", "컬럼")
자동 실행: db-code-writer --hard-think --delegate
체인: DB Planning → Migration → Implementation
예상 시간: 10-15분
```

### 예시 6: Epic 없는 단일 Task
```yaml
User: "Chrome DevTools 타임아웃 최적화"

분류: Epic 없음 + Task 1개
자동 실행: task-planner (--backlog-mode)
출력: docs/epics/_backlog/T001_chrome-devtools-timeout.md
예상 시간: 5-10분
```

### 예시 7: ADHOC Epic
```yaml
User: "로깅 시스템 개선 (Connection Log, Request/Response Log, 로그 조회 UI)"

분류: Epic 없음 + 관련 작업 3개
자동 실행: epic-creator (--adhoc)
출력: docs/epics/ADHOC-001_logging-improvements/
체인: Epic → Story → Task → code-writer
예상 시간: 25-35분
```

---

## 🔍 분류 알고리즘

### Step 1: 키워드 추출

```typescript
function extractKeywords(userRequest: string): string[] {
  const KEYWORD_PATTERNS = {
    urgent: /긴급|P0|장애|서비스 다운|핫픽스/,
    db: /스키마|마이그레이션|DDL|알렘빅|DB|테이블|컬럼/,
    large: /새로운 기능|시스템 구축|플랫폼|대규모|아키텍처/,
    medium: /API 추가|화면 추가|컴포넌트|기능 확장|통합/,
    small: /버그 수정|개선|테스트 추가|성능 최적화|리팩터링/,
    quick: /간단한 수정|값 변경|텍스트 수정|상수 변경|설정 변경/,
    commit: /커밋|commit|푸시|push/,
    reference: /figma|reference|\.reference|복제|lovable|v0|템플릿/
  }

  const matched = []
  for (const [type, pattern] of Object.entries(KEYWORD_PATTERNS)) {
    if (pattern.test(userRequest)) {
      matched.push(type)
    }
  }

  return matched
}
```

### Step 2: 우선순위 적용

```typescript
function selectAgent(keywords: string[]): string {
  // 우선순위: reference > urgent > db > large > medium > small > quick > commit
  if (keywords.includes('reference')) return 'reference-epic-creator'
  if (keywords.includes('urgent')) return 'error-fixer'
  if (keywords.includes('db')) return 'db-code-writer'
  if (keywords.includes('large')) return 'epic-creator'
  if (keywords.includes('medium')) return 'story-creator'
  if (keywords.includes('small')) return 'task-planner'
  if (keywords.includes('quick')) return 'quick-modifier'
  if (keywords.includes('commit')) return 'commit-manager'

  // 모호한 요청: 기본값 중형
  return 'story-creator'
}
```

### Step 3: Epic 없는 작업 감지

```typescript
function detectBacklogMode(userRequest: string): boolean {
  // Epic ID 패턴 체크
  const hasEpicId = /EP\d{3}|ADHOC-\d{3}/i.test(userRequest)

  if (!hasEpicId) {
    // Epic 없음 - Backlog 또는 ADHOC 판단
    const relatedTasksCount = estimateRelatedTasks(userRequest)

    if (relatedTasksCount >= 2) {
      return 'adhoc'  // ADHOC Epic 생성
    } else {
      return 'backlog'  // _backlog에 단일 Story/Task
    }
  }

  return 'regular'  // 정규 Epic/Story
}
```

---

## 📋 실행 규칙 상세

### 병렬 실행 규칙

**참조**: @.claude/guides/PARALLEL_EXECUTION_GUIDE.md

**핵심**:
- Task 의존성 자동 분석 필수
- 의존성 없으면 **무조건** 병렬 실행
- 단일 메시지에 여러 Task tool 호출

**예시**:
```typescript
// ✅ 병렬 실행 (단일 메시지)
[
  Task({ subagent_type: "code-writer", prompt: "T001" }),
  Task({ subagent_type: "code-writer", prompt: "T002" }),
  Task({ subagent_type: "code-writer", prompt: "T003" })
]
// 예상: 5분 (순차 15분 대비 3배 빠름)

// ❌ 순차 실행 (의존성 없는데)
Task("T001") → 완료 대기 → Task("T002") → 완료 대기 → Task("T003")
// 예상: 15분 (비효율)
```

### Epic E003 성공 패턴

**참조**: `docs/epics/EP003_*/`

**성공 요인**:
- ✅ 명확한 Story 분해
- ✅ 병렬 실행 최적화 (50% Task 동시 실행)
- ✅ 기존 패턴 재사용 (90%)

**재현 방법**:
- 동일한 Agent 체인 적용
- 동일한 병렬 전략 사용

---

## 🏋️ Squad 모드 (Mission Squad System)

> **Solo가 기본값**. Hook이 `SQUAD_SCALE`을 판단하여, SOLO가 아니면 Squad 편성을 추천한다.

### Squad 라우팅 (Hook → Main Thread)

```
사용자 요청
    ↓
user-prompt-submit.sh
    ├─ analyze_keywords() → KEYWORDS
    └─ determine_squad_scale() → SQUAD_SCALE
    ↓
[SOLO?] → 기존 Solo 방식 (위 섹션 참조)
[SQUAD?] → Squad 편성 시작
```

### Squad 실행 플로우

```
1. Teammate.spawnTeam(team_name="{type}-{id}-{YYYYMMDD}")
2. Lead 생성 → MISSION_BRIEF 전달
3. Lead: TaskCreate로 Task List 등록
4. Member: TaskList → claim → 구현 → completed
5. 모든 Task 완료 → Lead 보고 → Main Thread 해산
```

### 규모별 Squad 편성

| 규모 | Hook 출력 | Squad | 팀원 |
|------|----------|-------|------|
| EPIC | `🏋️ SQUAD [EPIC] → epic-squad` | epic-squad | architect + dev×2 + reviewer |
| STORY | `🏋️ SQUAD [STORY] → story-squad` | story-squad | tech-lead + dev |
| BUG_CRITICAL | `🏋️ SQUAD [BUG_CRITICAL] → bug-squad` | bug-squad | investigator×2-3 |
| DB | `🏋️ SQUAD [DB] → db-squad` | db-squad | db-architect + db-dev |
| UX | `🏋️ SQUAD [UX] → ux-squad` | ux-squad | ux-analyst + ui-dev + verifier |

### Squad 실행 예시

```yaml
User: "메모리 영속화 시스템 구축"

SQUAD_SCALE: EPIC
Squad: epic-squad

실행:
  1. Teammate.spawnTeam("epic-EP114-20260206")
  2. architect(Lead): 요구사항 분석 → Epic/Story/Task 문서 생성
  3. dev-1, dev-2: TaskList에서 Task claim → 병렬 구현
  4. reviewer: 구현 검증 → dev에게 DM 피드백
  5. 모든 Task 완료 → 해산
```

### Squad 참조

- 스쿼드 개요: @.claude/squads/README.md
- 역할 정의: @.claude/squads/roles/
- 편성 템플릿: @.claude/squads/templates/

---

## 🚨 예외 처리

### 1. 키워드 감지 실패

```yaml
증상: 키워드 매칭 없음

처리:
  - 사용자에게 구체적 정보 요청
  - 예: "어떤 종류의 작업인가요? (API 추가 / 버그 수정 / 새 기능)"

기본값: story-creator (중형)
```

### 2. 복합 요청 (여러 키워드)

```yaml
예시: "새로운 결제 시스템 + DB 마이그레이션 + 긴급"

우선순위 적용:
  1. 긴급 (최우선)
  2. DB (두 번째)
  3. 대형 (세 번째)

선택: error-fixer (긴급 우선)
```

### 3. Reference + Standard 혼합

```yaml
예시: "Figma 디자인 복제 + 커스텀 로직 추가"

처리:
  1. Reference 우선 (figma-clone-agents)
  2. 복제 완료 후 Standard (story-creator)

체인: reference-epic-creator → clone-code-writer → story-creator (커스텀)
```

---

## 📊 성공 지표

```yaml
Agent 선택 정확도:
  - 목표: 95%+
  - 측정: 사용자 재요청 비율

자동 실행율:
  - 목표: 80%+ (Confidence >= 90% 케이스)
  - 측정: 자동 실행 / 전체 요청

병렬 실행율:
  - 목표: 50%+ Task 병렬 실행
  - 측정: 병렬 Task / 전체 Task

개발 속도:
  - Epic: 30-45분 (AI 기준)
  - Story: 15-20분
  - Task: 5-10분
  - Hotfix: 3-6분
```

---

## 📚 참조

**관련 가이드**:
- **병렬 실행**: @.claude/guides/PARALLEL_EXECUTION_GUIDE.md
- **Agent 체인**: @.claude/guides/AGENT_CHAIN_RULES.md
- **자동 실행**: @.claude/guides/AUTO_EXECUTION_GUIDE.md
- **Backlog 워크플로우**: @.claude/agents/02-requirements/BACKLOG_WORKFLOW_EXAMPLES.md

**프로젝트 문서**:
- **코드 구조**: @docs/analysis/code-structure.md
- **기술 스택**: @docs/analysis/tech-stack.md
- **Agent 카탈로그**: @.claude/AGENT_CATALOG.md

---

**버전**: 1.1.0
**작성일**: 2025-11-27
**유지보수**: Agent 최적화 팀
