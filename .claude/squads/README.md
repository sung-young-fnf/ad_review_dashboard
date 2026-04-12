# Mission Squad System

> 하달식 Agent 체인을 미션 기반 스쿼드로 대체한다.

## 이원 구조

| 모드 | 조건 | 비용 |
|------|------|------|
| **Solo** | Code-Change minor(1-4줄) 또는 사용자 "solo만" 명시 | 1x |
| **Squad + multi-model** (기본값) | 나머지 모든 요청 | 2-4x |

**Squad + multi-model이 기본값이다.** Codex/Gemini가 항상 참여한다.
Solo는 1-4줄 간단 수정이거나 사용자가 "solo만"으로 명시할 때만 적용.

### Non-Delegation Signals (위임하지 않을 때)

> 영감: hermes-CCC subagent-driven-development — "위임 overhead > 단독 실행"이면 Solo가 맞다

Squad 편성 조건을 충족하더라도, 아래 중 하나라도 해당하면 **Solo로 다운그레이드**:

| 신호 | 이유 | 예시 |
|------|------|------|
| **Blocking Dependency** | 다음 액션이 결과에 blocked → 위임하면 유휴 대기만 발생 | "이 API 응답 shape을 확인해야 다음 단계 진행 가능" |
| **Same File Ownership** | 같은 파일을 여러 Agent가 건드리면 충돌 불가피 | BE Service 1개 파일에 2개 Task가 의존 |
| **Unframed Problem** | 문제 정의가 안 됐으면 위임받은 Agent가 방향을 잃음 | "개선해줘", "뭔가 이상해" (구체적 증상 없음) |
| **Faster Alone** | Squad 편성(~2분) + 통합(~3분) > 단독 실행 시간 | 3개 파일 10줄 수정, 총 5분이면 끝남 |
| **Main Thread Idle** | 위임 후 Main Thread가 할 병렬 작업이 없으면 순수 낭비 | 위임하고 "완료 대기"만 하는 상황 |

**적용 순서**: Non-Delegation 체크 → Squad 규모 판단 → 편성
**원칙**: "Keep blocking work local. Delegate bounded sidecar work."

---

## Full Pipeline (`/epic-execute`)

> `/epic-execute` 한 번이면 5단계 Squad 파이프라인이 자동 실행

```
Phase 1: ANALYSIS   → analysis-squad  → 코드베이스 사전분석 (5분)
    ↓
Phase 2: PLANNING   → planning-squad  → Epic/Story 생성 (15분)
    ↓
Phase 3: DESIGN     → design-squad    → Task 분해+검증 (10분)
    ↓
Phase 4: IMPLEMENT  → epic-squad      → 코드 구현 (2-8시간)
    ↓
Phase 5: QUALITY    → quality-squad   → 품질 검증 (5분)
```

- 각 Phase 산출물이 이미 있으면 자동 스킵
- 각 Phase에서 Solo/Squad 독립 판단
- `--from-phase N` 으로 특정 Phase부터 시작 가능
- 상세: `.claude/skills/epic-execute/SKILL.md`

---

## Squad Dispatcher

Main Thread가 요청을 받으면 아래 기준으로 규모를 판단한다.

### 규모 판단 기준

```
EPIC         "시스템", "플랫폼", "아키텍처", "대형", 명시적 Epic 요청
PLANNING     "기획 스쿼드", "planning squad", "에픽 생성 스쿼드", "스토리 생성 스쿼드"
ANALYSIS     "사전분석", "전수분석", "코드분석 스쿼드", "analysis squad"
DESIGN       "설계 스쿼드", "design squad", "task 분해 스쿼드"
QUALITY      "품질 검증", "quality squad", "릴리즈 검증", "전수 검증"
STORY        "기능 추가", "API", "컴포넌트", "통합", 200자+ 설명
BUG_CRITICAL "긴급" + ("버그"|"에러"|"장애"|"다운")
DB           "스키마", "마이그레이션", "DDL", "테이블"
UX           ("ux"|"frontend") + ("개선"|"감사"|"분석")
SOLO         Code-Change minor(1-4줄) 또는 사용자 "solo만" 명시
```

키워드 매칭 순서: EPIC > PLANNING > ANALYSIS > DESIGN > QUALITY > BUG_CRITICAL > DB > UX > STORY > SOLO
**기본 Fallback**: 키워드 미매칭 + Code-Change major → **STORY Squad** (SOLO 아님)

### +multi-model (기본값: 항상 활성)

**기본값: 활성화.** Codex/Gemini가 모든 Squad에 자동 참여한다.
사용자가 "solo만", "claude만"으로 명시할 때만 비활성화.

```
+multi-model  항상 (기본값)
-multi-model  "solo만", "claude만", "단독", "혼자" → Codex/Gemini 제외
```

