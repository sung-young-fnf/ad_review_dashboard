# story-creator Binary Eval Template

> story-creator Agent 최적화를 위한 사전 정의 eval set.
> 핵심 목표: "이미 구현된 기능을 놓치지 않고, AC가 검증 가능한 Story를 생성하는가?"

---

## 권장 Test Inputs (4개)

1. "새로운 CRUD 기능 Epic" — 기본 Story 분해
2. "기존 기능 개선 Epic" — 구현 여부 확인 필요
3. "크로스 도메인 Epic (BE+FE+DB)" — 복잡한 분해
4. "UX 개선 Epic" — AC 구체성 요구

---

## Eval Set (5개)

```
EVAL 1: 코드 검증 수행
Question: Story 작성 전에 Grep/Glob으로 기존 구현 여부를 확인했는가?
Pass: 각 Story의 핵심 키워드로 코드 검색 수행
Fail: 코드 검증 없이 "신규 구현" 표시

EVAL 2: ALREADY IMPLEMENTED 표시
Question: 이미 구현된 기능에 "ALREADY IMPLEMENTED" 또는 "구현 완료" 표시가 있는가?
Pass: 기존 코드가 있는 기능은 명확히 표시됨
Fail: 이미 구현된 기능을 "신규"로 잘못 분류

EVAL 3: AC 검증 가능성
Question: 모든 Acceptance Criteria가 구체적이고 검증 가능한가? ("개선" 같은 모호한 표현 없음)
Pass: 모든 AC에 구체적 조건 (수치, 동작, 상태) 포함
Fail: "사용성 개선", "성능 향상" 같은 모호한 AC 존재

EVAL 4: Story 독립성
Question: 각 Story가 독립적으로 구현/테스트 가능한가?
Pass: Story 간 순환 의존성 없음, 각각 독립 배포 가능
Fail: Story A를 완료해야만 Story B를 시작할 수 있는 강한 결합

EVAL 5: YAGNI 준수
Question: Epic 범위를 벗어나는 "미래 대비" Story가 없는가?
Pass: 모든 Story가 현재 요구사항에 직접 기여
Fail: "향후 확장을 위한", "나중에 필요할" 같은 Story 존재
```

---

## 채점 기준

- Runs per experiment: 5
- Max score: 5 evals × 5 runs = 25
- Baseline 기대치: 55~70% (EP135/136 사례 기반)
- 목표: 90%+
