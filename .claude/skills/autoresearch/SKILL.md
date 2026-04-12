---
name: autoresearch
description: "스킬/Agent 프롬프트를 Binary Eval 기반 자율 루프로 최적화. Karpathy autoresearch 방법론 적용. Use when: optimize this skill, improve this skill, 스킬 최적화, Agent 프롬프트 개선, eval 기반 벤치마크, 스킬 품질 측정"
effort: high
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - Agent
  - mcp__serena__write_memory
  - mcp__serena__read_memory
context: fork
user-invocable: true
---

# /autoresearch — Binary Eval 기반 스킬/Agent 자율 최적화

> Karpathy의 autoresearch 방법론: "자율 실험 루프로 프롬프트를 과학적으로 개선한다"
> 스케일(1~10) 대신 Binary Eval(Yes/No)만 사용 — 분산 최소화, 신뢰 가능한 시그널

---

## 핵심 원리

1. **Binary Only** — 모든 평가는 Yes/No. "1~10점"은 noise가 크다.
2. **Single Variable** — 한 번에 한 가지만 변경. 인과관계를 추적한다.
3. **Keep or Discard** — 점수 오르면 Keep, 그 외 Discard + revert.
4. **Squad 기본** — 2~3개 가설을 병렬 실험하여 수렴 속도 2~3x 향상.

---

## 실행 조건

- `/autoresearch [스킬명]` 또는 `/autoresearch [Agent명]`
- "이 스킬 최적화해줘", "Agent 프롬프트 개선", "eval 돌려봐"
- 기존 SKILL.md 또는 Agent `.md` 파일이 있어야 함

### 옵션 플래그

```bash
/autoresearch code-writer                    # 기본: Squad 병렬 루프
/autoresearch code-writer --gen-eval-only    # eval.json만 생성 (검토 후 수동 실행)
/autoresearch code-writer --dry-run          # git 변경 없이 채점만 (eval 품질 확인용)
/autoresearch code-writer --max-loops 30     # 최대 반복 횟수 (기본: 20)
/autoresearch code-writer --runtime          # 런타임 eval 모드 (실제 Agent 실행)
/autoresearch code-writer --runtime --max-runtime-loops 5  # 런타임 실험 최대 횟수
```

| 플래그 | 설명 | 용도 |
|--------|------|------|
| `--gen-eval-only` | eval.json 생성 후 종료 (루프 미실행) | eval을 사람이 검토/수정한 후 본 루프 실행 (Goodhart 방지) |
| `--dry-run` | git commit/reset 없이 Baseline 채점만 | 첫 실행 전 eval 품질 확인, 현재 점수 파악 |
| `--max-loops N` | 최대 실험 수 (기본 20) | 비용/시간 제한 |
| `--runtime` | 런타임 eval 모드 (실제 Agent 실행 + 출력 채점) | 정적 분석 포화 후 다음 단계 |
| `--max-runtime-loops N` | 런타임 실험 최대 수 (기본 3) | 비용 제어 (런타임 = 정적의 10~50x) |

---

## Phase 0: 컨텍스트 수집 (사용자 확인 필수)

**아래 6개 필드가 모두 확인될 때까지 실험을 시작하지 않는다.**

```
1. Target       — 최적화 대상 (스킬 또는 Agent 경로)
2. Test Inputs  — 테스트할 시나리오 3~5개 (다양성 필수, 오버피팅 방지)
3. Eval Criteria — Binary Yes/No 체크 3~6개 (references/eval-guide.md 참조)
4. Runs/Exp     — 실험당 실행 횟수 (기본: 5)
5. Interval     — 실험 주기 (기본: 2분)
6. Budget Cap   — 최대 실험 수 (기본: 무제한, 95%+ 3연속 시 자동 종료)
```

### Agent 최적화 시 추가 수집

Agent를 최적화할 때는 기존 Learning Loop 데이터도 참조:

```bash
# 해당 Agent의 과거 에러/교정 패턴 확인
Grep "{agent_name}" .claude/learnings/ERRORS.md
Grep "{agent_name}" .claude/learnings/LEARNINGS.md
```

이 데이터로 eval 기준을 더 정확하게 설계할 수 있다.

---

## Phase 1: 대상 읽기

1. Target SKILL.md 또는 Agent `.md` 전체 읽기
2. `references/` 에 연결된 파일이 있으면 함께 읽기
3. 핵심 역할, 프로세스 단계, 출력 형식 파악
4. 기존 품질 체크나 안티패턴 메모

---

