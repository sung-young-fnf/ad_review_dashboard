# Goal-Oriented Prompting Guide

> "이렇게 해"보다 "이 상태가 되면 성공"을 주는 것이 AI 코딩의 핵심.

## 핵심 원리

AI에게 작업을 맡길 때:
- **HOW(어떻게)** 를 고정하면 → AI의 문제 해결 공간이 좁아짐
- **WHAT(무엇)** 을 주면 → AI가 최적의 경로를 스스로 찾음
- **WHY(왜)** 를 알려주면 → 엣지 케이스에서 의도에 맞는 판단

## 3-Layer 구조

### Layer 1: Goal (필수)
```
"이 조건이 모두 참이면 성공"
- 검증 가능한 체크리스트
- pnpm build 성공, 테스트 통과, AC 달성
```

### Layer 2: Constraint (필수)
```
"이것을 위반하면 실패"
- BFF 패턴 준수, public 스키마 금지
- 보안 규칙, 아키텍처 패턴
```

### Layer 3: Hint (선택)
```
"이렇게 하면 더 나을 수 있다"
- 기존 패턴 참조, fetchWithAuth 활용
- AI가 더 나은 방법 찾으면 무시 가능
```

## 계층별 Goal 비중

| 상위 (Epic/Story) | 100% Goal | "사용자가 Excel 미리보기를 볼 수 있는 상태" |
|---|---|---|
| **중간 (Task)** | **Goal + Constraint** | "API가 5행 반환 + BFF 경유" |
| **하위 (간단 수정)** | **직접 명령 OK** | "line 42의 타입을 nullable로 변경" |

## 실전 예시

### Epic 수준 (100% Goal)
```
❌ "Excel 노드에 미리보기 기능을 추가하고, backend에 API를 만들고..."
✅ "사용자가 워크플로우 편집 중 Excel 데이터를 즉시 확인할 수 있는 상태"
```

### Task 수준 (Goal + Constraint)
```
❌ "GET /api/excel/preview 엔드포인트를 만들어서 Graph API를 호출해"
✅ Goal: "미리보기 API가 headers + 최대 5행을 반환하는 상태"
   Constraint: "BFF 경유, 3초 타임아웃"
   Hint: "Graph API 병렬 호출 권장"
```

### 간단 수정 (직접 명령 OK)
```
✅ "ExcelNode.tsx line 42의 User를 User | null로 변경"
→ 이미 원인을 아는 1줄 수정. 목표 형태 불필요.
```

## Agent 프롬프트 작성 원칙

### 종료 조건을 Goal로 명시
```
❌ "에러를 찾아서 수정해"
✅ "pnpm build가 성공하고, 콘솔에 에러가 0개인 상태"
```

### HOW는 Hint로 분리
```
❌ "historian에서 검색하고, 패턴 매칭하고, 수정하고, 검증해"
✅ Goal: "모든 TypeScript 에러가 해결된 상태"
   Hint: "historian에서 과거 해결책 참조 권장"
```

## WHY 원칙

모든 규칙과 제약에는 "왜"가 필요하다:
```
규칙: "code-writer 필수"
WHY: "validator 체인으로 AC 달성을 자동 검증하기 위함"
→ AI가 의도를 알면 엣지 케이스에서 더 나은 판단
```

## 참조
- @.claude/rules/quality-standards.md (Goal-Oriented Prompting 섹션)
- @.claude/CLAUDE.md (WHY가 추가된 규칙들)