Squad 편성 시 **일부 역할에 Codex/Gemini delegate를 자동 배치**한다.
어떤 역할에 어떤 모델을 배치할지는 Lead가 작업 특성에 맞게 판단한다.

**모델별 강점 참고** (경향성, 절대 규칙 아님):

| 영역 | 추천 모델 | 이유 |
|------|----------|------|
| 계획/설계/아키텍처 | Claude (Opus) | 구조적 사고 + 코드베이스 직접 접근 |
| UI/UX 시각 분석 | Gemini | 멀티모달 이미지 이해 강점 |
| 대규모 코드 분석 | Gemini Pro | 100만 토큰 컨텍스트 → 전체 모듈 한번에 |
| 깊은 코드 디버깅 | Codex (o3/o4) | 코드 추론 체인 |
| 웹 리서치/최신 정보 | Codex (web_search) | 실시간 웹 검색 |
| 코드 생성/편집 | Claude | 코드베이스 직접 접근 + 파일 편집 |

> 세 모델 모두 코드 분석 가능. 위는 상대적 강점 참고용.

**🔴 Claude 최종 판단 필수**: 병렬 실행이더라도 Codex/Gemini 결과를 Claude가 검증 후 채택. 무조건 수용 금지.
**제약**: Claude가 항상 Lead + 파일 편집 담당. Codex/Gemini는 읽기 전용 기본.
**비용**: Codex/Gemini 무제한 — 비용 제약 없이 적극 활용. 모든 분석/검증 역할에 병렬 배치.

상세: @.claude/guides/MULTI_MODEL_STRATEGY.md

---

## 규모별 스쿼드 편성표

| 규모 | 스쿼드 | 팀원 | subagent_type 매핑 |
|------|--------|------|-------------------|
| EPIC | epic-squad | architect(`general-purpose`) + dev x2(`04-implementation/code-writer`) + reviewer(`general-purpose`) | 4명 |
| PLANNING | planning-squad | planner(`general-purpose`) + code-scanner(`Explore`) + ux-advisor(`general-purpose`, 조건부) | 2-3명 |
| ANALYSIS | analysis-squad | coordinator(`general-purpose`) + structure-analyzer + quality-inspector + tech-analyzer(조건부) | 3-4명 |
| DESIGN | design-squad | architect(`general-purpose`) + task-validator + flow-analyzer(조건부) | 2-3명 |
| QUALITY | quality-squad | quality-lead(`general-purpose`) + impl-validator + perf-checker(조건부) + security-checker(조건부) | 3-4명 |
| STORY | story-squad | tech-lead(`general-purpose`) + dev(`04-implementation/code-writer`) | 2-3명 |
| STORY (fullstack) | fullstack-parallel-squad | architect(`general-purpose`) + backend-dev + bff-dev + frontend-dev(`04-implementation/code-writer`) | 4명 |
| BUG_CRITICAL | bug-squad | investigator x2(`04-implementation/code-writer`) | 2명 |
| DB | db-squad | db-architect(`general-purpose`) + db-dev(`04-implementation/db-code-writer`) | 2명 |
| UX | ux-squad | ux-analyst(`general-purpose`) + ui-dev(`04-implementation/code-writer`) + verifier(`general-purpose`) | 3명 |
| SOLO | - | 단독 Agent (code-writer / error-fixer / quick-modifier) | 팀 없음 |

---

## Squad Lifecycle

### 1. 편성 (Formation)

```
1. Teammate.spawnTeam(team_name="{type}-{id}-{YYYYMMDD}")
2. FOR role IN template.roles:
     Task(subagent_type=role.agent_type, team_name=..., name=role.name, prompt=role.system_prompt)
3. SendMessage(recipient=lead, content=MISSION_BRIEF)
```

- `team_name` 형식: `epic-EP114-20260206`, `bug-ISS42-20260206`
- Lead가 첫 번째로 생성되고, MISSION_BRIEF를 수신한다

### 2. 실행 (Execution)

**Lead 역할:**
1. 요구사항 분석
2. 문서 생성 (Epic/Story/Task `.md` - 기존 `docs/epics/` 형식 유지)
3. `TaskCreate`로 공유 Task List 등록
4. 의존성 설정 (`addBlockedBy` / `addBlocks`)

**Member 역할:**
1. `TaskList()` -> unblocked Task 확인
2. Task claim (`TaskUpdate` status: `in_progress`)
3. 구현
4. `TaskUpdate` status: `completed`
5. 다음 unblocked Task로 이동

**Inter-Story Test Gate (필수):**
> WHY: Story 간 회귀 방지. 28건 buggy_code 마찰 중 대부분이 Story 경계에서 발생
> -- Insights 마찰 분석

