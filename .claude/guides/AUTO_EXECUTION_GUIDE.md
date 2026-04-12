# 자동 실행 확신도 규칙

> **핵심**: 확신도 기반 스마트 실행
> **원칙**: 확실한 작업은 자동, 불확실한 작업은 승인 후 진행

---

## 📊 자동 실행 조건 (5가지 중 4가지 충족)

### 1. 높은 확신도 (Confidence >= 90%)

**판단 기준**:
- ✅ 명확한 키워드 매칭 ("버그 수정", "API 추가", "테스트", "필드 매핑")
- ✅ 단일 도메인 (auth, api, ui, db 중 하나만)
- ✅ 이전 성공 패턴과 유사도 80%+
- ✅ 구체적인 컨텍스트 존재 (방금 해결한 버그, 특정 파일 지정)

**예시**:
```yaml
Confidence 95%:
  - "templateId 필드 매핑 누락 수정"
  - "방금 해결한 패턴을 Agent에 반영"

Confidence 50%:
  - "뭔가 이상해 고쳐줘" (모호함)
```

---

### 2. 낮은 위험도 (Risk <= Low)

**판단 기준**:
- ✅ DB 스키마 변경 없음
- ✅ 외부 API 호출 변경 없음
- ✅ 인증/권한 로직 변경 없음
- ✅ 프로덕션 데이터 영향 없음

**위험도 분류**:
```yaml
Low:
  - 단일 파일 수정
  - UI 컴포넌트 추가
  - 버그 수정 (로직만)

Medium:
  - 인증 로직 변경
  - API 스키마 변경
  - 다중 도메인 작업

High:
  - DB 스키마 대규모 변경
  - 인증 시스템 전체 교체

Critical:
  - 프로덕션 DB 마이그레이션
  - 전체 시스템 배포
```

---

### 3. 명확한 범위 (Scope: Clear)

**판단 기준**:
- ✅ 수정 파일 5개 이하
- ✅ 단일 Epic/Story 범위
- ✅ 예상 소요시간 15분 이하 (AI 기준)
- ✅ Agent 체인이 명확함 (Story → Task → Code)

**예시**:
```yaml
Scope Clear:
  - 수정: 1개 파일 (hooks.ts)
  - 소요: 5분
  - 체인: task-planner → code-writer

Scope Unclear:
  - 수정: 10개 파일 (여러 도메인)
  - 소요: 60분
  - 체인: 불명확 (Epic 필요?)
```

---

### 4. 이전 성공 패턴 (Pattern: Known)

**판단 기준**:
- ✅ 유사한 작업을 이전에 성공적으로 완료
- ✅ 동일한 Agent 체인 사용 경험
- ✅ 에러율 5% 이하

**예시**:
```yaml
Pattern Known:
  - "버그 수정" → task-planner 성공 경험 (20회+)
  - "API 추가" → story-creator 성공 경험 (15회+)

Pattern Unknown:
  - "새로운 실시간 알림 시스템" (첫 시도)
  - "WebSocket 통합" (경험 없음)
```

---

### 5. 관련성 판단 (Relatedness: HIGH) [NEW]

**현재 작업과 관련된 미구현 기능 발견 시**:

#### HIGH: 완전 자동 실행 (사용자 승인 불필요)

**조건**:
- 방금 수정한 파일/컴포넌트와 **직접 연관**
- 예: Team 페이지 버그 수정 → Team Feedback API 미구현 발견

**자동 실행**:
```yaml
체인: Epic → Story → Task → 구현 → 테스트 (완전 자동)
예외: DB 스키마 변경/인증 로직 변경 시에만 승인 요청
```

**예시**:
- Team 페이지 수정 → Template API 자동 구현 ✅
- 로그인 버그 수정 → 2FA API 자동 구현 ✅

---

#### MEDIUM: Backlog 추가 (사용자 승인 필요)

**조건**:
- 같은 도메인이지만 **다른 기능**
- 예: 로그인 수정 → 회원가입 미구현 발견

**자동 실행**:
```yaml
체인: Backlog 추가 → 사용자 승인 요청
```

---

#### LOW: Backlog 추가만 (알림 없음)

**조건**:
- **다른 도메인**의 미구현 기능
- 예: UI 수정 → DB 마이그레이션 미구현

