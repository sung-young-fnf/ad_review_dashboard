---
name: handoff
user-invocable: true
auto-detect: false
effort: low
triggers:
  activate: [handoff, 핸드오프, 인수인계, 세션정리, 마무리, wrap up, session end]
  skip: []
description: |
  세션 핸드오프 문서 생성 - 다음 세션을 위한 완전한 컨텍스트 전달.
  작업 내역, 남은 과제, 실패한 접근법, 다음 단계를 포함.

  Triggers: handoff, 핸드오프, 인수인계, 세션정리, 마무리

  Use when: 세션 종료 전, 다른 AI/사람에게 작업 인수인계 시
context: fork
---

# /handoff - Session Handoff Generator

> 다음 세션(또는 다른 AI)이 컨텍스트 손실 없이 작업을 이어받을 수 있는 핸드오프 문서 생성

## Pre-injected Context (Dynamic Context Injection)

**Git 상태:**
!`git status --short 2>/dev/null`

**현재 브랜치:**
!`git branch --show-current 2>/dev/null`

**최근 커밋 (10개):**
!`git log --oneline -10 2>/dev/null`

**미커밋 변경 통계:**
!`git diff --stat 2>/dev/null`

**최신 PROGRESS.md:**
!`find docs/epics -name "PROGRESS.md" -newer .git/HEAD 2>/dev/null | head -1 | xargs cat 2>/dev/null | head -40`

**최근 저장된 Serena 메모리 키:**
!`ls -t .serena/memories/ 2>/dev/null | head -10`

## 실행 절차

### Phase 1: 현재 상태 수집

위 Pre-injected Context를 기반으로 정보를 정리합니다.
추가로 필요한 정보만 도구로 수집합니다.

**1. Epic/Task 진행 상태**

Pre-injected PROGRESS.md를 분석하여:
- 완료된 Task 목록
- 진행 중인 Task
- 남은 Task 목록
- 전체 진행률 (%)

**2. Serena 메모리 수집**

Pre-injected 메모리 키 목록에서 이번 세션에서 저장한 항목을 식별합니다.
필요 시 `serena/read_memory`로 상세 내용을 확인합니다.

### Phase 2: 실패 접근법 수집

**4. Historian 검색** (핵심 개선점)

```
mcp-cli call historian/search_conversations '{"query": "error fail rollback workaround", "limit": 5}'
```

이번 세션에서 시도했지만 실패한 접근법 추출:
- 에러 메시지와 원인
- 시도했지만 작동하지 않은 방법
- 우회한 이유와 최종 해결책

**5. 에러 패턴 검색**

```
mcp-cli call historian/get_error_solutions '{"error_message": "[최근 에러]", "limit": 3}'
```

### Phase 3: 핸드오프 문서 생성 (6-Bucket 구조)

> 영감: hermes-CCC hermes-compress — 6개 시맨틱 버킷으로 세션 상태를 구조화
> WHY: "모든 것을 요약"이 아닌 목적별 분류 → 다음 세션에서 필요한 버킷만 선택적 읽기

수집한 정보를 기반으로 `.claude/handoffs/latest-handoff.md`에 아래 형식으로 저장:

```markdown
# Session Handoff

> Generated: {timestamp}
> Session Duration: {duration}
> Project: {project_name}

## 1. Decisions (이번 세션에서 내린 결정)

{아키텍처, 기술 선택, 접근 방식 결정 목록}
- "X 대신 Y를 선택 — 이유: ..."
- "Z 패턴 적용 결정 — 근거: ..."

## 2. Artifacts Created (생성/수정한 산출물)

{git log --oneline 커밋 내역 + 생성된 파일 목록}
| 파일 | 설명 |
|------|------|
| `path/to/file.ts` | "..." |

### 완료된 Task
{PROGRESS.md에서 이번 세션 완료 Task}

## 3. Problems Solved (해결한 문제)

{버그 수정, 에러 해결, 블로커 제거}
- 증상: {what was wrong}
- 원인: {root cause}
- 해결: {fix applied}

## 4. Facts Learned (새로 배운 사실)

{코드베이스, 외부 API, 환경에 대해 새로 알게 된 것}
- "{subsystem}은 {fact} 방식으로 동작한다"
- "{tool/library}는 {constraint} 제약이 있다"

## 5. Open Issues (미해결 이슈)

{실패한 접근법 + 미해결 버그 + 알려진 제약}

### 실패한 접근법
- 시도: {what was tried}
- 실패 이유: {why it failed}
- 교훈: {lesson learned}

### 남은 과제
{PROGRESS.md에서 pending Task 목록}

## 6. Next Steps (다음 세션 가이드)

### 현재 상태
- Epic: {epic_id}
- 진행률: {completed}/{total} ({pct}%)
- 진행 중 Task: {current_task}
- 미커밋 파일: {uncommitted files}

### 즉시 실행 (Priority 1)
{미커밋 파일 처리 → 진행 중 Task 계속}

### 순서대로 (Priority 2+)
{남은 Task 순서대로}

### 컨텍스트 복원 명령어
- `cat .claude/handoffs/latest-handoff.md`
- `cat docs/epics/{epic_id}/PROGRESS.md`
- serena/list_memories → 관련 메모리 로드
- `git status && git log --oneline -5`
```

**6-Bucket 매핑 (hermes-compress → 핸드오프)**:
| hermes-compress 버킷 | 핸드오프 섹션 | 용도 |
|----------------------|-------------|------|
| `decisions` | 1. Decisions | 다음 세션에서 결정 맥락 즉시 파악 |
| `artifacts_created` | 2. Artifacts Created | 무엇이 만들어졌는지 빠른 확인 |
| `problems_solved` | 3. Problems Solved | 같은 문제 재조사 방지 |
| `facts_learned` | 4. Facts Learned | 코드베이스 학습 내용 보존 |
| `open_issues` | 5. Open Issues | 실패 접근법 + 미해결 과제 통합 |
| `next_steps` | 6. Next Steps | 다음 액션 명확화 |

### Phase 4: 저장 및 알림

**6. Markdown 파일 저장**

Write 도구로 `.claude/handoffs/latest-handoff.md`에 저장.

**7. Serena 메모리에 핸드오프 요약 저장**

```
mcp-cli call serena/write_memory '{
  "memory_file_name": "session_handoff_{date}",
  "content": "# Session Handoff {date}\n\n{1-2줄 요약}\n\n## 다음 할 일\n{top 3 next actions}"
}'
```

**8. Praetorian 압축**

```
mcp-cli call praetorian/praetorian_compact '{
  "type": "session_handoff",
  "title": "Session Handoff {date}"
}'
```

**9. 사용자에게 결과 표시**

```
=== Session Handoff 생성 완료 ===

작업 내역: {commits}개 커밋, {completed} Task 완료
남은 과제: {pending} Task
실패 접근법: {count}건 기록

저장 위치: .claude/handoffs/latest-handoff.md
다음 세션에서: "cat .claude/handoffs/latest-handoff.md" 또는 자동 로드

===
```

## 출력 규칙

- 핸드오프 문서는 반드시 `.claude/handoffs/latest-handoff.md`에 저장
- Serena 메모리에도 요약 저장 (세션 간 영속성)
- 실패 접근법이 없으면 "없음"으로 명시 (생략하지 않음)
- 다음 세션 가이드는 구체적인 명령어 포함 (모호한 지시 금지)