```
Story N 완료
  ↓
[Test Gate] pnpm build && pnpm tsc --noEmit
  ↓ PASS → Story N+1 시작
  ↓ FAIL → Story N 수정 (다음 Story 진행 금지)
```

- 각 Story 완료 후 **반드시 빌드+타입체크** 통과해야 다음 Story 진행
- 실패 시 해당 Story 내에서 수정 완료할 때까지 다음 Story 블록
- Lead가 `TaskCreate` 시 Story 간 `addBlockedBy` 설정으로 강제

**Reviewer 역할:**
1. completed Task 검증
2. 이슈 발견 시 dev에게 `SendMessage` 피드백
3. 수정 확인 후 승인

### 2.5. Worktree Isolation (v2.1.63+) — 🔴 미작동 (순차 실행 프로토콜 유지)

> **🔴 STATUS: 4회 테스트 실패 — Worktree 생성 자체가 안 됨 (2026-04-12, v2.1.104)**
> 2.1.50~2.1.98에서 worktree 관련 대규모 수정 완료:
> - 2.1.50: `isolation: "worktree"` Agent frontmatter 지원 + 비치명적 초기화
> - 2.1.63: .claude/ 설정 worktree 간 자동 공유 (별도 복사 불필요)
> - 2.1.72: `ExitWorktree` 도구 + `CLAUDE_CODE_DISABLE_CRON` 긴급 중단
> - 2.1.76: `worktree.sparsePaths` 대형 모노레포 지원 + stale worktree 자동 정리
> - 2.1.77: "Always Allow" compound command 수정 + stale worktree 경합 방지
> - 2.1.81: worktree 세션 resume 시 자동 복귀
> - 2.1.94: `--resume` worktree 직접 resume 지원
> - **2.1.97: subagent worktree cwd 누수 수정** (부모 세션 Bash에 cwd 역류 방지)
> - **2.1.97: MCP HTTP/SSE ~50MB/hr 메모리 누수 수정** (장시간 worktree 안정성)
> - **2.1.97: Stop/SubagentStop hook 장시간 세션 실패 수정** (worktree cleanup 안정성)
> - **2.1.98: stale worktree cleanup — untracked files 보존** (미저장 작업 손실 방지)
> - **2.1.98: team members leader 퍼미션 모드 상속** (Squad 퍼미션 일관성)
> - **2.1.98: background subagent 실패 시 partial progress 보고** (장애 진단 개선)
>
> **이전 이슈 상태** (2026-04-10 기준 — 3대 blocker 모두 해소 + 2.1.98 추가 안정화):
> - #29110: 데이터 유실 → ✅ 2.1.77 transcript 복구 + 2.1.97 compaction 중복 방지
> - #27649: silent freeze → ✅ 2.1.47+ 메모리 개선 + 2.1.97 MCP 메모리 누수 수정
> - #28175: 팀 worktree 생성 실패 → ✅ 2.1.63 설정 공유 + 2.1.50 non-fatal init
> - cwd 누수 → ✅ 2.1.97 subagent worktree cwd override 격리 수정
> - stale cleanup 데이터 손실 → ✅ 2.1.98 untracked files 보존
> - Squad 퍼미션 불일치 → ✅ 2.1.98 leader 퍼미션 상속
>
> **테스트 결과 (2026-04-12, v2.1.104)**: 4회차 테스트도 실패 — WorktreeCreate hook 발화 `"path not provided, skipped"`, git worktree add 자체 미실행. v2.1.101 "subagent worktree Read/Edit 거부 수정"은 별개 이슈 (생성된 worktree 내 파일 접근 문제). macOS Darwin 24.6.0에서 worktree 생성 조건 자체가 미충족.
> **이전 결과 (2026-04-10, v2.1.98)**: 3회 테스트 모두 동일 실패 (clean/dirty 무관).
> **현재 권장**: 순차 실행 프로토콜 유지. 다음 재테스트: CC 릴리즈 노트에서 "worktree creation" 관련 수정 언급 시.
> **대안 유지**: dev-1, dev-2 순차 실행이 여전히 안전한 대안

~~원래 설계: dev-1, dev-2가 같은 파일을 수정할 때 독립 브랜치+파일시스템으로 충돌 제거~~

**현재 적용 상태** (🔴 Worktree 미작동 — 순차 실행):

| Squad | 역할 | `isolation: worktree` | 상태 |
|-------|------|:---:|------|
| epic-squad | dev-1, dev-2 | 🔴 미작동 | v2.1.104 4회 테스트 실패, 순차 실행 |
| bug-squad | investigator-1, investigator-2 | 🔴 미작동 | v2.1.104 4회 테스트 실패, 순차 실행 |
| story-squad | dev | 🔴 미작동 | v2.1.104 4회 테스트 실패, 순차 실행 |
| 모든 Squad | architect, reviewer, ux-reviewer | X | 원래부터 미사용 |
| planning/analysis/design/quality | 전원 | X | 코드 작성 안 함 |

