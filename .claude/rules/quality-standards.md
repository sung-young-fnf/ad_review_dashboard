---
globs: ["**"]
---

# Quality Standards (Kent Beck 철학)

> "Make the change easy, then make the easy change." - Kent Beck

## Core Principles

### KISS (Keep It Simple, Stupid)
- 단순하고 명확한 로직
- 불필요한 추상화 배제
- 직관적인 구조
- **"가장 단순한 것이 작동할 수 있는 것은 무엇인가?"**

### YAGNI (You Aren't Gonna Need It)
- 현재 필요한 기능만 구현
- 미래 대비 코드 금지
- 실제 요구사항 기반 개발
- **"내일 필요한 것은 내일 만들어라"**

### DRY (Don't Repeat Yourself)
- 기존 코드 재사용 우선
- 중복 로직 제거
- 공통 패턴 템플릿화
- **"모든 지식은 시스템 내에서 단일하고 명확한 표현을 가져야 한다"**

## Kent Beck의 추가 원칙

### Small Pieces
- 작은 단위로 분해 (각각 테스트 가능)
- 한 번에 하나의 변경만
- 점진적 개선

### Intention-Revealing
- 코드/문서가 의도를 드러내야 함
- 이름만으로 목적 파악 가능
- 주석 없이도 이해 가능한 구조

### Testable Design
- 모든 기능은 검증 가능해야 함
- 부작용 최소화
- 명확한 입출력

### Clarity over Brevity (Anthropic Code-Simplifier 원칙)
- **명확성 > 간결성** - 한 줄 축약보다 3줄 명확한 코드 선호
- 코드 골프 금지 - 읽기 쉬운 코드가 유지보수 쉬운 코드
- 디버깅/확장 용이성 우선

## Goal-Oriented Prompting
> 상세: @.claude/guides/GOAL_ORIENTED_PROMPTING.md
> 핵심: "이렇게 해(HOW)"보다 "이 상태가 되면 성공(WHAT)" — Goal / Constraint / Hint 3-Layer
> 모든 규칙에 WHY를 포함하면, 엣지 케이스에서 의도에 맞는 더 나은 판단 가능

## Industry Pattern Research First (증상 패치 금지)
> WHY: EP124→EP224 — per-task 토큰 설계 오류를 2달간 8건 fix 커밋으로 패치.
> 처음부터 업계 패턴(per-user 중앙 토큰)을 리서치했으면 1번에 해결.
> "같은 영역에서 fix 2건+" = 구조적 문제 신호 → 패치가 아니라 리서치가 필요.

### 트리거 조건
아래 중 하나라도 해당하면 **구현 전 Codex 웹 리서치 필수**:
- 인증/토큰/세션 관리 신규 설계
- 같은 영역에서 fix 커밋 2건+ 누적 (반복 패치 신호)
- 캐싱/큐/스케줄링 등 인프라 패턴 신규 도입
- "이렇게 하면 되지 않을까?" 직감 기반 설계 (검증 없는 접근)

### 리서치 프로토콜
```
1. Codex delegate (web_search) 호출
   → "How do [Zapier/Make/n8n/industry] handle [문제]?"
   → Azure/AWS/GCP 공식 문서 확인
   → RFC/보안 BCP 확인

2. 결과 요약 (3가지)
   → 업계 표준 패턴
   → 우리 접근과의 차이
   → 보안 고려사항

3. 사용자 확인 후 구현 (Pre-Flight에 포함)
```

### 반복 패치 감지 규칙
- `git log --grep="{영역}" --since="30 days"` → fix 2건+ → **STOP**
- "또 이거 고치네" 느낌 → 패치 대신 근본 원인 리서치
- ❌ 같은 영역 3번째 fix에도 리서치 없이 패치 = VIOLATION

## 코드 스타일 가드레일

### Ternary Rules (중첩 삼항 금지)
```typescript
// ❌ Bad - 중첩 삼항
const status = a ? (b ? "x" : "y") : "z";
const result = condition1 ? value1 : condition2 ? value2 : value3;

// ✅ Good - if/else 또는 switch
if (a) {
  return b ? "x" : "y";
}
return "z";

// ✅ Good - 단일 조건 삼항은 허용
const label = isActive ? "활성" : "비활성";
```

- ❌ 2단계 이상 중첩 삼항 금지
- ✅ 단일 조건 삼항 허용
- ✅ 복잡한 조건은 if/else, switch, 또는 객체 매핑 사용

## Karpathy 4 Principles (AI 코딩 실행 검증)

> "AI 코딩의 4대 실패 패턴: '생각 안 하고', '과복잡하게', '범위 밖 건드리고', '약한 목표로 종료'"
> — Andrej Karpathy (Tesla AI Director, OpenAI 창립멤버)

### 1️⃣ Think Before Coding (구현 전 불확실성 명시)

**원칙**: 코드 전에 "이게 작동하려면 뭐가 필요한가?"를 명시하면, 70% 버그 선제 방지.