## Phase 2: Eval Suite 구축

사용자의 eval 기준을 구조화. 모든 eval은 **반드시 Binary**.

```
EVAL [N]: [짧은 이름]
Question: [Yes/No 질문]
Pass: [Yes의 구체적 조건]
Fail: [No가 되는 구체적 조건]
```

### Eval 품질 3-Question Test

각 eval을 확정하기 전에:
1. **두 Agent가 같은 출력에 동의할 수 있는가?** → No면 너무 주관적
2. **스킬이 이 eval만 게이밍할 수 있는가?** → Yes면 너무 좁음
3. **사용자가 이 기준을 실제로 신경 쓰는가?** → No면 삭제

### Max Score 계산

```
max_score = eval_count × runs_per_experiment
```

상세: [references/eval-guide.md](references/eval-guide.md)

### eval.json 형식 (기계 파싱 가능)

eval을 마크다운 대신 **JSON으로 정의**하면 자동 생성/채점/비교가 편리하다.

`--gen-eval-only` 또는 Phase 2에서 다음 형식으로 `autoresearch-{name}/eval.json` 생성:

```json
{
  "skill_name": "code-writer",
  "skill_md_path": ".claude/agents/04-implementation/code-writer.md",
  "generated_at": "2026-03-20T08:30:00Z",
  "tests": [
    {
      "id": "eval-001",
      "description": "빌드 통과",
      "prompt": "간단한 API 엔드포인트 추가 (CRUD)",
      "expected_behavior": "변경 후 pnpm tsc --noEmit 에러 0개",
      "assertions": [
        "pnpm tsc --noEmit 출력에 error가 0개이다",
        "새 파일이 TypeScript strict mode를 따른다"
      ]
    },
    {
      "id": "eval-002",
      "description": "Full-Stack 완전성",
      "prompt": "기존 컴포넌트에 필드 추가 (Backend + Frontend)",
      "expected_behavior": "Backend + BFF Route + Frontend 모두 변경",
      "assertions": [
        "Backend에 DTO/Service/Controller 변경이 있다",
        "app/api/ 에 BFF Route가 있다",
        "Frontend 컴포넌트에서 BFF를 호출한다"
      ]
    }
  ]
}
```

**필드 설명:**

| 필드 | 설명 |
|------|------|
| `id` | `eval-001` 형식 고유 ID |
| `description` | eval 그룹명 (= EVAL 블록의 짧은 이름) |
| `prompt` | 테스트 시나리오 (Test Input) |
| `expected_behavior` | 기대 동작 (Pass 조건) |
| `assertions` | Binary Yes/No 판별 가능한 assertion 배열 |

**eval.json 자동 생성 규칙** (`--gen-eval-only` 시):

1. Target SKILL.md/Agent.md를 읽는다
2. ERRORS.md에서 해당 Agent의 실패 패턴을 추출한다
3. LEARNINGS.md에서 교정 패턴 (Count 2+)을 추출한다
4. `templates/{agent}-evals.md`가 있으면 참조한다
5. 5개 카테고리에서 assertions 생성:
   - **구조**: 필수 출력 섹션, 파일 구조
   - **빌드**: 컴파일/타입 에러 없음
   - **규칙 준수**: CLAUDE.md 규칙 위반 없음
   - **교정 회피**: 과거 교정 패턴 미반복
   - **완전성**: Full-Stack, Scope 준수
6. `autoresearch-{name}/eval.json`으로 저장

**eval.json은 실험 중 수정 금지** — 테스트 기준은 고정해야 인과관계 추적 가능.

---

## Phase 3: 대시보드 생성

실험 시작 전에 `autoresearch-{name}/dashboard.html` 생성 후 브라우저 오픈.

**대시보드 기능:**
- 10초 자동 새로고침 (results.json 읽기)
- Chart.js 라인 차트: X=실험번호, Y=pass rate %
- 실험별 컬러 바: 초록=Keep, 빨강=Discard, 파랑=Baseline
- eval별 breakdown: 어떤 eval이 가장 많이/적게 통과하는지
- 현재 상태: "Running experiment [N]..." / "Complete"

**CORS 방지 (필수):** `file://` 프로토콜에서 `fetch()` 차단 방지를 위해 **results.json 인라인 삽입**:
```javascript
// dashboard.html 내부 — results.json 내용을 INLINE_DATA 상수로 삽입
const INLINE_DATA = { /* results.json 전체 내용 */ };

async function loadData() {
  try {
    const resp = await fetch('results.json?' + Date.now());
    const data = await resp.json();
    render(data);
  } catch (e) {
    // file:// CORS fallback
    if (INLINE_DATA) render(INLINE_DATA);
  }
}
```
- 매 실험 결과 갱신 시 `INLINE_DATA`도 함께 업데이트
- HTTP 서버 환경에서는 fetch 우선, `file://`에서는 인라인 자동 fallback

