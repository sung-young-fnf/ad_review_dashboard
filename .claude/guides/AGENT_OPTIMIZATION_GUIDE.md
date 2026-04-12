# Claude Code Agent 최적화 가이드

## 🎯 핵심 원칙

### 문제점
- **1000줄 이상의 긴 Agent 지침** → 핵심 작업 누락
- **모든 로직이 한 파일에** → 컨텍스트 과부하
- **중요 작업이 문서 후반부에** → 실행 누락
- **불필요한 복잡성과 과도한 기능** → 유지보수 어려움

### 해결책
- **200줄 이하로 Agent 지침 축소**
- **작업별 Command 분리**
- **핵심 작업을 최상단 배치**
- **YAGNI 원칙 적용** - 현재 필요한 것만 구현

## 📐 권장 구조

### 기본 구조 (Option 1)
```
agent-name.md (200줄 이하)
├── 핵심 임무 (20줄)
├── 필수 체크포인트 (10줄)
├── 실행 순서 (30줄)
└── Command 참조 (10줄)

.claude/commands/
├── {agent-name}-save.md      # 파일 저장 전용
├── {agent-name}-analyze.md   # 분석 로직
├── {agent-name}-validate.md  # 검증 로직
└── {agent-name}-template.md  # 템플릿 생성

.claude/templates/
└── {agent-name}/
    ├── output-template.md
    └── examples/
```

### 🎯 개선된 폴더 체계 구조 (Option 2 - 권장)
```
agent-name.md (200줄 이하)
├── 핵심 임무 (20줄)
├── 필수 체크포인트 (10줄)
├── 실행 순서 (30줄)
└── Command 참조 (10줄)

.claude/commands/{agent-name}/    # Agent별 폴더로 그룹화
├── save.md                       # 파일 저장 전용
├── analyze.md                    # 분석 로직
├── validate.md                   # 검증 로직
└── template.md                   # 템플릿 생성

.claude/templates/{agent-name}/
├── output-template.md
├── manual-tasks-template.md
└── examples/
    └── example-output.md
```

### 📁 폴더 체계의 장점

| 항목 | Option 1 (평면 구조) | Option 2 (폴더 구조) | 권장 이유 |
|------|---------------------|---------------------|-----------|
| **명확성** | 파일명에 agent 이름 포함 | 폴더명으로 구분 | 폴더 구조가 더 직관적 |
| **확장성** | 파일 수 증가 시 복잡 | Agent별 독립 관리 | 다수 Agent 관리 용이 |
| **Command 호출** | `/command {agent}-{action}` | `/command {agent}/{action}` | 경로가 더 명확 |
| **충돌 방지** | 접두사로 구분 | 폴더로 완전 분리 | 이름 충돌 원천 차단 |
| **유지보수** | 관련 파일 찾기 어려움 | 한 폴더에 모두 위치 | 관련 파일 쉽게 접근 |

## ✅ Agent 파일 템플릿

```markdown
---
name: category/agent-name
description: 핵심 목적을 한 문장으로. MUST include critical actions (e.g., "MUST save files").
tools: [필요한 도구들]
---

# Agent Name

## 🎯 핵심 임무 [CRITICAL]
1. 주요 작업 1
2. **반드시 수행할 작업** (강조)
3. 결과 출력

## ⚠️ 필수 체크포인트
- [ ] 입력 검증 완료
- [ ] 핵심 작업 수행
- [ ] **파일 저장 완료** ← 절대 생략 불가!
- [ ] 결과 보고 완료
- [ ] YAGNI 원칙 준수 확인

## 🔄 실행 순서
1. 입력 분석
2. `/command {agent}-analyze` 실행
3. 핵심 작업 수행
4. **`/command {agent}-save`** 실행 (필수!)
5. 결과 보고

## 📁 출력 규칙
- 경로: `docs/category/subcategory/`
- 파일명: `{id}_{name}.md`
- 형식: Markdown

[상세 내용은 commands 폴더 참조]
```

## 🔧 Command 파일 템플릿

### 프론트매터 (Frontmatter) 설정
| 필드 | 목적 | 예시 |
|-----|------|------|
| `allowed-tools` | 사용 가능한 도구 제한 | `Read, Write, Grep` |
| `argument-hint` | 인수 힌트 (사용자에게 표시) | `[epic-id] [story-id]` |
| `description` | 명령어 간단 설명 | `기술 명세 파일 저장` |
| `model` | 특정 모델 지정 (선택) | `opus` 또는 `haiku` |

### Command 파일 전체 템플릿
```markdown
---
allowed-tools: Write, Read, Glob, LS
argument-hint: [epic-id] [story-id] [content]
description: 기술 명세를 tech-specs 폴더에 저장
---

# Command Name

## 목적
한 가지 구체적인 작업 수행

## 인수 설명
- `$1` (epic-id): Epic 식별자 (예: E001)
- `$2` (story-id): Story 식별자 (예: STORY-001)
- `$3` (content): 저장할 내용
- `$ARGUMENTS`: 전체 인수 문자열

## 실행 단계
1. 인수 검증: Epic ID는 $1, Story ID는 $2
2. 경로 구성: docs/epics/$1/tech-specs/$2_tech-spec.md
3. Write 도구로 저장
4. 결과 확인 및 보고

## 체크리스트
- [ ] 인수 검증 완료
- [ ] 파일 저장 완료
- [ ] 경로 확인 완료
```

