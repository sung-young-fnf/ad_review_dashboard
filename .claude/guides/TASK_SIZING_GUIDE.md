# Task 크기 표준화 가이드

> **목적**: Task 분해 일관성 확보 및 병렬 실행 효율성 극대화

---

## 📐 Task 크기 기준

### Small Task (15-30분)
**정의**: 단일 작업 단위, 의존성 최소

**특징**:
- 수정 파일 1-2개
- 단순 로직 (조건 분기 없음)
- 외부 의존성 없음
- 테스트 불필요 (통합 테스트에서 커버)

**예시**:
```yaml
✅ 올바른 Small Task:
  - WeeklyOKRCard에 "수정하기" 버튼 추가
  - useRouter hook으로 /spark-note 페이지 이동
  - 파일: 1개 (WeeklyOKRCard.tsx)
  - 시간: 15분

✅ 올바른 Small Task:
  - Avatar 컴포넌트에 fallback 이미지 추가
  - 파일: 1개 (Avatar.tsx)
  - 시간: 20분

❌ 과소 분해 (Small Task로 부적합):
  - import 문 추가만 (5분)
  - 상수 정의만 (5분)
  → 상위 Task에 병합 필요
```

**task-planner 출력 형식**:
```markdown
- [x] **T001-S01 [Small]**: 편집 버튼 추가 (15분)
```

---

### Medium Task (30-90분)
**정의**: 복잡한 로직 또는 여러 컴포넌트 조합

**특징**:
- 수정 파일 3-5개
- 조건 분기, 에러 처리 포함
- 외부 API 호출 1-2개
- 단위 테스트 필요

**예시**:
```yaml
✅ 올바른 Medium Task:
  - GET /api/v1/user/okrs/:okrId 조회
  - React Query 설정
  - 에러 처리 (404, 403, 500)
  - 로딩/에러 상태 UI
  - 파일: 3개 (hooks.ts, api.ts, component.tsx)
  - 시간: 45분

✅ 올바른 Medium Task:
  - CampaignItem 컴포넌트 구현
  - Badge, 호버/선택 상태 UI
  - URL 쿼리 동기화
  - 파일: 4개 (CampaignItem.tsx, useCampaigns.ts, styles.css, types.ts)
  - 시간: 60분

❌ 과대 분해 (Medium으로 통합 필요):
  - T001: React Query 설정 (15분)
  - T002: API 호출 함수 (15분)
  - T003: 에러 처리 (15분)
  → 하나의 Medium Task로 통합
```

**task-planner 출력 형식**:
```markdown
- [ ] **T003-S01 [Medium]**: OKR 데이터 조회 및 에러 처리 (45분)
```

---

### Large Task (90-120분)
**정의**: 통합 작업, E2E 테스트, 복잡한 상태 머신

**특징**:
- 수정 파일 6개 이상
- 여러 시스템 통합
- E2E 테스트 필수
- 여러 Phase의 통합 검증

**예시**:
```yaml
✅ 올바른 Large Task:
  - 편집 모드 전체 플로우 E2E 테스트
  - Playwright 시나리오 작성
  - 성공/실패 케이스 검증
  - 파일: 10개 이상 (모든 Phase 파일 + 테스트)
  - 시간: 120분

✅ 올바른 Large Task:
  - Admin Impersonation 통합
  - Frontend: 사용자 선택 UI
  - Backend: X-Impersonate-User 헤더 검증
  - Middleware: 권한 체크
  - E2E 테스트
  - 파일: 8개
  - 시간: 90분

❌ 너무 큰 Task (2개 Large로 분리 필요):
  - 전체 인증 시스템 구현 (3시간)
  → Large 1: 로그인 플로우 (90분)
  → Large 2: 권한 관리 (90분)
```

**task-planner 출력 형식**:
```markdown
- [ ] **T007-S01 [Large]**: 편집 모드 E2E 통합 테스트 (120분)
```

---

## 🚫 과대/과소 분해 방지 규칙

### 과소 분해 방지 (Too Small)
**규칙**: 10분 이하 Task는 상위 Task에 병합

**잘못된 예**:
```yaml
T001: useRouter import 추가 (5분)
T002: handleEdit 함수 작성 (10분)
T003: Button 컴포넌트 추가 (5분)
```

**올바른 병합**:
```yaml
T001 [Small]: 편집 버튼 추가 및 Navigation (20분)
  - useRouter import
  - handleEdit 함수 작성
  - Button 컴포넌트 추가
```

---

### 과대 분해 방지 (Too Fragmented)
**규칙**: 동일 파일 수정 Task는 통합

**잘못된 예**:
```yaml
T001: hooks.ts에 useFetch 추가 (15분)
T002: hooks.ts에 useQuery 설정 (15분)
T003: hooks.ts에 에러 처리 (15분)
```