**자동 실행**:
```yaml
체인: Backlog 추가만 (조용히)
```

---

## ✅ 자동 실행 예시

### Case 1: 버그 수정 (소형) - 즉시 실행

```yaml
User: "templateId 필드 매핑 누락 수정"

분석:
  Confidence: 95% (명확한 버그, 구체적 컨텍스트)
  Risk: Low (단일 파일 수정, API Hook 매핑만)
  Scope: Clear (1개 파일, hooks.ts)
  Pattern: Known (방금 해결한 패턴)

결론: ✅ 즉시 task-planner → code-writer 실행
```

---

### Case 2: Agent 개선 (중형) - 즉시 실행

```yaml
User: "방금 해결한 디버깅 패턴을 error-fixer Agent에 반영"

분석:
  Confidence: 95% (명확한 요청, 구체적 패턴)
  Risk: Low (Agent 스펙 파일, 코드 실행 없음)
  Scope: Clear (3개 파일)
  Pattern: Known (Agent 최적화 경험 다수)

결론: ✅ 즉시 task-planner → code-writer 실행
```

---

### Case 3: 관련 미구현 (NEW) - 완전 자동 실행

```yaml
Context: 방금 Team 페이지 버그 수정 완료
발견: Template API, Team Feedback API 미구현

분석:
  Confidence: 95% (명확한 컨텍스트)
  Risk: Low-Medium (신규 기능, 기존 패턴 재사용)
  Scope: Clear (2개 Epic, 각 2-3 Story)
  Pattern: Known (유사 CRUD 경험)
  Relatedness: HIGH (방금 수정한 코드와 직접 연관) ✅

판단:
  ✅ Relatedness HIGH → 사용자 승인 없이 완전 자동
  ✅ Epic → Story → Task → 구현 → 테스트
  ⚠️ 단, DB 스키마 변경 시에만 승인 요청

결론: ✅ 즉시 epic-creator → ... → test-creator 완전 자동 실행
```

---

### Case 4: API 추가 (중형) - 사용자 승인 필요

```yaml
User: "로그인 API에 2FA 추가"

분석:
  Confidence: 85% (명확한 기능)
  Risk: Medium (인증 로직 변경, 보안 영향) ⚠️
  Scope: Clear (auth 도메인)
  Pattern: Known (2FA 구현 경험)

결론: ⚠️ 사용자 승인 필요 (Risk >= Medium)
```

---

## ❌ 사용자 승인 필요 예시

### Case 5: 대형 프로젝트 - 승인 필요

```yaml
User: "새로운 사용자 관리 시스템"

분석:
  Confidence: 70% (모호함) ⚠️
  Risk: High (DB + Auth + UI 복합) ⚠️
  Scope: Unclear (여러 도메인) ⚠️
  Pattern: Unknown (신규 시스템) ⚠️

결론: ❌ 사용자 승인 필요
```

---

### Case 6: 모호한 요청 - 구체화 필요

```yaml
User: "뭔가 이상해, 고쳐줘"

분석:
  Confidence: 30% (모호함) ❌

결론: ❌ 사용자에게 구체적인 요청 요구
예: "어떤 파일의 어떤 기능이 이상한가요?"
```

---

### Case 7: Critical Risk - 절대 금지

```yaml
User: "프로덕션 DB 전체 마이그레이션"

분석:
  Risk: Critical (프로덕션 데이터) 🚨

결론: ❌ 절대 자동 실행 금지
→ 상세 Epic 계획 수립 → 사용자 승인 → 단계별 실행
```

---

## 📝 응답 템플릿

### 자동 실행 (Confidence >= 90% && Risk <= Low)

```markdown
[Enhanced 4-Step Workflow - AUTO-EXECUTION]

ANALYZE:
  키워드: [추출된 키워드]
  인텐트: [create/modify/debug] + [복잡도]
  확신도: 95% ✅

INJECT:
  🎯 [DOMAIN] DETECTED
  📋 Agent: [agent-name]
  ⚠️ Risk: Low ✅
  💡 Pattern: Known ✅

ROUTE:
  ✅ 자동 실행 조건 충족 (Confidence: 95%, Risk: Low)
  → [agent-name] 즉시 실행

실행 중...
```

---

### 사용자 승인 필요 (Confidence < 90% OR Risk > Low)

