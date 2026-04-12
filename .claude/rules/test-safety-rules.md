---
globs: ["**/*.test.*", "**/*.spec.*", "**/__tests__/**"]
---

# Test Safety Rules (EP121)

> "테스트는 코드가 작동한다는 증거, 의미 없는 assertion은 거짓 안전감" - Karpathy Goal-Driven

## Core Principle

테스트는 AI Agent가 작성하는 경우가 많다. AI는 "테스트 통과"를 목표로 최소 저항 경로를 택하기 쉽다.
따라서 **테스트 자체의 품질**을 강제하는 규칙이 필요하다.

## Goal-Driven Test Design (Karpathy)

약한 AC를 강한 Goal State로 리프레이밍:

| 약한 AC | 강한 Goal State |
|---------|----------------|
| "에러 처리 추가" | "네트워크 에러 시 토스트 표시 + Retry 버튼" |
| "테스트 작성" | "정상/에러/경계값 3개 시나리오 검증" |
| "API 테스트" | "200 응답 + 필드 타입 + 404 처리 검증" |
| "성능 테스트" | "10개 렌더 < 100ms (현재 500ms)" |
| "MCP 도구 테스트" | "같은 title로 2회 호출 시 v1→v2 (중복 생성 아님)" |

### MCP 도구 AC 필수 시나리오 (Stateless Consumer 가정)
> WHY: EP194에서 "AI가 artifactId를 기억해서 재사용"을 가정 → 실제로 매번 새로 생성 (29건 중복)
> MCP 도구를 호출하는 AI 에이전트는 이전 응답을 기억하지 못한다고 가정해야 함

MCP 도구 AC 작성 시 반드시 포함:
- [ ] **Stateless 재호출**: ID 없이 같은 식별자(title, name, key)로 재호출 시 upsert 동작
- [ ] **새 세션에서 호출**: 이전 세션의 반환값 없이 호출 시 정상 동작
- [ ] **동시 호출**: 같은 도구를 빠르게 2회 호출 시 race condition 없음

## 금지 패턴 vs 권장 패턴

### Assertion

| 금지 | 권장 |
|------|------|
| `expect(true).toBe(true)` | `expect(result.status).toBe('active')` |
| `expect(1).toBe(1)` | `expect(items.length).toBe(3)` |
| `expect(false).toBe(false)` | `expect(error.message).toContain('not found')` |
| `assert True` | `assert response.status_code == 200` |
| `assert 1 == 1` | `assert len(result.items) == expected_count` |

### Test Body

| 금지 | 권장 |
|------|------|
| `it('works', () => {})` | `it('returns 3 items for valid query', () => { ... })` |
| `it('should work', () => { expect(true).toBe(true) })` | `it('should reject invalid email', () => { ... })` |

### Mock Usage

| 금지 | 권장 |
|------|------|
| mock만 있고 expect 없음 | mock 설정 + 결과값 assertion |
| `jest.fn()` 호출 확인만 | 반환값/사이드이펙트 검증 |

## DB Test Isolation

### 금지
```sql
-- TRUNCATE TABLE (다른 테스트 데이터 파괴)
-- DROP TABLE (스키마 손상)
-- DELETE FROM table (전체 삭제)
-- ROLLBACK을 격리 수단으로 사용 (트랜잭션 중첩 시 불안정)
```

### 권장: UUID Prefix 격리
```typescript
// 테스트별 고유 prefix로 데이터 격리
const testPrefix = `test_${randomUUID().slice(0, 8)}`;
const testUser = await createUser({ name: `${testPrefix}_user` });

// teardown: prefix 기반 정리
afterEach(async () => {
  await db.user.deleteMany({ where: { name: { startsWith: testPrefix } } });
});
```

### 권장: Factory Pattern
```typescript
// 재사용 가능한 테스트 데이터 팩토리
function createTestData(overrides = {}) {
  const prefix = `test_${randomUUID().slice(0, 8)}`;
  return {
    name: `${prefix}_item`,
    status: 'active',
    ...overrides,
  };
}
```

## Anthropic Test Design Principles

> "AI가 작성하는 테스트는 AI를 위해 설계되어야 한다"

1. **Deterministic**: 실행 순서에 의존하지 않음
2. **Self-contained**: 외부 상태 의존 최소화
3. **Descriptive**: 테스트 이름만으로 검증 대상 파악 가능
4. **Boundary-aware**: 정상/에러/경계값 3가지 시나리오 포함
5. **Evidence-based**: 각 assertion이 비즈니스 로직을 검증

## Hook 연동

`test-quality-checker.sh` (PostToolUse Hook)가 자동으로 감지:
- 의미 없는 assertion 패턴
- 빈 테스트 바디
- mock-only 테스트 (expect 없음)

경고만 표시하며 차단하지 않음. Agent가 경고를 보고 자체 수정하도록 유도.