**Assumption Manifesto** — 구현 전 검증:
- Data Flow: Frontend payload ↔ Backend DTO 필드 일치? (`Grep export interface`)
- API Contract: 엔드포인트 존재? 메서드 일치? (`Grep @Post|@Get|@Put|@Delete`)
- **Response Shape**: Backend 반환이 배열(`[]`)인지 wrapper(`{ items, total }`)인지? Repository 반환 타입 → Service → Controller → BFF 전체 체인 추적 필수
- **Consumer Props**: 새 컴포넌트가 전달하는 데이터 = 기존 컴포넌트가 요구하는 Props 타입? (content 필수 등 누락 방지)
- Type Safety: snake_case ↔ camelCase 매핑? (prisma.schema/models 확인)
- Permission: 권한 체크 코드 존재? (Guard/Decorator 확인)
- Consumer Alignment: Service 호출 시 **프론트엔드가 어떤 필드로 필터링/조회하는지** 확인? (Tool→Service 호출에서 context 필드 누락 방지)
- **Existing Features**: 기존에 같은 기능이 이미 있는지? (VersionSelector, ArtifactPanel 등 재사용 가능 컴포넌트 확인)
- **Live Data State**: 관련 DB 테이블에 실제 데이터가 있다면 `SELECT` 한 번으로 상태 확인 — 중복, 누락, 버전 불일치 등 기존 이슈 조기 발견 (API 구조만 보지 말고 실제 데이터 상태를 봐야 동작 이슈가 보인다)
- **Stateless Consumer**: MCP 도구/API를 호출하는 주체(AI 에이전트, cron, 외부 시스템)가 **이전 응답을 기억하지 못한다**고 가정. ID 기반 update만으로는 부족 → title/key 기반 upsert(findOrUpdate) 반드시 제공. "반환값을 기억해서 재사용할 것"은 깨지기 쉬운 가정

### 2️⃣ Simplicity First (과복잡성 자체 검증)

**원칙**: 단순성은 분량이 아니라 **인지 부하**로 측정. Complexity Red Flags 2개+ → 리팩토링:
- 조건 중첩 3단계+ → Early return + guard clauses
- 파라미터 4개+ → DTO 객체 사용
- 함수 목적 1문장 불가 → 책임 분리

구현 후 자문: "50줄로 줄일 수 있나?" / "Senior가 과복잡하다 할까?" / "3개월 후 이해 가능?"

### 3️⃣ Surgical Changes (범위 외 수정 금지)

**원칙**: Task 범위 밖 "착한 리팩토링"도 금지. Scope Lock:
- ✅ Task AC 명시 파일만 수정 / import·export 추가 / 기존 패턴 복제
- ❌ 다른 파일 구조 개선 / 컴포넌트 이름 변경 / 새 라이브러리 추가 / 요청 없는 "개선"
- 검증: `git diff --name-only` — Task 명시 파일 N개 vs 실제 M개, M > N → Scope creep 경고

### 4️⃣ Goal-Driven Execution (약한 목표 → 강한 목표)

**원칙**: AC가 약하면 검증도 약하다. Goal State 명시로 검증 자동화.
- ❌ "에러 처리 추가" / "UI 개선" / "성능 최적화"
- ✅ "네트워크 에러 시 토스트+Retry" / "10개 렌더 < 100ms" / "기존 테스트 통과+새 3개"

Self-Validation: 각 Goal 달성? → 증거 첨부 → 모두 ✅ → validator → 하나라도 ❌ → 구현 재개

## Additive-then-Subtractive Refactoring (Superset 패턴)

> "한 번에 삭제+교체 금지. 신규를 먼저 추가하고, 둘 다 통과한 후 기존을 제거한다."
> WHY: delete-then-replace는 중간에 실패하면 롤백 불가. 둘 다 공존하는 상태에서 검증하면 안전하다.

### 리팩토링 3단계 순서 (필수)
1. **Add** — 신규 코드를 기존 코드 **옆에** 추가 (기존 코드 건드리지 않음)
2. **Verify** — 기존 + 신규 둘 다 있는 상태에서 빌드/테스트 통과 확인
3. **Remove** — 기존 코드 삭제, 최종 빌드/테스트 통과 확인

### 적용 대상
- 함수/메서드 시그니처 변경
- 컴포넌트 교체 (v1 → v2)
- API 엔드포인트 마이그레이션
- DB 스키마 마이그레이션 (컬럼 추가 → 데이터 이전 → 컬럼 삭제)

### 적용 예외 (한 번에 교체 허용)
- 1-4줄 minor 수정
- 내부 private 함수 (외부 참조 없음)
- 테스트 코드만 변경

```typescript
// ❌ Bad - 한 번에 삭제+교체
// 기존 함수 삭제 → 새 함수 작성 → 빌드 실패 시 원본 복구 불가

// ✅ Good - Additive-then-Subtractive
// Step 1: 새 함수 추가 (기존 유지)
function getUserV2(id: string) { /* new implementation */ }

// Step 2: 호출부 교체 + 테스트 통과 확인
// Step 3: 기존 getUser() 삭제
```

---