**올바른 통합**:
```yaml
T001 [Medium]: API 조회 Hook 구현 (45분)
  - useFetch 추가
  - useQuery 설정
  - 에러 처리
```

---

## 🔀 병렬 실행 최적화

### 병렬 실행 가능 조건
```yaml
조건:
  - 수정 파일 겹치지 않음
  - 함수/변수명 충돌 없음 (Story 단계에서 네이밍 사전 정의)
  - 의존성 없음 (한쪽 완료 기다릴 필요 없음)

예시 (EP012-S04):
  ✅ 병렬 가능:
    T008 [Medium]: Sidebar 컴포넌트 생성 (60분)
      - 파일: SparkNoteSidebar.tsx, CampaignList.tsx
    T009 [Medium]: Campaign API 연동 (45분)
      - 파일: useCampaigns.ts, api.ts
    → 파일 겹치지 않음 ✅

  ❌ 병렬 불가:
    T010 [Medium]: CampaignItem 컴포넌트 (60분)
      - 파일: CampaignItem.tsx (T008에서 import)
    → T008 완료 후 실행
```

---

## 📊 Phase 구조 활용

### Phase별 Task 그룹화
**목적**: 의존성 명시, 병렬 실행 지점 명확화

**구조**:
```markdown
### Phase 1: 기본 구조 (병렬 실행 가능 🔀)
- [ ] **T001 [Small]**: Component A 생성 (20분)
  - 의존성: 없음
  - 병렬: T002 (독립 실행 가능)

- [ ] **T002 [Small]**: Component B 생성 (20분)
  - 의존성: 없음
  - 병렬: T001

### Phase 2: API 연동 (T001, T002 완료 후)
- [ ] **T003 [Medium]**: API Hook 구현 (45분)
  - 의존성: T001, T002
  - 병렬: 없음
```

**Phase 실행 순서**:
1. Phase 1 Task들 병렬 실행 (T001 + T002)
2. Phase 1 완료 대기
3. Phase 2 시작 (T003)

---

## 🎯 task-planner Agent 적용

### Agent 출력 형식 (PROGRESS.md)
```markdown
## 📋 Story별 Task 목록

### S01: Spark Note 편집 모드

#### Phase 1: 네비게이션 (병렬 실행 가능 🔀)
- [x] **T001-S01 [Small]**: 편집 버튼 네비게이션 (20분)
  - 상태: ✅ 완료
  - 의존성: 없음
  - 병렬: T002 (독립 실행 가능)
  - 설명: WeeklyOKRCard에 편집 버튼 추가 및 라우팅

- [ ] **T002-S01 [Small]**: 편집 모드 감지 (15분)
  - 상태: ⏳ 대기
  - 의존성: 없음
  - 병렬: T001
  - 설명: URL 쿼리에서 okrId 추출 및 편집 모드 판단

#### Phase 2: 데이터 조회 (Phase 1 완료 후)
- [ ] **T003-S01 [Medium]**: OKR 데이터 조회 (45분)
  - 상태: ⏳ 대기
  - 의존성: T001, T002
  - 병렬: 없음
  - 설명: GET /api/v1/user/okrs/:okrId API 호출 + 에러 처리
```

---

## ✅ 체크리스트 (task-planner 실행 시)

**Task 분해 시 확인사항**:
```yaml
1. ⛔ 크기 기준 준수
   → Small: 15-30분, Medium: 30-90분, Large: 90-120분
   → 10분 이하 Task는 병합

2. ⛔ 과대 분해 방지
   → 동일 파일 수정 Task는 통합
   → 3개 Small Task → 1개 Medium Task

3. ⛔ Phase 구조 명시
   → Phase 1: 기본 구조 (병렬 가능)
   → Phase 2: 통합 (순차 실행)

4. ⛔ 의존성 명확화
   → 의존성: T001, T002
   → 병렬: T003 (독립 실행 가능)

5. ⛔ 크기 라벨 추가
   → [Small], [Medium], [Large]
```

---

## 📈 예상 효과

### Before (표준화 전)
```yaml
Task 크기 분포:
  - 5-10분: 20% (과소 분해)
  - 15-30분: 30%
  - 30-90분: 30%
  - 90-180분: 20% (과대 분해)

병렬 실행 효율:
  - 크기 불균형으로 한쪽만 먼저 완료
  - 전체 시간: Max(T001, T002) → 긴 쪽에 종속
  - 효율: 50%
```

### After (표준화 후)
```yaml
Task 크기 분포:
  - Small: 40% (15-30분)
  - Medium: 50% (30-90분)
  - Large: 10% (90-120분)

병렬 실행 효율:
  - 비슷한 크기 Task 병렬 실행
  - 전체 시간: 거의 동일하게 완료
  - 효율: 90%
```

---

**작성일**: 2025-11-07
**적용 대상**: task-planner Agent
**참조 문서**: `docs/audit/agent-workflow-analysis-2025-11-07.md`