**워크트리 동작 방식 (v2.1.63+ 네이티브 지원):**
```
1. Agent frontmatter에 `isolation: worktree` 선언 (v2.1.50+)
   또는 Agent Tool 호출 시 isolation: "worktree" 지정
2. Claude Code가 자동으로 독립 워크트리 생성
3. .claude/ 설정은 worktree 간 자동 공유 (v2.1.63+, 별도 복사 불필요)
4. Agent가 별도 브랜치에서 작업
5. 완료 → Lead에게 워크트리 경로+브랜치 반환
6. Lead가 main에 머지 → pnpm build 검증
7. 세션 종료 시 미사용 워크트리 자동 정리
8. stale worktree는 다음 세션에서 자동 cleanup (v2.1.76+)
```

**settings.json worktree 설정** (이미 적용됨):
```json
"worktree": {
  "symlinkDirectories": ["node_modules", ".next", ".cache"]
}
```
대형 모노레포에서 `worktree.sparsePaths`로 특정 디렉토리만 체크아웃 가능 (v2.1.76+).

**ExitWorktree (v2.1.72+):**
> `ExitWorktree` 도구로 워크트리 세션 중간에 격리를 해제할 수 있다.
> 사용 시점: dev가 작업 완료 후 main으로 복귀해야 할 때, 또는 Lead가 워크트리 결과를 확인 후 탈출시킬 때.
> `EnterWorktree` → 작업 → `ExitWorktree` → main 복귀 패턴 사용 가능.

**순차 실행 프로토콜 (현재 적용 중 — worktree 비활성화 대안):**
```
architect: TaskCreate로 Task 생성 + blockedBy 의존성 설정
    ↓
dev-1: unblocked Task claim → 구현 → TaskUpdate(completed)
    ↓
dev-2: dev-1 완료 Task 기반 unblocked Task claim → 구현
    ↓
architect: pnpm build && pnpm tsc --noEmit
    ↓ PASS
다음 단계 진행
```

**예외:**
- DB migration Task는 워크트리 격리 대상에서 제외 (공유 DB 충돌 위험)
- Solo 모드는 워크트리 미사용 (단독 Agent = 충돌 불가)

**사용자 관점:**
- 워크트리를 직접 관리할 필요 없음 — main 브랜치만 보면 됨
- 테스트는 항상 main에서 `pnpm dev` 실행
- 머지 충돌은 Lead가 해결하거나, 불가 시 사용자에게 보고

**Hook 호환성:**
- 모든 활성 Hook이 `${CLAUDE_PROJECT_DIR:-...}` 패턴을 사용하여 워크트리에서도 `.claude/` 정상 접근
- 새 Hook 작성 시 bare `git rev-parse --show-toplevel` 사용 금지 → 반드시 `$CLAUDE_PROJECT_DIR` 우선

### 2.6. Worktree Non-Fatal Initialization (agtx 패턴)

> WHY: worktree 초기화 시 부분 실패가 전체를 막으면 안 됨.
> agtx는 initialize_worktree() → Vec<warnings> 반환으로 부분 실패를 허용.

**원칙**: 초기화 실패 = 경고(계속 진행), 치명적 실패만 중단

| 초기화 단계 | 실패 시 행동 | 이유 |
|------------|------------|------|
| ~~.claude/ 복사~~ | **불필요 (v2.1.63+)** | Project configs & auto memory가 worktree 간 자동 공유됨 |
| docs/epics/ 복사 | 경고 + 계속 | 참조 문서 없어도 구현 가능 |
| pnpm install | 경고 + 계속 | 이미 node_modules 있을 수 있음 |
| git worktree 생성 | **중단** | 격리 실패는 치명적 |

**멱등성**: 같은 worktree 재생성 요청 시 기존 반환 (재생성 안 함)

### 2.7. Artifact-Based Phase Completion (agtx 패턴)

> WHY: agent가 "완료" 보고를 누락하거나 조기 선언하는 문제 해소.
> 산출물 파일 존재 여부로 Phase 완료를 이중 검증.

**Squad YAML artifacts 섹션**:
```yaml
artifacts:
  planning:
    path: "docs/epics/{epic_id}/stories/*.md"
    skip_if_exists: true
```

- `path`: 해당 Phase의 산출물 파일 경로 (glob 패턴 지원)
- `skip_if_exists`: true이면 이미 산출물 있으면 Phase 스킵 (재작업 방지)
- `signal`: 파일이 아닌 명령 실행 결과로 완료 판정 (예: `pnpm build`)

