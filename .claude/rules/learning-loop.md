---
globs: [".claude/learnings/**", "docs/solutions/**"]
---

## Self-Improving Agent (Learning Loop)
> WHY: 에이전트가 같은 실수를 반복하지 않도록, 실패와 교정을 자동 기록하고 다음 작업에 참조

### Learning Loop 구조
```
작업 시작 → .claude/learnings/ 참조 (Phase 0)
    ↓
작업 수행 → 규칙적 커밋
    ↓
실패 시 → ERRORS.md 자동 기록 (Hook)
사용자 교정 시 → LEARNINGS.md 자동 기록 (Hook)
커밋 시 → CHANGELOG.md 자동 기록 (Hook)
    ↓
다음 작업 시 → 관련 학습 자동 참조
```

### 학습 파일 (.claude/learnings/)
| 파일 | 역할 | 기록 방식 |
|------|------|----------|
| `ERRORS.md` | 에이전트 실패/에러 기록 | SubagentStop Hook 자동 |
| `LEARNINGS.md` | 사용자 교정 기록 | UserPromptSubmit Hook 자동 → **에이전트가 플레이스홀더 즉시 채움** |
| `IMPROVEMENTS.md` | 개선 아이디어 | 수동 + 자동 |
| `CHANGELOG.md` | 커밋 해시 ↔ 변경 매핑 | PostToolUse(Bash) Hook 자동 |
| **`rules/auto-promoted.md`** | **반복 3회+ 자동 승격 규칙** | **self-improve-recorder Hook 자동** |

### 커밋 메시지 규칙 (에이전트 커밋 시 필수)
```
[agent:{name}] type(scope): 요약

type: feat|fix|refactor|learn|chore
scope: 변경된 주요 파일/모듈
name: code-writer|error-fixer|self-improve|main-thread 등
```
예시:
- `[agent:code-writer] feat(hooks): SubagentStop 실패 자동 기록 추가`
- `[agent:error-fixer] fix(api): BFF 프록시 타임아웃 수정`
- `[agent:main-thread] chore(learnings): 학습 구조 초기화`

### 워크플로우 확인 요청 시 (사용자 트리거)
사용자가 "워크플로우 확인해봐" 등으로 요청하면:
1. `.claude/learnings/CHANGELOG.md`에서 최근 변경 확인
2. `git log --oneline -20`으로 커밋 이력 확인
3. 의심 커밋 `git diff {hash}~1..{hash}` 비교
4. 선택적 `git revert {hash}` 또는 수정 후 개선 커밋

### Phase 0 학습 참조 (에이전트 시작 시 권장)
에이전트 시작 시 관련 학습 확인:
- `Grep "에러키워드" .claude/learnings/ERRORS.md` — 과거 실패 패턴
- `Read .claude/learnings/LEARNINGS.md` (최근 10줄) — 사용자 교정 사항

---

## Self-Correction Protocol (자기학습)
> 문서와 현실이 항상 일치하고, 같은 실수를 반복하지 않는다

| 상황 | 행동 | 기록 위치 |
|------|------|----------|
| **🔴 사용자 실수 지적** | **Mistake Feedback Loop 실행** (5Why→교훈→재작업) | `serena/memory` 또는 `docs/solutions/` |
| **🔴 사용자 UI/UX 교정** | **해당 가이드 파일 즉시 업데이트** (코드 수정 + 가이드 반영 = 세트) | `.claude/guides/UI_PATTERNS.md` 등 |
| 기술 스택 불일치 | 해당 앱 CLAUDE.md 갱신 | `apps/{app}/CLAUDE.md` |
| 가이드에 없는 패턴 | **해당 가이드 파일에 직접 추가** (노트가 아닌 가이드 우선) | `.claude/guides/{guide}.md` |
| 같은 실수 2회 | 방지 규칙 추가 | Root 또는 앱 CLAUDE.md |
| 문서 참조 누락 | Guides 섹션에 추가 | `.claude/CLAUDE.md` |
| **🔴 규칙 위반 발견** | **`/compound` 호출 필수** | `docs/solutions/{date}-{topic}.md` |
| **🔴 같은 파일 3회+ 수정** | **ref 주석 자동 추가** (아래 참조) | 해당 코드 인라인 |

### Ref 주석 규칙 (반복 수정 시 필수)
> WHY: 같은 파일을 3회+ 수정하면 다음 에이전트가 맥락을 모르고 또 돌아옴. 핵심 지점에 커밋 ref를 남기면 git log로 즉시 경위 파악 가능.

**트리거**: 같은 파일에 대해 한 세션에서 커밋 3개+ 발생
**행동**: 해당 파일의 핵심 수정 지점에 아래 형식 주석 추가

```python
# ⚠️ [주의사항 1줄]
# ref: abc1234, def5678 (YYYY-MM-DD 변경 경위 요약)
```

**예시**:
```python
# ⚠️ 토큰 주입 핵심 경로 — token_injector.py 미들웨어는 여기를 안 거침!
# ref: 5bc966d, c062dc2 (2026-03-20 OAuth audience 분리)
```

- 주석은 **compact하게 1-2줄**
- 커밋 해시는 **short hash** (7자)
- 날짜 + 변경 경위를 한 줄로 요약

규칙: 작업 완료 후 갱신 | 같은 커밋에 포함 | 노트는 3-5줄 | 앱 특화 규칙은 `apps/{app}/CLAUDE.md`에
❌ 규칙 위반을 발견하고도 `/compound` 미호출 = VIOLATION
