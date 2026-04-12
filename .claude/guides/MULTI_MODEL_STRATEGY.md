# Multi-Model Strategy Guide

> Squad에서 Claude/Codex/Gemini를 적재적소에 활용하는 전략

## WHY

단일 모델은 모든 영역에서 최선이 아니다. 각 모델의 강점을 살려 역할을 배정하면
분석 품질과 다양한 관점을 확보할 수 있다.

## 활성화 조건

**기본값: 항상 활성화.** 모든 Squad에 Codex/Gemini가 자동 참여한다.

비활성화 키워드 (사용자 명시 시에만):
```
"solo만" / "claude만" / "단독" / "혼자" → Codex/Gemini 제외, Claude-only Squad
```

Solo 모드(팀 없음)는 Code-Change minor(1-4줄)이거나 사용자 "solo만" 명시 시에만 적용.

---

## 모델별 강점 매핑 (참고 기준)

> 아래는 경향성이며 절대 규칙이 아니다. Lead가 작업 특성에 맞게 판단한다.

| 영역 | 1순위 | 2순위 | 근거 |
|------|-------|-------|------|
| **계획/설계/아키텍처** | Claude (Opus) | Gemini Pro | 구조적 사고 + 코드베이스 직접 접근 |
| **UI/UX 시각 분석** | Gemini | Claude | 멀티모달 이미지 이해 강점 |
| **대규모 코드 분석** | Gemini Pro | Claude | 100만 토큰 컨텍스트 → 전체 모듈 한번에 분석 |
| **깊은 코드 디버깅** | Codex (GPT 5.4) | Gemini/Claude | 코드 추론 + 1M context |
| **웹 리서치/최신 정보** | Codex (web_search) | Gemini | 실시간 웹 검색 기능 |
| **코드 생성/편집** | Claude | Codex | 코드베이스 직접 접근 + 파일 편집 가능 |
| **크로스 검증/세컨드 오피니언** | 어떤 조합이든 | - | 다른 모델이 놓친 관점 발견 |

> **참고**: 세 모델 모두 코드 분석이 가능하다. 위 표는 "상대적 강점"이지 "이것만 가능"이 아니다.
> Lead는 작업 특성에 맞게 유연하게 배치한다.

---

## Per-Phase Model Config (agtx 패턴)

> agtx의 `[agents]` 섹션 영감: Phase별로 최적 모델을 YAML로 선언

### Squad YAML에서 설정

```yaml
# .claude/squads/templates/epic-squad.yaml
phase_overrides:
  analysis:
    model: gemini          # 대규모 코드 분석 (100만 토큰)
  planning:
    model: claude-opus     # 구조적 설계
  implementation:
    model: claude-opus     # 코드 생성 + 편집
  review:
    model: codex           # 코드 추론 검증
```

### 동작 방식

1. `+multi-model` 활성화 시에만 `phase_overrides` 참조
2. 비활성화 시 모든 Phase가 기본 Claude로 동작
3. Lead가 Phase 전이 시 해당 model로 Agent 자동 선택
4. 특정 Phase의 override를 생략하면 기본 Claude 사용

### Agent Tool `model` 파라미터 (v2.1.72+ 복원)

> 2.1.72에서 per-invocation model override가 복원됨.
> Squad YAML의 `spawn_options.model`과 별개로, Agent 호출 시 동적으로 모델 지정 가능.

```
Task(
  subagent_type: "04-implementation/code-writer",
  model: "haiku",   # per-invocation 모델 오버라이드
  prompt: "..."
)
```

| 우선순위 | 소스 | 예시 |
|---------|------|------|
| 1 (최우선) | Agent Tool `model` 파라미터 | `model: "haiku"` |
| 2 | Agent frontmatter `model` | `.claude/agents/*.md` |
| 3 (기본) | 부모 상속 | Lead의 모델 |

Squad Lead는 작업 특성에 따라 `model` 파라미터로 Agent별 최적 모델을 선택할 수 있다.

### agtx와의 비교

| 항목 | agtx | mcp-orch |
|------|------|---------|
| 설정 형식 | config.toml `[agents]` | Squad YAML `phase_overrides` |
| Agent 전환 | tmux 윈도우 내 프로세스 교체 | subagent_type 변경 |
| 적용 범위 | 글로벌 (모든 Task) | Squad 템플릿별 (유연) |
| 실행 방식 | 순차 (1 task, N phases) | 병렬 가능 (N tasks, N agents) |

