# code-writer Binary Eval Template

> code-writer Agent 최적화를 위한 사전 정의 eval set.
> ERRORS.md/LEARNINGS.md 분석에서 도출된 주요 실패 패턴 기반.

---

## 권장 Test Inputs (5개)

1. "간단한 API 엔드포인트 추가 (CRUD)" — 기본 기능
2. "기존 컴포넌트에 필드 추가 (Backend + Frontend)" — Full-stack 변경
3. "버그 수정 (타입 에러)" — 디버깅 능력
4. "UI 컴포넌트 신규 생성" — 프론트엔드 전용
5. "DB 스키마 변경 + API 반영" — 크로스 레이어

---

## Eval Set (5개)

```
EVAL 1: 빌드 통과
Question: 변경 후 pnpm tsc --noEmit가 에러 0개로 통과하는가?
Pass: TypeScript 컴파일 에러 0개
Fail: 1개 이상 컴파일 에러

EVAL 2: Full-Stack 완전성
Question: feat 변경 시 Backend + BFF Route + Frontend가 모두 포함되었는가?
Pass: 3개 레이어 모두 변경됨 (또는 순수 인프라/내부 로직이라 불필요)
Fail: Backend만 있고 BFF/Frontend 누락 (feat인데 한쪽만)

EVAL 3: Scope 준수
Question: git diff --name-only가 Task에 명시된 파일만 포함하는가?
Pass: 변경 파일이 모두 Task scope 내
Fail: Task에 없는 파일이 변경됨 (scope creep)

EVAL 4: 교정 패턴 미위반
Question: LEARNINGS.md의 기존 교정 패턴을 반복하지 않는가?
Pass: 알려진 anti-pattern 0개 재현
Fail: 이전에 교정된 실수를 반복 (예: useEffect 객체 의존성, public 스키마 사용)

EVAL 5: Pre-Flight 준수
Question: 2파일+ 변경 시 Pre-Flight 블록을 출력한 후 구현했는가?
Pass: "내 이해/접근법/수정 파일" 블록이 구현 전에 존재
Fail: Pre-Flight 없이 바로 코드 작성 시작
```

---

## 채점 기준

- Runs per experiment: 5 (권장)
- Max score: 5 evals × 5 runs = 25
- Baseline 기대치: 60~75% (현재 ERRORS.md 기반 추정)
- 목표: 90%+

---

## ERRORS.md에서 추출된 주요 실패 패턴

| 패턴 | 빈도 | 관련 Eval |
|------|------|-----------|
| TypeScript 빌드 실패 | 높음 | EVAL 1 |
| Backend만 구현 후 완료 보고 | 높음 | EVAL 2 |
| Task 범위 밖 리팩토링 | 중간 | EVAL 3 |
| useEffect 무한 렌더 | 중간 | EVAL 4 |
| Pre-Flight 없이 바로 구현 | 높음 | EVAL 5 |