## 3-Strike Rule (디버깅/수정 시 필수)
> WHY: error-fixer가 무한 루프에 빠지는 패턴 반복 — 같은 문제에 3회+ 실패하면 아키텍처 문제 의심
> Source: gstack `/investigate` Iron Law 채택 (2026-03-23)

**동일 이슈에 대해 수정 3회 실패 시 반드시 중단:**
1. 각 수정 시도를 카운트 (같은 에러/같은 파일 기준)
2. 3회 실패 → **STOP** — 사용자에게 보고:
   ```
   ⚠️ 3-Strike: 동일 이슈에 3회 수정 실패
   시도 1: [무엇을 했고 왜 실패했나]
   시도 2: [무엇을 했고 왜 실패했나]
   시도 3: [무엇을 했고 왜 실패했나]
   → 단순 버그가 아닌 아키텍처/설계 문제 가능성
   A) 계속 — 새 가설: [설명]
   B) Codex/Gemini에 위임 — 다른 관점 필요
   C) 사용자 판단 대기
   ```
3. 사용자 승인 없이 4회차 수정 시도 금지

❌ 3회 실패 후 사용자 보고 없이 계속 수정 시도 = VIOLATION
❌ "이번엔 될 것 같다" — 희망은 전략이 아님

## Scope Drift Detection (구현 완료 후 필수)
> WHY: 요청된 범위 외 "착한 리팩토링"이 scope creep 유발 — 의도와 결과 불일치 감지
> Source: gstack `/review` Step 1.5 채택 (2026-03-23)

**코드 변경 후 커밋 전에 drift 체크:**
```
git diff --name-only  # 실제 변경된 파일
vs
Task/요청에서 명시된 파일  # 의도된 범위
```

- 의도에 없는 파일이 변경됨 → **Scope Drift 경고** 출력
- 의도된 파일이 변경 안 됨 → **Missing Requirement 경고** 출력
- 형식:
  ```
  Scope Check: [CLEAN / DRIFT / MISSING]
  의도: [요청 1줄 요약]
  실제: [diff가 실제로 한 것 1줄]
  [Drift: 범위 밖 변경 파일 목록]
  [Missing: 미변경 필수 파일 목록]
  ```
- INFORMATIONAL — 블로킹 아님, 인지 목적

## Verification Gate (완료 주장 전 필수)
> WHY: "should work" / "이제 될 것 같다"가 가장 위험한 말 — 증거 없는 완료 주장 금지
> Source: gstack `/ship` Step 6.5 + Karpathy Goal-Driven 강화 (2026-03-23)

**코드 변경 후 "완료" 주장 전 필수 증거:**
1. **빌드 증거**: `pnpm tsc --noEmit` 또는 `pnpm build` 출력 결과
2. **테스트 증거**: 관련 테스트 실행 결과 (있는 경우)
3. **변경 후 재검증**: Step 3에서 테스트 통과했어도 이후 코드가 변경되면 **재실행 필수**

**합리화 방지 (Rationalization Prevention):**
- "이제 될 것 같다" → **실행해라**
- "확신한다" → 확신은 증거가 아니다
- "아까 테스트했다" → 그 후 코드가 바뀌었다. 다시 테스트해라
- "사소한 변경이다" → 사소한 변경이 프로덕션을 깨뜨린다

❌ 빌드/테스트 증거 없이 "완료" 보고 = VIOLATION
❌ 코드 변경 후 이전 테스트 결과를 재사용 = VIOLATION

---

### Karpathy 체크리스트 (code-writer 사용)
구현 전: Assumption Manifesto 작성 / Grep 검증 / Scope Lock 정의
구현 후: Complexity Red Flag 0개 / 수정 파일 = Task 명시 파일 / Goal State 모두 달성

## Critical Warnings

```typescript
// ❌ useEffect(() => {...}, [api.method, data])  // 객체 의존성 = 무한 렌더
// ✅ useEffect(() => {...}, [userId, teamId])    // primitive만

// ❌ useCallback(() => { doSomething(state) }, [])  // stale closure!
// ✅ useCallback(() => { doSomething(state) }, [state])
```
- ❌ `public` schema 금지 → ✅ `{schema}.table_name`
- `pnpm prisma generate` — 타입에러 100+ 시
- ❌ 인증 필요한 페이지에 브라우저 자동 접근 시도 금지
- ✅ UI 변경 확인은 코드 레벨 검증 또는 사용자에게 수동 확인 위임
- ❌ 스크린샷 촬영을 위한 새 탭 열기 + 로그인 시도 = VIOLATION
- UI 수정 전 Route→Page→Component 하향식 추적 필수 (렌더링 여부 확인)
- ❌ 컴포넌트 이름만 보고 바로 수정 = VIOLATION (렌더링 여부 미확인)
- 로그 조사: 좁은 범위(서비스명+15분)로 시작, 3회 시도 후 중간 보고 필수
- ❌ 시간대 1시간+ 넓은 쿼리로 시작 = VIOLATION
- ❌ 5회+ 쿼리 반복하며 사용자 미보고 = VIOLATION