### 도구 제한 예시
```yaml
# Git 작업만 허용
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)

# 읽기 전용 작업
allowed-tools: Read, Grep, Glob, LS

# 파일 쓰기 작업
allowed-tools: Write, Edit, MultiEdit

# MCP 도구만
allowed-tools: mcp__serena__*, mcp__Context7__*
```

## 📂 폴더 체계 마이그레이션 예시

### Before (평면 구조)
```
.claude/commands/
├── task-planner-save.md
├── task-planner-analyze.md
├── task-planner-db-separate.md
├── task-planner-template.md
├── epic-creator-save.md
├── epic-creator-validate.md
└── ... (파일 수 증가로 혼잡)
```

### After (폴더 구조)
```
.claude/commands/
├── task-planner/
│   ├── save.md
│   ├── analyze.md
│   ├── db-separate.md
│   └── template.md
├── epic-creator/
│   ├── save.md
│   └── validate.md
└── story-creator/
    ├── save.md
    └── analyze.md
```

### Command 호출 변경
```bash
# Before
/command task-planner-save [args]
/command epic-creator-validate [args]

# After (더 명확한 경로)
/command task-planner/save [args]
/command epic-creator/validate [args]
```

## 🚀 마이그레이션 체크리스트

### 기존 Agent 분석
- [ ] 현재 줄 수 확인 (500줄 초과 시 분리 필요)
- [ ] 핵심 작업 식별
- [ ] 반복적인 작업 패턴 찾기
- [ ] 템플릿과 로직 구분

### Agent 파일 개선
- [ ] 핵심 지침만 남기고 200줄 이하로 축소
- [ ] Description에 핵심 작업 명시 (MUST 키워드 사용)
- [ ] 필수 체크포인트를 상단에 배치
- [ ] Command 참조로 상세 로직 대체

### Command 분리
- [ ] 파일 저장 로직 → `{agent}-save.md`
- [ ] 분석 로직 → `{agent}-analyze.md`
- [ ] 검증 로직 → `{agent}-validate.md`
- [ ] 템플릿 생성 → `{agent}-template.md`

### 템플릿 분리
- [ ] 출력 템플릿 → `templates/{agent}/`
- [ ] 예제 파일 → `templates/{agent}/examples/`
- [ ] 스키마 정의 → `templates/{agent}/schemas/`

## 📊 효과 측정

| 지표 | Before | After | 개선율 |
|-----|--------|-------|--------|
| Agent 파일 크기 | 1000+ 줄 | <200 줄 | 80% 감소 |
| 핵심 작업 성공률 | 70% | 95% | 35% 향상 |
| 유지보수 시간 | 30분 | 5분 | 83% 감소 |
| 재사용성 | 낮음 | 높음 | Command 모듈화 |

## 📚 컨텍스트 문서 참조 체계

### Agent 간 컨텍스트 공유
Agent들이 생성한 분석 문서를 다른 Agent가 참조하는 체계:

#### 필수 컨텍스트 섹션 추가
```markdown
## 📤 필수 참조 사항

### 핵심 컨텍스트 (필수)
- **비즈니스 컨텍스트**: @docs/analysis/business-domain.md
  - Story의 비즈니스 가치 정의
  - 사용자 페르소나별 요구사항

- **기술 스택**: @docs/analysis/tech-stack.md
  - Story 크기와 복잡도 예측
  - 기술적 제약사항 확인

- **코드 구조**: @docs/analysis/code-structure.md
  - 영향받는 모듈 파악
  - 의존성 분석
```

#### 컨텍스트 체인 예시
```
business-analyzer → @docs/analysis/business-domain.md
                        ↓
              [story-creator, tech-spec-engineer]
```

#### @참조 구문 사용법
- `@파일경로`: 필수 참조 문서 명시
- Serena MCP 자동 로드 지원
- Agent 시작 시 자동 검증

## 💡 Best Practices

### DO ✅
- 핵심 작업을 Description에 명시
- 필수 작업에 **강조** 표시
- Command를 통한 모듈화
- 체크포인트로 진행상황 추적
- 명확한 폴더/파일 명명 규칙
- **@참조 구문으로 컨텍스트 명시**
- **생성 문서를 다음 Agent가 활용하도록 설계**
- **YAGNI 원칙 적용** - 실제 요구사항에만 집중

### DON'T ❌
- 500줄 이상의 긴 Agent 파일
- 모든 로직을 한 파일에 포함
- 중요 작업을 문서 후반부에 배치
- 복잡한 중첩 구조
- 모호한 지침
- **컨텍스트 문서 참조 누락**
- **Agent 간 정보 단절**
- **미래 요구사항 추측** (YAGNI 위반)
- **불필요한 추상화나 일반화**
- **사용되지 않는 유틸리티 함수**

## 🔄 적용 우선순위

1. **즉시 개선 필요** (파일 저장 누락 등 치명적 문제)
   - tech-spec-engineer
   - task-planner
   - implementation agents

2. **점진적 개선** (동작하지만 개선 여지 있음)
   - epic-creator
   - story-creator
   - analyzer agents

3. **참고용** (새로 생성하는 Agent)
   - 처음부터 이 가이드 적용
   - Command 우선 설계

---

_Version: 1.3_
_Created: 2025-01-29_
_Updated: 2025-01-30 - YAGNI 원칙 추가 및 컨텍스트 문서 참조 체계 추가_
_Purpose: Claude Code Agent 최적화를 위한 표준 가이드_