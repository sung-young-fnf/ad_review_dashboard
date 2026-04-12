# Session & Task Management Guide

> Claude Code 2.0.64+ 세션 관리 및 2.1.16+ Task 시스템 활용 가이드

## Session Management (2.0.64+)

### 세션 명명 규칙
| 유형 | 패턴 | 예시 | 복원 |
|------|------|------|------|
| Epic | `epic-EP{번호}-{YYYYMMDD}` | `epic-EP081-20260127` | `--resume "epic-EP081-20260127"` |
| Story | `story-S{번호}-{epic_id}` | `story-S01-EP081` | `--resume "story-S01-EP081"` |
| Bugfix | `bugfix-{이슈번호}` | `bugfix-456` | `--resume "bugfix-456"` |
| Deploy | `deploy-{git-short-sha}` | `deploy-ae4ee54` | `--resume "deploy-ae4ee54"` |

### 시나리오별 명령어
[session: scenario, command]
Epic 시작, `--session-id "epic-EP{nnn}-$(date +%Y%m%d)"`
Story 포크, `--resume "epic-..." --fork-session`
에러 A/B, `--fork-session` (2회 실패 시)
배포 추적, `--session-id "deploy-${GIT_SHA::7}"`

### Named Session (2.0.64+)
```bash
/rename "epic-EP081"              # 현재 세션에 이름 부여
claude --resume "epic-EP081"      # 이름으로 즉시 복원 (ID 불필요)
claude --resume "epic-EP081" --fork-session --session-id "story-S01-EP081"  # 포크+이름 지정 (2.0.73+)
```

### Skill에서 세션 추적 (2.1.9+)
```yaml
# skill frontmatter에서 ${CLAUDE_SESSION_ID} 사용 가능
# ralph-loop 등에서 세션별 상태 추적에 활용
```

---

## Task Management (2.1.16+)

> **멀티 세션 Shared Brain** - 여러 터미널에서 같은 Task 목록 공유

### 환경변수
```bash
# Epic 작업 시 모든 터미널에서 동일 ID 사용
CLAUDE_CODE_TASK_LIST_ID=EP032 claude

# 저장 위치: ~/.claude/tasks/{TASK_LIST_ID}/

# Task 시스템 비활성화 (이전 Todo 시스템 사용, 2.1.19+)
CLAUDE_CODE_ENABLE_TASKS=false claude
```

### 사용 시나리오
| 시나리오 | 터미널 1 | 터미널 2 | 터미널 3 |
|---------|----------|----------|----------|
| Epic 병렬 | task-planner | code-writer | test-creator |
| 의존성 | TaskCreate T001~T005 | T001 완료 → T002 자동 시작 | T003 대기 |

### Task 도구 vs Task 파일(.md)
| 구분 | Task 도구 | Task 파일 (.md) |
|------|----------|-----------------|
| 목적 | 멀티 세션 조율 | 요구사항 문서 |
| 저장 | ~/.claude/tasks/ | Git 저장소 |
| 용도 | 실행 시 의존성 관리 | PR/리뷰용 |

### 키보드 단축키 (2.1.18+)
```bash
/keybindings  # 커스텀 단축키 설정
```

---

## Frontend Data Fetching 패턴

**기본**: `useEffect` + `fetch` (단순, Provider 불필요)
**성능최적화 시에만**: React Query, SWR (캐싱/중복제거 필요 시)
```typescript
// ✅ 기본 패턴 (권장)
useEffect(() => {
  let isMounted = true;
  async function fetchData() {
    const result = await fetch('/api/...');
    if (isMounted) setData(result);
  }
  fetchData();
  return () => { isMounted = false; };
}, [userId]); // primitive 의존성만

// ❌ React Query (성능 이슈 없으면 불필요)
// useQuery({ queryKey: [...], queryFn: ... })
```