```bash
open autoresearch-{name}/dashboard.html
```

---

## Phase 4: Baseline 측정 (Experiment #0)

1. 워킹 디렉토리: `autoresearch-{name}/` 생성
2. `results.tsv` + `results.json` 초기화
3. 원본 백업: `SKILL.md.baseline` (또는 `{agent}.md.baseline`)
4. 대상 스킬/Agent를 N회 실행
5. 모든 출력을 모든 eval로 채점
6. Baseline 점수 기록

**결과 확인:** Baseline 90%+ 이면 사용자에게 "이미 높은 점수입니다. 계속할까요?" 확인

---

## Phase 5: Squad 병렬 실험 루프 (기본 모드)

> Solo 순차 실험 대신 **Squad 병렬 실험이 기본**. 2~3개 가설을 동시 검증하여 수렴 2~3x 가속.

### Squad 편성

```
autoresearch-squad-{name}-{YYYYMMDD}

┌─ Lead (Opus, Main Thread) ──────────────────────────────┐
│  역할: 실패 분석 → 가설 도출 → 판정 → changelog 관리    │
│  도구: Read, Write, Edit, Bash, results.tsv 관리         │
└──────────────────────────────────────────────────────────┘
         │ 가설 A          │ 가설 B          │ 가설 분석
         ▼                 ▼                 ▼
┌─ Mutator-1 ────┐ ┌─ Mutator-2 ────┐ ┌─ Codex ──────────┐
│ isolation:      │ │ isolation:      │ │ subagent_type:   │
│   worktree      │ │   worktree      │ │   codex-delegate │
│ 가설 A 적용     │ │ 가설 B 적용     │ │ 실패 패턴 분석   │
│ → 스킬 실행 ×N │ │ → 스킬 실행 ×N │ │ → 가설 C 제안    │
│ → eval 채점    │ │ → eval 채점    │ │ (세컨드 오피니언) │
│ → 점수 반환    │ │ → 점수 반환    │ │ → 점수 반환      │
└────────────────┘ └────────────────┘ └──────────────────┘
         │                 │                 │
         └────────┬────────┘                 │
                  ▼                          ▼
┌─ Lead: 판정 ───────────────────────────────────────────┐
│  최고 점수 mutation → KEEP (새 baseline)                │
│  나머지 → DISCARD + worktree 정리                       │
│  Codex 가설이 최고이면 → Lead가 직접 적용 후 재검증     │
│  results.tsv + changelog.md 갱신                        │
│  → 다음 iteration REPEAT                               │
└─────────────────────────────────────────────────────────┘
```

### 실험 루프 상세

```
LOOP (iteration N):
  1. Lead: 실패 분석 — 어떤 eval이 가장 많이 실패하는가?
  2. Lead: 가설 2~3개 수립 (각각 ONE thing to change)
  3. 병렬 실행:
     - Mutator-1 (worktree): 가설 A 적용 → 스킬 ×N회 → eval 채점
     - Mutator-2 (worktree): 가설 B 적용 → 스킬 ×N회 → eval 채점
     - Codex: 실패 출력 분석 → 가설 C 제안 + 근거
  4. Lead: 판정
     - 최고 점수 > baseline → KEEP (새 baseline)
     - 모든 가설 ≤ baseline → 전부 DISCARD
     - Codex 가설이 유망하면 → 다음 iteration에 Mutator가 검증
  5. Lead: results.tsv + results.json + changelog.md 갱신
  6. REPEAT
```

### Worktree 머지 프로토콜

```
Mutator-1 KEEP 판정 → Lead:
  git merge mutator-1-branch --no-ff
  pnpm tsc --noEmit (sanity check)
  Mutator-2 worktree 정리

Mutator-2 KEEP 판정 → Lead:
  git merge mutator-2-branch --no-ff
  Mutator-1 worktree 정리
```

### 노이즈 방지

- LLM Agent는 같은 프롬프트에도 다른 결과 → **최소 3회 실행의 중앙값으로 판정**
- epsilon band (+-2%) 이내 변화는 무시 (noise vs signal 구분)
- 각 Mutator가 독립 3회 실행하므로 총 6회 데이터로 판정 (신뢰도 향상)