---

## Squad 유형별 멀티모델 배치

### EPIC Squad (+multi-model) — 적극 배치

```
architect (Claude)         — 아키텍처 설계, Task 분배 (Lead)
dev-1 (Claude)             — 메인 구현 (코드베이스 직접 접근)
dev-2 (Claude)             — 보조 구현
reviewer (Claude)          — 코드 리뷰 (최종 판정)
codex-analyst (Codex)      — 깊은 코드 분석, 엣지케이스 발견
codex-reviewer (Codex)     — 구현 결과 독립 리뷰 (reviewer와 교차 검증)
gemini-analyzer (Gemini)   — 대규모 코드 영향도 분석 (100만 토큰 활용)
```

### STORY Squad (+multi-model) — 적극 배치

```
tech-lead (Claude)         — Story 분석, 구현 방향 (Lead)
dev (Claude)               — 구현
codex-verifier (Codex)     — 구현 후 로직 검증, 엣지케이스
gemini-context (Gemini)    — 관련 코드 넓은 범위 분석
```

### BUG_CRITICAL Squad (+multi-model) — 적극 배치

```
investigator-1 (Claude)    — 코드베이스 탐색, 흐름 추적 (Lead)
investigator-2 (Codex)     — 독립적 근본 원인 분석 (교차 검증)
gemini-tracer (Gemini)     — 넓은 범위 코드 흐름 추적, 관련 파일 탐색
```

### UX Squad (+multi-model) — 적극 배치

```
ux-analyst (Claude)        — 기존 UX 분석 파이프라인 (Lead)
gemini-visual (Gemini)     — 스크린샷/UI 시각 분석, 접근성 검토
codex-ux-logic (Codex)     — UX 관련 프론트엔드 로직 검증
ui-dev (Claude)            — 구현
verifier (Claude)          — 검증
```

### PLANNING Squad (+multi-model) — 적극 배치

```
planner (Claude)           — 종합 기획 (Lead, 최종 결정권)
code-scanner (Claude)      — 기존 구현 전수 검사
codex-reviewer (Codex)     — 기획안의 기술적 실현 가능성 검증
gemini-scope (Gemini)      — 대규모 코드베이스 범위 분석, 누락 기능 탐지
ux-advisor (Claude)        — UX AC 보강 (조건부)
```

### ANALYSIS Squad (+multi-model) — 적극 배치

```
coordinator (Claude)       — 디스패치, 종합 보고 (Lead)
structure-analyzer (Claude) — 의존성, 아키텍처
codex-deep-analysis (Codex) — 복잡한 로직 흐름 분석
gemini-full-scan (Gemini)  — 전체 모듈 한번에 분석 (100만 토큰)
quality-inspector (Claude) — 복잡도, 보안, 기술 부채
```

### DESIGN Squad (+multi-model) — 적극 배치

```
architect (Claude)         — Task 분해, 종합 확정 (Lead)
task-validator (Claude)    — AC 커버리지, 의존성 검증
codex-flow (Codex)         — 실행 흐름 완전성, 엣지케이스 발견
gemini-scope (Gemini)      — 설계 범위 누락 탐지
```

### QUALITY Squad (+multi-model) — 적극 배치

```
quality-lead (Claude)      — 디스패치, 종합 판정 (Lead)
impl-validator (Claude)    — AC 달성 검증
codex-deep-check (Codex)   — 깊은 로직 오류, 엣지케이스 분석
codex-security (Codex)     — OWASP Top 10 보안 검증
gemini-visual (Gemini)     — UI 결과물 시각 검증
gemini-perf (Gemini)       — 대규모 코드 성능 패턴 분석
```

### DB Squad (+multi-model) — 적극 배치

```
db-architect (Claude)      — 스키마 설계, 마이그레이션 (Lead)
db-dev (Claude)            — 구현
codex-query (Codex)        — 쿼리 최적화, N+1 탐지
gemini-schema (Gemini)     — 전체 스키마 영향도 분석
```

### DEBATE Squad (기존 패턴 확장)

```
moderator (Claude)         — 중재, 합의 도출
debater-claude (Claude)    — Claude 관점
debater-codex (Codex)      — Codex 관점
debater-gemini (Gemini)    — Gemini 관점 (3자 토론)
```