```markdown
[Enhanced 4-Step Workflow]

ANALYZE:
  키워드: [...]
  인텐트: [...]
  확신도: 85% ⚠️

INJECT:
  🎯 [DOMAIN] DETECTED
  📋 Agent 추천: [agent-name]
  ⚠️ Risk: Medium ⚠️
  💡 예상 구조: [workflow_preview]

ROUTE:
  - 요청 분류: [중형/대형]
  - 자동 실행: [agent-name] --hard-think --delegate

🚀 [Chain명] 워크플로우를 실행할까요?
```

---

## 🚨 Edge Case 처리

### Critical Risk 작업

```yaml
트리거 키워드:
  - "프로덕션", "배포", "전체 마이그레이션"
  - DB 스키마 대규모 변경
  - 인증 시스템 전체 교체

응답:
  ❌ 자동 실행 절대 금지
  → 상세 Epic 계획 수립
  → 사용자 승인
  → 단계별 실행
```

**예시**:
```
User: "프로덕션 DB 전체 마이그레이션"
→ ❌ 자동 실행 금지
→ Epic 계획서 작성 → 사용자 리뷰 → 승인 후 실행
```

---

### 모호한 요청

```yaml
트리거:
  - 키워드 추출 실패
  - Confidence < 50%
  - 도메인 불명확

응답:
  ❌ Agent 실행 보류
  → 사용자에게 구체적 정보 요청

예시:
  "어떤 파일의 어떤 기능을 수정하시려나요?"
  "버그가 어느 화면에서 발생하나요?"
```

---

## 💡 실전 적용 예시

### 예시 1: 버그 수정 - 즉시 실행

```yaml
User: "templateId 필드 매핑 누락 수정"

분석:
  Confidence: 95%
    - 명확한 버그
    - 구체적 컨텍스트 (방금 발견)
    - 단일 도메인 (frontend)

  Risk: Low
    - 단일 파일 수정 (hooks.ts)
    - API Hook 매핑만
    - 프로덕션 영향 없음

  Scope: Clear
    - 1개 파일
    - 5분 소요 (AI 기준)
    - 체인: task-planner → code-writer

  Pattern: Known
    - 필드 매핑 수정 경험 (10회+)
    - 에러율 0%

결론: ✅ 자동 실행 조건 충족 (4/4)
→ 즉시 task-planner → code-writer 실행
```

---

### 예시 2: Agent 개선 - 즉시 실행

```yaml
User: "방금 해결한 디버깅 패턴을 error-fixer Agent에 반영"

분석:
  Confidence: 95%
    - 명확한 요청
    - 구체적 패턴 (templateId 버그)
    - 단일 도메인 (agent)

  Risk: Low
    - Agent 스펙 파일 수정
    - 코드 실행 없음
    - 문서 업데이트만

  Scope: Clear
    - 3개 파일 (error-fixer.md, debugging-workflow.md)
    - 10분 소요
    - 체인: task-planner → code-writer

  Pattern: Known
    - Agent 최적화 경험 (agent-optimizer 사용)
    - 문서 업데이트 경험 다수

결론: ✅ 자동 실행 조건 충족 (4/4)
→ 즉시 task-planner → code-writer 실행
```

---

### 예시 3: 관련 미구현 - 완전 자동 실행 [NEW]

```yaml
Context: Team 페이지 버그 수정 완료
발견: Template API, Team Feedback API 미구현

분석:
  Confidence: 95%
    - 명확한 컨텍스트
    - 관련성 확인됨

  Risk: Low-Medium
    - 신규 기능
    - 기존 CRUD 패턴 재사용

  Scope: Clear
    - 2개 Epic, 각 2-3 Story
    - 30분 소요 (AI 기준)

  Pattern: Known
    - 유사 CRUD 구현 경험

  Relatedness: HIGH ✅ (핵심)
    - 방금 수정한 Team 페이지와 직접 연관
    - Template, Team Feedback 모두 Team 도메인

판단 로직:
  ✅ Relatedness HIGH → 사용자 승인 없이 완전 자동
  ✅ Epic → Story → Task → 구현 → 테스트
  ⚠️ 단, DB 스키마 변경 시에만 승인 요청

결론: ✅ 즉시 완전 자동 실행
→ epic-creator → story-creator → task-planner → code-writer → test-creator
```