**검증 우선순위**: TaskUpdate(completed) + artifact 존재 = 확실한 완료
- TaskUpdate만 있고 artifact 없음 → 경고 표시
- artifact만 있고 TaskUpdate 없음 → 자동 완료 제안

### 2.8. Heartbeat 패턴 — Monitor (권장) + `/loop` (레거시)

> WHY: Squad 장시간 운영 시 teammate가 stall되어도 Lead가 인지 못하는 문제.
> Monitor 도구로 이벤트 기반 감지, `/loop`은 LLM 판단이 필요한 경우만 사용.

#### Monitor 기반 (권장 — 토큰 90%+ 절감)

> Monitor는 셸 스크립트가 stdout으로 이벤트를 방출할 때만 알림 → 빈 폴링 없음
> "감지만 필요" → Monitor / "감지 + LLM 판단 + 자동 행동" → `/loop`

**Squad Stall 감지:**
```bash
Monitor({
  description: "Squad member stall 감지",
  persistent: true,
  command: '''
    TEAM_DIR=".claude/squad-logs/${TEAM_NAME:-default}"
    while true; do
      LATEST=$(ls -t "$TEAM_DIR"/evt-*.json 2>/dev/null | head -1)
      if [ -n "$LATEST" ]; then
        EVT_EPOCH=$(basename "$LATEST" | grep -o "[0-9]*" | head -1)
        DIFF=$(( $(date +%s) - ${EVT_EPOCH:0:10} ))
        if [ $DIFF -gt 600 ]; then
          AGENT=$(jq -r '.data.agent_name // "unknown"' "$LATEST")
          echo "STALL: ${AGENT} — ${DIFF}s idle"
        fi
      fi
      sleep 60
    done
  '''
})
# → 알림 수신 후 Lead가 SendMessage로 해당 멤버 진행 촉구
```

**배포 완료 감지:**
```bash
Monitor({
  description: "배포 완료 감지: ${APP_NAME}",
  persistent: false,
  timeout_ms: 900000,
  command: '''
    SHA=$(git rev-parse --short HEAD)
    while true; do
      CONCLUSION=$(gh run list --commit "$SHA" --json conclusion \
        -q ".[0].conclusion // empty" 2>/dev/null) || true
      if [ -n "$CONCLUSION" ]; then
        echo "CI: $CONCLUSION ($SHA)"
        exit 0
      fi
      sleep 30
    done
  '''
})
```

#### `/loop` 기반 (LLM 판단 필요 시)

```bash
# LLM이 TaskList를 읽고 판단 + SendMessage 행동까지 자동 수행
/loop 3m "TaskList로 모든 멤버 상태 확인. stalled(10분+ 미변경) 작업 있으면 SendMessage로 진행 촉구"
```

#### 선택 기준

| 상황 | 도구 | 이유 |
|------|------|------|
| 상태 변화 **감지만** | Monitor | 셸 스크립트가 필터링, 토큰 절감 |
| 감지 + **LLM 판단 + 자동 행동** | `/loop` | 판단/행동에 LLM 호출 필수 |
| **LLM 자기 페이싱** (동적 간격) | `ScheduleWakeup` | `/loop` dynamic 모드 전용, 캐시 TTL 고려 지연 |
| 일회성 **완료 대기** | `Bash(run_in_background)` | 단순 대기 |

| 기존 방식 | Monitor/loop 전환 | 효과 |
|----------|------------------|------|
| Lead 수동 TaskList 확인 | Monitor (stall 감지) + Lead SendMessage | 토큰 90% 절감 |
| `/loop 5m /deploy-validate` | Monitor (CI/ArgoCD 이벤트) | 즉시 반응 + 토큰 절감 |
| Ralph Loop + `/loop 2m` | Monitor (ralph.json 감시) | 경량 heartbeat |

**긴급 중단:**
- Monitor: `TaskStop`으로 개별 중단
- `/loop`: `CLAUDE_CODE_DISABLE_CRON=1` 환경변수로 전체 중단
- `/loop` 설정 후 문제 발생 시 세션을 종료하지 않고도 반복 실행 중단 가능

### 3. 해산 (Disbandment)

```
Lead -> Main Thread: "모든 Task 완료"
Main Thread:
  FOR member IN team:
    SendMessage(type="shutdown_request", recipient=member)
  Teammate.cleanup()
```

모든 Task가 completed 상태가 되면 Lead가 Main Thread에 보고하고, Main Thread가 팀을 해산한다.

---

## Planning Squad (기획 품질 강화)

> WHY: EP135/136에서 7/8 Story가 이미 구현됨 — 코드 검증 없는 기획이 최대 마찰 원인
> Solo 기획의 "이미 구현됨" 놓침, UX AC 누락, 과대 스코핑 문제를 역할 분리로 해결