---

## Solo 모드에서도 적극 활용

Solo 모드(Squad 미편성)라도 Codex/Gemini를 **세컨드 오피니언**으로 적극 활용한다.

| 상황 | 활용 방법 |
|------|----------|
| 버그 진단 | Codex delegate Task — 독립적 근본 원인 분석 |
| 설계 결정 | Gemini delegate Task — 대안 아키텍처 제안 |
| 코드 리뷰 | Codex delegate Task — 엣지케이스/보안 검토 |
| 복잡한 로직 | Codex + Gemini 병렬 Task 후 Claude 종합 |
| UI/UX 판단 | Gemini delegate Task — 시각적 분석 의견 |

> **무제한이므로**: "필요할 때만"이 아니라 "가능하면 항상" 호출한다.
> 외부 모델 호출 비용 = 0이므로, 품질 향상 가능성이 조금이라도 있으면 호출한다.

---

## 실행 방법

### Codex 위임 (Task 도구)

```
Task(
  subagent_type: "99-utils/codex-delegate",
  name: "codex-analyst",
  team_name: "{squad-name}",
  prompt: "분석할 내용..."
)
```

### Gemini 위임 (Task 도구)

```
Task(
  subagent_type: "99-utils/gemini-delegate",
  name: "gemini-visual",
  team_name: "{squad-name}",
  prompt: "분석할 내용..."
)
```

### 빠른 세컨드 오피니언 (Squad 없이)

Squad 편성 없이 빠른 교차 검증이 필요할 때 delegate Task 사용:

```
Task(subagent_type: "99-utils/codex-delegate", prompt: "분석할 내용...")
Task(subagent_type: "99-utils/gemini-delegate", prompt: "분석할 내용...")
```

---

## Lead의 판단 기준

멀티모델 활성화 시 Lead가 결정해야 하는 것:

1. **어떤 역할에 외부 모델을 배치할까?**
   - 위 매핑표를 참고하되, 작업 특성에 맞게 판단
   - 불확실하면 Claude로 통일 (안전한 기본값)

2. **몇 명을 외부 모델로 배치할까?**
   - **기본: 최대한 많이** (Codex/Gemini 무제한 — 비용 제약 없음)
   - 모든 분석/검증 역할에 Codex 또는 Gemini 병렬 배치 권장
   - Claude-only 역할은 코드 편집이 필요한 경우만 (Lead, dev)

3. **언제 외부 모델 결과를 우선할까?**
   - 해당 모델의 강점 영역일 때
   - Claude가 놓친 관점을 발견했을 때
   - 논거의 구체성과 근거 강도 기준
   - **적극 채택**: 무제한이므로 "일단 돌려보고 판단" 전략 적극 활용

---

## Effort 관리 (v2.1.68+)

> Opus 4.6은 medium effort가 기본값. Deep thinking이 필요한 역할은 명시적으로 effort를 지정해야 한다.

| 역할 | 권장 Effort | 이유 |
|------|:----------:|------|
| architect, quality-lead | `ultrathink` 키워드 | 아키텍처 설계, 품질 판정에 deep thinking 필수 |
| planner, coordinator | `ultrathink` 키워드 | 종합 분석, 전략 수립 |
| dev, ui-dev | medium (기본값) | 구현은 medium으로 충분 |
| reviewer, verifier | `think harder` 키워드 | 리뷰에 적당한 depth |

**Squad Lead 프롬프트에 추가할 문구:**
```
이 작업은 깊은 분석이 필요합니다. ultrathink으로 신중하게 접근해주세요.
```

---

## 모델 버전 (2026-03-07 기준)

| 모델 | 현재 버전 | 비고 |
|------|----------|------|
| Claude Opus | **4.6** | 4.0/4.1 제거됨 — 자동 4.6으로 이동 |
| Claude Sonnet | **4.6** | 4.5에서 자동 마이그레이션됨 |
| Claude Haiku | **4.5** | Explore agent 기본 |
| Codex (OpenAI) | **GPT 5.4** | **1M context beta 활성화** — 대규모 코드 분석 가능 |
| Gemini Pro | **2.5** | 100만 토큰 컨텍스트 기본 |

> ⚠️ Agent frontmatter에서 `model: claude-opus-4-0` 또는 `claude-sonnet-4-5` 사용 금지.
> 명시하려면 `claude-opus-4-6`, `claude-sonnet-4-6` 사용.