### Good Mutations

- 가장 많이 실패하는 eval을 위한 구체적 지시 추가
- 모호한 표현을 명시적으로 변경
- 반복 실수에 대한 안티패턴 추가 ("DO NOT X")
- 중요한 지시를 프롬프트 상단으로 이동 (priority = position)
- 올바른 출력을 보여주는 예시 추가/개선
- 한 eval에만 과최적화된 지시 제거

### Bad Mutations (금지)

- 전체 재작성
- 한 번에 10개 규칙 추가
- "더 잘 해" 같은 모호한 지시
- 이유 없이 프롬프트 길이만 늘리기

### 종료 조건

- 사용자 수동 중단
- Budget cap 도달
- 95%+ pass rate 3연속 (수확 체감)
- Lead 판단: 3 iteration 연속 모든 가설 DISCARD (수렴 완료)

### 아이디어 고갈 시

- Codex에게 "지금까지 시도한 mutation과 결과를 보고, 새 접근법 제안" 위임
- 이전의 near-miss mutation 두 개 조합
- 완전히 다른 접근법 시도
- **추가보다 제거** — 단순화하면서 점수 유지도 승리

---

## Phase 6: Changelog 기록

매 실험 후 `changelog.md`에 추가:

```markdown
## Experiment [N] — [keep/discard]

**Score:** [X]/[max] ([percent]%)
**Change:** [변경 내용 1문장]
**Reasoning:** [이 변경이 도움이 될 것으로 예상한 이유]
**Result:** [어떤 eval이 개선/악화되었는지]
**Remaining:** [아직 실패하는 패턴]
```

---

## Phase 7: 결과 전달

루프 종료 시 보고:

1. **Score Summary:** Baseline → Final (% 개선)
2. **Total Experiments:** 시도된 mutation 수
3. **Keep Rate:** Keep vs Discard 비율
4. **Top 3 Changes:** 가장 효과적이었던 변경
5. **Remaining Failures:** 아직 해결되지 않은 패턴
6. **Improved File:** 이미 저장 완료
7. **Artifacts Location:** results.tsv, changelog.md 경로

---

## 산출물

```
autoresearch-{name}/
├── eval.json            # Binary eval 정의 (기계 파싱 가능, 실험 중 수정 금지)
├── dashboard.html       # 실시간 브라우저 대시보드
├── results.json         # 대시보드 데이터
├── results.tsv          # 전체 실험 점수 로그
├── changelog.md         # 실험별 변경/결과 상세
└── {name}.md.baseline   # 원본 백업
```

+ 개선된 SKILL.md (원래 위치에 덮어쓰기)

### git 연동 (autoimprove-cc 패턴)

```bash
# 점수 향상 → commit
git add {target_file}
git commit -m "autoresearch: score 60% → 75% (iter 3)"

# 점수 동일/하락 → rollback
git checkout -- {target_file}
```

- `--dry-run` 시 git 명령 실행 금지
- worktree 모드에서는 branch 단위로 keep/discard (merge vs delete)

---

## Learning Loop 연동

### ERRORS.md → Eval 자동 생성

Agent의 과거 에러 패턴에서 eval을 역으로 생성할 수 있다:

```
ERRORS.md: "code-writer가 빌드 실패 3회"
→ EVAL: "생성된 코드가 pnpm tsc --noEmit 통과하는가?" (Yes/No)

LEARNINGS.md: "사용자가 BFF 패턴 누락 교정 4회"
→ EVAL: "API 추가 시 BFF route가 함께 생성되었는가?" (Yes/No)
```

### Eval 결과 → LEARNINGS.md 환류

실험에서 발견된 새 패턴을 Learning Loop에 기록:

```bash
# 실험에서 발견된 새 실패 패턴
echo "## [$(date)] autoresearch 발견" >> .claude/learnings/IMPROVEMENTS.md
echo "- Agent: {name}" >> .claude/learnings/IMPROVEMENTS.md
echo "- Pattern: {실패 패턴}" >> .claude/learnings/IMPROVEMENTS.md
echo "- Fix: {적용된 mutation}" >> .claude/learnings/IMPROVEMENTS.md
```

---

## Agent 우선순위 (권장)