### Hybrid 모드 (Pre-Flight + Full Squad)

| 모드 | 조건 | 비용 | 효과 |
|------|------|------|------|
| **Pre-Flight Scanner** | 모든 Epic 기본 적용 | 1.3x | "이미 구현됨" 80% 방지 |
| **Full Planning Squad** | 트리거 조건 충족 시 | 2.5x | 코드 검증 + UX AC 보강 |

### Pre-Flight Scanner (Solo에서도 자동 실행)

```
Epic 생성 요청
    ↓
[Pre-Flight] Code Scanner (Explore agent)
    ├─ 키워드별 Grep/Glob/serena 전수 검사
    ├─ IMPLEMENTED / PARTIAL / NOT_FOUND 분류
    └─ 보고서 → epic-creator 참고
    ↓
epic-creator (Solo, Scanner 결과 반영)
```

### Full Planning Squad 트리거 조건

다음 중 하나 이상 충족 시 Full Squad 편성:
- Story 예상 5개+
- 크로스 도메인 (Backend + Frontend 동시 수정)
- UX 영향 있음 (User Impact: Yes)
- 범위 불명확 ("개선해줘", "리팩토링해줘")
- 기존 코드 재사용 가능성 높음

### Full Squad 워크플로우

```
Planner: 초안 작성 (Goal State + Story 목록)
    ↓ (병렬)
Code Scanner: 코드 전수 검사       UX Advisor: UX 영향 평가
    │ "S03 이미 구현됨"                │ "S02에 에러 메시지 AC 필요"
    └──────────┬───────────────────────┘
               ↓
Planner: 종합 (구현된 Story 제거, UX AC 추가)
    ↓
최종 Epic/Story 문서 → story-validator → task-planner
```

### 역할 상세

| 역할 | agent_type | 핵심 | 참조 |
|------|-----------|------|------|
| Planner (Lead) | general-purpose | 종합·조율·문서 생성 | roles/planner.md |
| Code Scanner | Explore | 기존 구현 전수 검사 | roles/code-scanner.md |
| UX Advisor (조건부) | general-purpose | UX AC 보강 제안 | roles/ux-advisor.md |

---

## Analysis Squad (사전분석 병렬화)

> WHY: 7개 사전분석 Agent를 순차 실행하면 ~20분 → 병렬이면 ~5분 (4x 절감)
> Epic 구현 전 코드베이스 전수 파악이 정확할수록 구현 중 재작업 감소

### 워크플로우

```
Analysis Coordinator: 분석 범위 정의
    ↓ (병렬 — 7개 동시)
code-structure-analyzer  |  code-quality-inspector  |  tech-stack-analyzer
business-analyzer        |  git-history-analyzer    |  test-env-analyzer
learnings-researcher
    ↓
Coordinator: 결과 종합 → 통합 보고서
```

### 트리거 조건
- Epic 구현 시작 전 (코드베이스 전수 파악 필요)
- 새 도메인 진입 / 대규모 리팩토링 / 기술 부채 감사

### 역할 상세

| 역할 | agent_type | 핵심 | 참조 |
|------|-----------|------|------|
| Coordinator (Lead) | general-purpose | 디스패치·종합·보고 | roles/analysis-coordinator.md |
| Structure Analyzer | 01-pre-analysis/code-structure-analyzer | 의존성·아키텍처 | 기존 Agent |
| Quality Inspector | 01-pre-analysis/code-quality-inspector | 복잡도·보안·부채 | 기존 Agent |
| Tech Analyzer (조건부) | 01-pre-analysis/tech-stack-analyzer | 버전·호환성 | 기존 Agent |

---

## Design Squad (Task 설계 병렬 검증)

> WHY: task-planner → task-validator → spec-flow-analyzer 순차 실행 비효율
> 검증과 플로우 분석을 병렬로 돌리면 40% 시간 절감, 설계 단계 gap 조기 발견

### 워크플로우

```
Design Architect: Story 분석 → Task 분해 (task-planner 실행)
    ↓ (병렬)
task-validator: AC 커버리지 검증      spec-flow-analyzer: 플로우 완전성
    │ "T003 AC 누락"                     │ "에러 복구 경로 없음"
    └──────────┬─────────────────────────┘
               ↓
Architect: 피드백 반영 → Task 최종 확정
```

### 트리거 조건
- Story의 Task 예상 5개+
- 크로스 도메인 Story (Backend + Frontend + DB)
- 사용자 흐름이 복잡 (분기 3개+)

### 역할 상세