### Codex 1M Context (Beta)

> **2026-03 현재**: Codex CLI에 1M context beta가 적용됨.
> 이전에는 Gemini만 대규모 컨텍스트를 지원했으나, 이제 Codex도 동등한 수준.

**활용 전략 변경점:**
- Codex도 전체 모듈/디렉토리를 한번에 분석 가능 (이전: Gemini 전용 강점)
- 대규모 코드 분석 시 Codex vs Gemini **병렬 비교** → 더 높은 정확도
- `web_search` + `1M context` 조합 → Codex가 최신 문서 + 코드 동시 분석 가능

| 작업 | 이전 전략 | 변경 전략 |
|------|----------|----------|
| 전체 모듈 분석 | Gemini 단독 | **Codex + Gemini 병렬** |
| 코드 + 문서 교차 분석 | Gemini 코드 + Codex 웹검색 | **Codex 1M(코드+문서 통합)** |
| 대규모 리팩토링 영향 분석 | Gemini 우선 | Codex/Gemini 동등 배치 |

---

## Jarvis Watch 모델 라우팅

> jarvis:watch의 각 Phase를 최적 모델에 자동 배치하여 비용 70%+ 절감

### Phase별 모델 배치표

| Phase | 작업 | 모델 | 이유 |
|-------|------|------|------|
| 1. 기술 분석 | git diff/build 체크 | **Codex** | 코드 분석 + 1M context |
| 2. PO 브레인스토밍 | 서비스별 제안 ×2 | **Gemini ×2** | 넓은 컨텍스트로 전체 코드 파악 |
| 3. Chief PO 평가 | 전략 판단 + 스코어링 | **Opus (유지)** | 최고 수준 판단력 필요 |
| 4. 자동 커밋 | 변경 분류 + 커밋 메시지 | **Sonnet** | 단순 분류 작업 |
| 5. Idea Pool | JSON CRUD | **Sonnet** | 저비용 데이터 조작 |
| 5.7. 자기개선 | 파일 패턴 분석 | **Codex** | 파일 패턴 + 중복 감지 |
| 6. TTS 브리핑 | 스크립트 포매팅 | **Sonnet** | 텍스트 생성 |
| 7. 긱뉴스 | 웹 크롤링 + 분석 | **Codex** (web_search) | 실시간 웹 검색 |

### 비용 모델

```
현재: 매 사이클 Opus 100%           = 1.0x
최적화: Opus 20% + Sonnet 30% + Codex/Gemini 50%(무료)
      = 0.2x + 0.09x + 0x          = ~0.29x (71% 절감)
```

---

## 제약 조건

- **🔴 Claude가 최종 판단자 (MANDATORY)**: Codex/Gemini의 분석 결과는 반드시 Claude가 검토하고 적합성을 판단한 후 채택한다. 병렬 실행이더라도 외부 모델 결과를 **무조건 수용하지 않는다**.
  - 외부 모델 결과 수신 → Claude가 검증 → 적합하면 채택, 부적합하면 버리거나 수정
  - 코드 수정 제안은 Claude가 `Grep`/`Read`/`find_symbol`로 **실제 코드베이스를 확인**한 후 반영 (외부 모델이 존재하지 않는 파일/함수를 언급할 수 있음)
  - 외부 모델 간 의견 충돌 시 Claude가 근거 기반으로 최종 결정
  - 외부 모델이 "~가 없다/필요하다"고 주장하면 Claude가 반드시 검증 (Verify Before Claiming 원칙 동일 적용)
- **Claude가 Lead**: 코드베이스 직접 접근, 파일 편집은 Claude만 가능
- **Codex/Gemini는 읽기 전용 기본**: `--write`/`--yolo` 명시 요청 시에만 쓰기
- **비용 무제한**: Codex/Gemini는 무제한 사용 가능. 비용 이유로 배치를 줄이지 않는다
- **적극 활용 원칙**: 분석/검증/리뷰 역할에는 반드시 Codex 또는 Gemini를 병렬 배치한다
- **타임아웃**: 외부 CLI 호출은 각 600초 제한

---

_Version: 2.3 - 2026-03-10 (v2.1.72 Agent model 파라미터 복원 + ExitWorktree + DISABLE_CRON 반영)_
