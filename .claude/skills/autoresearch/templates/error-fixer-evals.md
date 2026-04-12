# error-fixer Binary Eval Template

> error-fixer Agent 최적화를 위한 사전 정의 eval set.
> 핵심 목표: "첫 시도에 올바르게 수정하는가?"

---

## 권장 Test Inputs (5개)

1. "TypeScript 컴파일 에러 (타입 불일치)" — 가장 빈번
2. "런타임 에러 (undefined 참조)" — 실행 시 발생
3. "빌드 실패 (import 순환)" — 구조적 문제
4. "API 404/500 에러" — Backend 이슈
5. "React hydration mismatch" — SSR 특화

---

## Eval Set (4개)

```
EVAL 1: 첫 시도 해결
Question: 수정 1회만에 에러가 해결되었는가? (재수정 없이)
Pass: 첫 Edit/Write 후 빌드 통과
Fail: 2회 이상 수정 시도 필요

EVAL 2: 근본 원인 특정
Question: 수정 전에 에러의 근본 원인을 파일:라인 수준으로 특정했는가?
Pass: 구체적 파일:라인 참조 후 수정
Fail: 추측으로 여러 파일 시도

EVAL 3: 부작용 없음
Question: 에러 수정 후 새로운 에러가 발생하지 않았는가?
Pass: 수정 전 에러 수 ≥ 수정 후 에러 수 (즉, 늘어나지 않음)
Fail: 수정으로 인해 새로운 에러 발생

EVAL 4: historian 사전 조회
Question: 수정 전에 historian/get_error_solutions 또는 docs/solutions/ 검색을 했는가?
Pass: 과거 솔루션 조회 후 수정 시작
Fail: 과거 지식 미참조
```

---

## 채점 기준

- Runs per experiment: 5
- Max score: 4 evals × 5 runs = 20
- Baseline 기대치: 50~65%
- 목표: 85%+
