---
name: test-creator
description: "Task AC(Given-When-Then)를 테스트 stub으로 자동 변환"
effort: medium
---

# AC-to-Test Auto Conversion Skill

> Task AC(Given-When-Then)를 테스트 stub으로 자동 변환

## WHY

code-writer가 AC 달성을 "주관적 판단"이 아닌 "테스트 pass/fail"로 결정론적으로 검증.
구현 전 fail 상태 stub을 먼저 만들고, 구현 완료 시 모두 pass 해야 AC 달성.

## 사용법

code-writer Phase 1.5에서 자동 실행. 별도 호출 불필요.

## AC 파싱 규칙

### 입력 형식 (Task 파일)
```markdown
### AC-{N}: {제목}
- Given: {전제조건}
- When: {실행조건}
- Then: {기대결과}
- And: {추가 기대결과}
```

### 파싱 전략
1. `### AC-` 또는 `AC-{N}:` 패턴으로 AC 블록 식별
2. `Given:` / `When:` / `Then:` / `And:` 라인 추출
3. AC별 1개 테스트 케이스 생성

## 테스트 stub 생성 규칙

### 서비스별 프레임워크

| 서비스 | 프레임워크 | 파일 패턴 | 위치 |
|--------|-----------|----------|------|
| AI-Agent Backend | jest | `{feature}.ac.spec.ts` | `src/{module}/__tests__/` |
| AI-Agent Frontend | vitest/jest | `{component}.ac.test.tsx` | 컴포넌트 옆 |
| MCP-Orbit Backend | pytest | `test_{feature}_ac.py` | `tests/` |
| MCP-Orbit Frontend | vitest | `{component}.ac.test.tsx` | 컴포넌트 옆 |

### stub 생성 원칙

1. **Given → Setup**: 테스트 데이터, mock, 전제조건 설정 (TODO 주석)
2. **When → Execute**: 대상 함수/API 호출 (TODO 주석)
3. **Then → Assert**: 기대 결과 assertion (`expect(false)` → 구현 전 fail 보장)
4. **And → 추가 Assert**: Then 아래에 추가 assertion

### jest stub 템플릿

```typescript
describe('{StoryId}-AC{N}: {제목}', () => {
  it('Given: {given}, When: {when}, Then: {then}', async () => {
    // Given (Setup)
    // TODO: {given} 전제조건 설정

    // When (Execute)
    // TODO: {when} 실행

    // Then (Assert)
    expect(true).toBe(false); // FAIL until implemented
    // TODO: {then} 검증
  });
});
```

### pytest stub 템플릿

```python
class Test{StoryId}AC{N}:
    """{StoryId}-AC{N}: {제목}"""

    def test_given_{given_slug}_when_{when_slug}_then_{then_slug}(self):
        # Given
        # TODO: {given} 전제조건 설정

        # When
        # TODO: {when} 실행

        # Then
        assert False, "Not implemented yet"
        # TODO: {then} 검증
```

## AC 없는 Task 처리

Task 파일에 Given-When-Then AC가 없으면:
```
[Phase 1.5] AC-to-Test: Given-When-Then AC 미발견. 경고 후 Phase 2로 진행.
```
- Blocking 아님 — 경고만 출력
- Phase 2(구현)는 정상 진행
- Phase 3 검증 시 AC 테스트 단계 스킵

## Frontend AC 특수 처리

- 컴포넌트 렌더링 테스트: `render()` + `screen.getByRole()` stub
- UI 상호작용: `fireEvent` / `userEvent` stub
- Snapshot 테스트: 선택적 (불안정성 고려, 기본 비활성)
- 타입 체크 우선: `satisfies` / `as const` 활용한 컴파일 타임 검증

## Phase 3 연동

Phase 1.5에서 생성한 stub이 Phase 3에서 검증됨:
```
Phase 1.5: AC stub 생성 (모두 FAIL)
    ↓
Phase 2: 구현 (stub의 TODO를 실제 코드로 교체)
    ↓
Phase 3: 테스트 실행
    ├─ 모두 PASS → AC 달성 확인 → Phase 3.5
    └─ FAIL 존재 → 구현 재개 (error-fixer loop)
```