---

### 예시 4: API 추가 - 사용자 승인 필요

```yaml
User: "로그인 API에 2FA 추가"

분석:
  Confidence: 85% (명확한 기능)
  Risk: Medium (인증 로직 변경, 보안 영향) ⚠️
  Scope: Clear (auth 도메인)
  Pattern: Known (2FA 구현 경험)

결론: ⚠️ 사용자 승인 필요 (Risk >= Medium)
→ 워크플로우 계획 설명 → 사용자 승인 → 실행
```

---

### 예시 5: 대형 프로젝트 - 승인 필요

```yaml
User: "새로운 사용자 관리 시스템"

분석:
  Confidence: 70% (모호함) ⚠️
  Risk: High (DB + Auth + UI 복합) ⚠️
  Scope: Unclear (여러 도메인) ⚠️
  Pattern: Unknown (신규 시스템) ⚠️

결론: ❌ 사용자 승인 필요 (조건 미충족 4/4)
→ Epic 계획 수립 → 사용자 승인 → 단계별 실행
```

---

## 🎯 의사결정 알고리즘

```typescript
function shouldAutoExecute(request: UserRequest): boolean {
  const confidence = analyzeConfidence(request)
  const risk = analyzeRisk(request)
  const scope = analyzeScope(request)
  const pattern = analyzePattern(request)
  const relatedness = analyzeRelatedness(request)  // NEW

  // Relatedness HIGH → 완전 자동 실행 (예외)
  if (relatedness === "HIGH" && risk !== "Critical") {
    return true  // 사용자 승인 불필요
  }

  // 일반 조건 (4가지)
  if (
    confidence >= 90 &&
    risk <= "Low" &&
    scope === "Clear" &&
    pattern === "Known"
  ) {
    return true  // 자동 실행
  }

  return false  // 사용자 승인 필요
}
```

---

## 📊 통계 및 목표

### 현재 통계 (예상)

```yaml
자동 실행율:
  - 현재: 60%
  - 목표: 80%

자동 실행 정확도:
  - 현재: 90%
  - 목표: 95%

사용자 재요청 비율:
  - 현재: 10%
  - 목표: 5%
```

### 개선 목표

```yaml
Confidence >= 90% 케이스:
  - 목표: 80% 자동 실행
  - 측정: 자동 실행 / 전체 요청

Relatedness HIGH 케이스 (NEW):
  - 목표: 100% 완전 자동 (승인 불필요)
  - 측정: 완전 자동 / Relatedness HIGH 케이스

Risk >= Medium 케이스:
  - 목표: 100% 사용자 승인
  - 측정: 승인 요청 / Risk >= Medium 케이스
```

---

## 🚨 주의사항

### 1. Relatedness HIGH 남용 방지

```yaml
위험: Relatedness HIGH를 과대평가하여 무분별 자동 실행

방지:
  - 파일/컴포넌트 직접 연관만 HIGH
  - 같은 도메인이지만 다른 기능 → MEDIUM
  - 다른 도메인 → LOW

예시:
  HIGH: Team 페이지 수정 → Team Feedback API (직접 연관)
  MEDIUM: 로그인 수정 → 회원가입 (같은 auth, 다른 기능)
  LOW: UI 수정 → DB 마이그레이션 (다른 도메인)
```

### 2. DB 스키마 변경은 항상 승인

```yaml
Relatedness HIGH여도 예외:
  - DB 스키마 변경 → 사용자 승인 필수
  - 인증 로직 변경 → 사용자 승인 필수
  - 프로덕션 배포 → 사용자 승인 필수

이유: Risk >= Medium (자동 실행 조건 위반)
```

---

## 📚 참조

**관련 가이드**:
- **워크플로우**: @.claude/guides/AUTO_WORKFLOW_GUIDE.md
- **Agent 체인**: @.claude/guides/AGENT_CHAIN_RULES.md
- **병렬 실행**: @.claude/guides/PARALLEL_EXECUTION_GUIDE.md

**프로젝트 문서**:
- **Agent 카탈로그**: @.claude/AGENT_CATALOG.md
- **Reddit Hook System**: @.claude/guides/REDDIT_HOOK_SYSTEM.md

---

**버전**: 1.0.0
**작성일**: 2025-11-18
**유지보수**: Agent 최적화 팀