| 역할 | agent_type | 핵심 | 참조 |
|------|-----------|------|------|
| Architect (Lead) | general-purpose | Task 분해·종합·확정 | roles/design-architect.md |
| Task Validator | 03-design/task-validator | AC 커버리지·의존성 | 기존 Agent |
| Flow Analyzer (조건부) | 03-design/spec-flow-analyzer | 플로우 gap·edge case | 기존 Agent |

---

## Quality Squad (구현 후 병렬 검증)

> WHY: 순차 검증 (impl-validator → perf-oracle → simplicity-reviewer → security-auditor) = ~17분
> 병렬 검증 = ~5분 (3.4x 절감), P0 이슈 조기 발견으로 릴리즈 후 장애 방지

### 워크플로우

```
Quality Lead: 변경 범위 파악 → 필요 Agent 결정
    ↓ (병렬)
impl-validator     |  performance-oracle    |  code-simplicity-reviewer
security-auditor   |  ui-tester (조건부)
    ↓
Quality Lead: 결과 종합 → P0 있으면 error-fixer 즉시 위임
    ↓
통합 품질 보고서 + 통과/실패 판정
```

### 트리거 조건
- Epic/대형 Story 구현 완료 (전체 품질 검증 필요)
- 릴리즈 전 최종 검증
- 보안 감사 / 성능 이슈 의심

### 역할 상세

| 역할 | agent_type | 핵심 | 참조 |
|------|-----------|------|------|
| Quality Lead | general-purpose | 디스패치·종합·판정 | roles/quality-lead.md |
| Impl Validator | general-purpose | AC 달성·API 체인 | 기존 Agent |
| Perf Checker (조건부) | general-purpose | N+1·Big-O·번들 | 기존 Agent |
| Security Checker (조건부) | general-purpose | OWASP Top 10 | 기존 Agent |

---

## Solo Mode (minor 전용)

Code-Change minor(1-4줄) 또는 사용자 "solo만" 명시 시에만 적용.

| 작업 유형 | Agent | 비고 |
|----------|-------|------|
| 소형 버그 | error-fixer 단독 | historian 먼저 호출 |
| 간단 수정 (1-4줄) | quick-modifier 단독 | Main Thread에서 직접 가능 |
| 단일 Task 구현 | code-writer 단독 | validator 체인 포함 |

---

## 비용 정책 (Codex/Gemini 무제한)

1. **Squad + multi-model 기본값** — Codex/Gemini 항상 참여 (minor만 Solo)
2. **적극 배치** — 모든 분석/검증/리뷰 역할에 Codex 또는 Gemini 병렬 배치
3. **Solo에서도 활용** — 세컨드 오피니언으로 Codex/Gemini delegate Task 적극 호출
4. **broadcast 최소화** — 1:1 DM 우선, 전체 알림은 마일스톤만
5. **조기 해산** — 모든 Task 완료 즉시 cleanup

> Codex/Gemini 호출 비용 = 0. "돌려봐서 손해 없다" 원칙으로 최대한 활용한다.

---

## 기존 시스템 호환

| 항목 | 호환 방식 |
|------|----------|
| 44개 Agent 파일 | 수정 없음. Role이 감싸서 사용 |
| `docs/epics/` 문서 구조 | Lead가 기존 형식으로 생성 |
| Hook 시스템 | Squad 모드 감지 시 chain guard bypass |
| Memory MCP | 기존 serena/historian/praetorian 그대로 사용 |
| Task 도구 | `CLAUDE_CODE_TASK_LIST_ID` 공유로 멀티 세션 조율 |

---

## Subagent Resume 패턴 (v2.1.77+ SendMessage 방식)

> WHY: code-writer가 빌드 실패로 중단된 경우, 새로 시작하면 컨텍스트 손실. SendMessage로 기존 Agent를 깨워 이어서 작업하면 분석/수정 내역 유지.
> **v2.1.77 Breaking Change**: `Task(resume: ...)` 파라미터 제거됨. `SendMessage({to: agentId})` 사용 필수.

### 사용 시점

| 상황 | 행동 |
|------|------|
| code-writer 빌드 실패 후 중단 | SendMessage로 에러 컨텍스트 유지하며 재시도 |
| 대형 구현 중 세션 타임아웃 | SendMessage로 이어서 작업 |
| 리뷰 피드백 후 수정 필요 | 같은 에이전트에 SendMessage로 피드백 반영 |

### 사용 방법

```
# 이전 agent_id로 SendMessage — stopped agent도 자동 재개됨 (v2.1.77+)
SendMessage({
  to: "agent-id-from-previous-run",
  content: "빌드 에러를 수정해주세요: [에러 내용]"
})
```

- SubagentStop hook에서 `agent_id`와 `agent_transcript_path` 제공 (v2.0.42+)
- SendMessage 시 이전 대화 컨텍스트 전체 유지, stopped agent 자동 재개
- Agent에 `name` 파라미터를 설정하면 `SendMessage({to: "agent-name"})` 으로도 접근 가능