| 우선순위 | Agent | 이유 | 권장 Eval |
|:--------:|-------|------|-----------|
| 1 | code-writer | 가장 많이 사용, ERRORS.md 최다 | 빌드 통과, BFF 포함, 교정 없음 |
| 2 | error-fixer | 첫 시도 성공률이 중요 | 1회 수정으로 해결, revert 없음 |
| 3 | story-creator | 이미 구현된 기능 누락이 빈번 | 코드 검증 포함, AC 완전성 |
| 4 | task-planner | Task 품질이 구현 품질 결정 | 순환 의존성 없음, AC 구체적 |
| 5 | epic-creator | 스코프 과대/과소가 반복 | YAGNI 준수, Story 수 적절 |

각 Agent의 eval 템플릿은 `templates/` 참조.

---

## 자동 스케줄링 (Nightly / Continuous)

> 비용 무제한 환경에서는 **주기적으로 자동 실행**하여 Agent 품질을 지속 개선할 수 있다.

### Nightly 모드 (권장)

```bash
# 매일 새벽 Agent TOP 5를 순차 최적화
/loop 24h "/autoresearch code-writer --max-loops 10 && /autoresearch error-fixer --max-loops 10 && /autoresearch story-creator --max-loops 10"
```

### Continuous 모드 (비용 무제한)

```bash
# Agent 5개를 무한 순환 최적화
/loop 2h "/autoresearch code-writer --max-loops 5"
/loop 2h "/autoresearch error-fixer --max-loops 5"  # 30분 offset
```

### 자동 스케줄링 워크플로우

```
Nightly (새벽 2시)
    ↓
[Agent 1: code-writer] ──→ eval.json 채점 → 가설 병렬 → keep/discard ×10
    ↓ 완료
[Agent 2: error-fixer] ──→ eval.json 채점 → 가설 병렬 → keep/discard ×10
    ↓ 완료
[Agent 3: story-creator] → eval.json 채점 → 가설 병렬 → keep/discard ×10
    ↓ 완료
dashboard.html 종합 업데이트 → Slack/Teams 알림 (선택)
    ↓
아침에 개선된 Agent 프롬프트로 작업 시작
```

### Safety Guard

- **eval.json 고정** — 자동 실행 중 eval 기준 변경 금지 (Goodhart 방지)
- **git branch 격리** — `autoresearch/{agent}/{date}` 브랜치에서 실행, main에 자동 머지는 사용자 승인 후
- **regression gate** — 이전 최고 점수보다 5% 이상 하락 시 자동 중단 + 알림
- **max-loops 상한** — 무한 루프 방지 (기본 20, nightly는 10 권장)

---

## `/loop` 연동

> `/loop`는 Squad 루프 **밖에서 Lead의 stall 감시자**로만 사용한다.

```bash
# Squad 기반 autoresearch 실행
/autoresearch code-writer

# /loop으로 Squad heartbeat 감시 (선택)
/loop 3m "autoresearch Squad 진행상황 확인 + Mutator stall 감지"
```

---

## Squad Quality Gate 연동

quality-squad의 판정을 binary eval로 공식화:

```
# quality-squad에서 사용할 표준 eval set
EVAL 1: 빌드 통과 — pnpm build && pnpm tsc --noEmit 성공하는가?
EVAL 2: AC 달성 — Task의 모든 Acceptance Criteria가 충족되었는가?
EVAL 3: 범위 준수 — git diff --name-only가 Task 명시 파일만 포함하는가?
EVAL 4: BFF 완전성 — feat 커밋에 Backend+BFF+Frontend가 모두 있는가?
EVAL 5: 보안 — OWASP Top 10 위반이 없는가?
```

이 eval set을 quality-squad Lead가 자동으로 체크하면 주관적 판단 → 정량 판정으로 전환.

---

## 관련 스킬 & 파일

- `/learning-insights` — 학습 현황 대시보드
- `/compound` — 솔루션 문서화
- `/diagnose` — 버그 진단
- `/tdd-fix` — 테스트 기반 수정 루프 (autoresearch와 유사한 자율 루프 패턴)
- `.claude/learnings/eval-framework.md` — 기존 Learning Eval Framework (사후 평가 축, autoresearch는 사전 평가 축)

---

## Phase 8: 런타임 Eval (정적 분석 포화 시 자동 전환)

> WHY: 정적 분석(프롬프트에 규칙이 명시되어 있는가)은 100%에 도달하면 더 이상 개선 불가.
> 런타임 eval은 **실제 Agent를 실행**하고 출력을 채점하여 "규칙이 있는가" → "규칙을 지키는가"로 진화.

### 전환 조건

정적 분석 100% 달성 + 3 iteration 연속 변화 없음 → 자동으로 런타임 eval Phase 진입

