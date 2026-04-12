# Component Reuse Rules

> **핵심**: 컴포넌트를 다른 페이지에서 재사용할 때 반드시 확인

## 필수 체크리스트

### 1. 원본 컴포넌트 분석

- ✅ onClick 핸들러 확인 (router.push, URL 변경)
- ✅ 상태 관리 방식 (로컬 useState vs 전역 Zustand/URL)
- ✅ 페이지 특화 로직 존재 여부
- ✅ 하드코딩된 경로 (`/spark-note` 등)

### 2. Side Effect 예측

- ✅ 다른 페이지에서 사용 시 발생 가능한 문제
- ✅ 상태 동기화 이슈 (독립적 로컬 상태)
- ✅ URL 변경 동작 (원하지 않는 페이지 이동)

### 3. 설계 결정

- ✅ 조건부 동작 prop 추가 (`disableRouting`, `pageType`)
- ✅ URL 기반 상태 관리로 전환 (공유 상태 필요 시)
- ✅ 페이지별 Wrapper 컴포넌트 생성 (복잡한 분기 시)

---

## 구현 패턴

### Pattern 1: Conditional Prop (간단한 분기)

```typescript
interface SidebarProps {
  disableRouting?: boolean;  // 페이지별 동작 제어
}

function handleClick() {
  if (!disableRouting) {
    router.push('/target-page');
  }
}
```

### Pattern 2: URL-based State (상태 공유)

```typescript
// ✅ 올바른 패턴: URL이 Single Source of Truth
const searchParams = useSearchParams();
const pathname = usePathname();

if (disableRouting) {
  router.push(`${pathname}?${params}`);  // 현재 페이지 유지
} else {
  router.push(`/target?${params}`);  // 페이지 전환
}
```

### Pattern 3: Page-Specific Wrapper (복잡한 분기)

```typescript
// 페이지별 Wrapper 컴포넌트
export function SparkNoteSidebar() {
  return <BaseSidebar pageType="spark-note" />;
}

export function TeamSidebar() {
  return <BaseSidebar pageType="team" />;
}
```

---

## 검증 체크리스트

- ✅ 원본 페이지: 기존 동작 유지 확인
- ✅ 신규 페이지: 원하는 동작 확인
- ✅ 상태 동기화: 양쪽 페이지 모두 동일한 상태 구독
- ✅ 브라우저 히스토리: 뒤로/앞으로 가기 테스트

---

## 금지 사항

- ❌ 원본 컴포넌트 분석 없이 무작정 재사용
- ❌ 로컬 상태를 전역 상태로 착각
- ❌ 페이지별 동작 분기 없이 하드코딩
- ❌ 한쪽 페이지만 테스트하고 완료 판단

---

## 실제 케이스 (SparkNoteSidebar 재사용)

### 문제

- Spark Note 페이지용 SparkNoteSidebar를 Team 페이지에 재사용
- 캠페인 클릭 시 `/spark-note`로 이동하는 버그 발생
- 상태가 동기화되지 않아 목록 미표시

### 해결

1. `disableRouting` prop 추가
2. URL 쿼리 파라미터 기반 상태 공유
3. 양쪽 페이지 모두 테스트

### 교훈

> 컴포넌트 재사용 전 **반드시** 원본 분석 → Side Effect 예측 → 설계 결정 순서 준수