### code-writer-retry-handler.sh 연동

기존 `code-writer-retry-handler.sh`가 SubagentStop에서 실패 감지 시 agent_id를 기록합니다.
Main thread가 이를 읽어 SendMessage로 재개 여부를 판단합니다.

---

## Squad Event Log (Event Sourcing)

> WHY: Squad 실행 과정이 세션 종료 시 소멸 → 디버깅, 성과 분석, 병목 파악 불가
> ClawTeam Event Sourcing 패턴 참고: 불변 이벤트 로그로 전체 실행 이력 추적

### 자동 기록 (Hook 연동)

4개 Hook에서 자동으로 이벤트 기록:
- `SubagentStart` → `agent_start` 이벤트
- `SubagentStop` → `agent_stop` 이벤트
- `TaskCreated` → `task_created` 이벤트
- `TaskCompleted` → `task_completed` 이벤트

### 저장 구조

```
.claude/squad-logs/                    # .gitignore (런타임 데이터)
├── {team-name}/
│   ├── evt-{epoch}-{uid}.json         # 불변 이벤트 (수정 안 함)
│   ├── summary.json                   # 증분 집계 (자동 업데이트)
│   └── report.md                      # 요약 보고서 (수동 생성)
└── default/                           # 팀 미지정 이벤트
```

### 이벤트 스키마

```json
{
  "id": "evt-17748272143N-432b6ca4",
  "event_type": "agent_stop",
  "team_name": "epic-EP211-20260330",
  "timestamp": "2026-03-30T10:00:00Z",
  "hook_source": "SubagentStop",
  "data": {
    "agent_name": "epic-EP211-20260330:dev-1",
    "agent_type": "code-writer",
    "result_preview": "Task T001 completed"
  }
}
```

### 보고서 생성

```bash
# Squad 완료 후 보고서 생성
.claude/hooks/utils/squad-report-generator.sh {team-name}
```

---

## Epic Snapshot Manager (Checkpoint/Restore)

> WHY: Epic 장시간 실행 중 실패 시 처음부터 재시작 → Phase별 체크포인트로 빠른 복구
> ClawTeam SnapshotManager 패턴 참고: JSON 번들로 전체 상태 저장/복원

### 사용법

```bash
# 스냅샷 생성 (Phase 완료 시)
.claude/hooks/utils/epic-snapshot.sh create EP210 "phase1-complete"

# 스냅샷 목록
.claude/hooks/utils/epic-snapshot.sh list EP210

# 현재 상태와 비교
.claude/hooks/utils/epic-snapshot.sh diff EP210 {snap-id}

# 복원 (자동으로 현재 상태 백업 후 복원)
.claude/hooks/utils/epic-snapshot.sh restore EP210 {snap-id}

# 복원 미리보기
.claude/hooks/utils/epic-snapshot.sh restore EP210 {snap-id} --dry-run
```

### 저장 구조

```
docs/epics/{epic-dir}/.snapshots/
├── snap-20260330T100000-phase1-complete.json
├── snap-20260330T140000-phase2-stories.json
└── snap-20260330T160000-pre-restore-backup.json   # 복원 전 자동 백업
```

### 번들 내용

| 항목 | 설명 |
|------|------|
| `meta` | 스냅샷 ID, Epic명, Git 브랜치/커밋, Story/Task 수 |
| `epic_md` | epic.md 전문 |
| `stories` | 모든 S*.md 파일 내용 |
| `tasks` | tasks/*.md 파일 내용 |
| `progress_md` | PROGRESS.md 상위 50줄 |
| `squad_summary` | Squad Event Log 요약 (있으면) |

### 권장 사용 시점

| 시점 | 태그 | 설명 |
|------|------|------|
| Epic 기획 완료 | `planning-done` | Story 문서 확정 |
| Task 설계 완료 | `design-done` | Task 분해 확정 |
| Phase N 구현 완료 | `phaseN-done` | 중간 체크포인트 |
| 품질 검증 통과 | `qa-passed` | 배포 직전 |
| 배포 전 | `pre-deploy` | 롤백 포인트 |

---

## 디렉토리 구조

```
.claude/squads/
  README.md          # 이 파일 (Dispatcher 로직 + 개요)
  roles/             # 역할별 system prompt 정의
  templates/         # 스쿼드 유형별 편성 템플릿

.claude/squad-logs/  # 런타임 이벤트 로그 (.gitignore)
.claude/hooks/utils/
  squad-report-generator.sh   # 보고서 생성
  epic-snapshot.sh            # 스냅샷 관리
.claude/hooks/post/
  squad-event-logger.sh       # 이벤트 자동 기록 Hook
```