### eval.json 런타임 확장 형식

```json
{
  "id": "runtime-001",
  "type": "runtime",
  "description": "BFF Route 생성 검증",
  "setup": {
    "task_file": "tests/fixtures/autoresearch/add-api-endpoint.md",
    "working_dir": "autoresearch-{name}/runtime-sandbox"
  },
  "execution": {
    "agent_type": "04-implementation/code-writer",
    "prompt": "Task 파일을 읽고 구현하세요: {task_file}",
    "timeout_ms": 300000,
    "isolation": "worktree"
  },
  "assertions": [
    {
      "type": "file_exists",
      "path": "apps/*/app/api/**/*.ts",
      "description": "BFF Route 파일이 생성되었는가"
    },
    {
      "type": "grep_match",
      "pattern": "fetch\\(|fetchWithAuth\\(",
      "glob": "apps/*/app/**/*.tsx",
      "description": "Frontend에서 BFF를 호출하는가"
    },
    {
      "type": "command_pass",
      "command": "pnpm tsc --noEmit",
      "description": "TypeScript 빌드가 통과하는가"
    },
    {
      "type": "no_pattern",
      "pattern": "public\\.",
      "glob": "**/*.sql",
      "description": "public schema를 사용하지 않는가"
    }
  ]
}
```

### Assertion 유형

| type | 설명 | Pass 조건 |
|------|------|-----------|
| `file_exists` | glob 패턴으로 파일 존재 확인 | 1개+ 매칭 |
| `grep_match` | 파일 내 패턴 존재 확인 | 1개+ 매칭 |
| `no_pattern` | 금지 패턴 부재 확인 | 0개 매칭 |
| `command_pass` | 명령 실행 결과 확인 | exit code 0 |
| `file_count` | 변경 파일 수 범위 확인 | min ≤ count ≤ max |
| `diff_scope` | git diff가 Task 범위 내인지 | 범위 외 파일 0개 |

### 런타임 실행 워크플로우

```
1. worktree 생성 (격리 환경)
2. Task fixture 파일 복사
3. Agent 실행 (timeout 내)
4. Agent 완료 후 assertions 자동 채점
5. worktree 정리
6. 점수 → results.json 갱신
```

### Task Fixture 디렉토리

```
tests/fixtures/autoresearch/
├── add-api-endpoint.md          # feat: API 추가 시나리오
├── fix-type-error.md            # fix: 타입 에러 수정 시나리오
├── add-field-fullstack.md       # feat: BE+BFF+FE 필드 추가
├── refactor-component.md        # refactor: 컴포넌트 리팩토링
└── README.md                    # fixture 작성 가이드
```

### 비용 제어

- 런타임 eval은 실제 Agent 실행 → 정적 분석 대비 **10~50x 비용**
- `--max-runtime-loops 3` (기본): 런타임 실험 최대 3회
- 정적 100% + 런타임 90%+ → 최적 수준으로 판정
- 런타임 실패 시 정적 분석 결과는 보존 (rollback 없음)

---

## 리스크 & 보완 (Codex 리뷰)

| 리스크 | 설명 | 보완 |
|--------|------|------|
| Eval 유지보수 비용 | 44 Agent × N eval = 관리 폭발 | 상위 5개만 시작, ROI 검증 후 확장 |
| Goodhart 문제 | Agent가 eval을 우회하는 방법 학습 | eval harness를 Agent 수정 불가 영역에 격리 |
| 노이즈 | 같은 프롬프트에 다른 결과 | 최소 3회 중앙값 + epsilon band |
| Squad 충돌 | quality-squad의 주관적 판단과 겹침 | binary eval을 Squad의 한 gate로 통합 |

## 권장 실행 순서

```
Phase 1 (1일): eval-framework.md 4개 지표 자동 측정 스크립트
Phase 2 (2일): code-writer eval 10개 + autoresearch 루프 MVP
Phase 3 (1일): LEARNINGS.md → eval case 자동 변환 Hook
Phase 4 (필요시): 나머지 Agent + ai-agent 채팅 Tier 1
```

---

## 성공 기준

1. Baseline 측정 없이 변경하지 않았는가?
2. Binary eval만 사용했는가?
3. 한 번에 한 가지만 변경했는가?
4. 모든 실험을 기록했는가?
5. 점수가 실제로 향상되었는가?
6. 오버피팅하지 않았는가? (테스트 통과 ≠ 실제 품질 향상)
7. 자율적으로 실행했는가? (매 실험마다 사용자에게 묻지 않음)
