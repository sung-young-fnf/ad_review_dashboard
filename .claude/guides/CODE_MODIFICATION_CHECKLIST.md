# CODE MODIFICATION CHECKLIST

> **목적**: 코드 수정 시 Side Effect 영향 범위를 완전히 분석하여 버그 사전 방지

## 📋 실제 사례 기반 체크리스트

### Case 1: 임시저장 토스트 중복 (2025-11-10)

**문제**:
- `handleManualSave` → `onDraftSave` → `handleDraftSave`
- 각각 `toast.success()` 호출 → 사용자에게 2개 메시지 표시

**놓친 체크**:
```yaml
✅ 확인함: handleManualSave가 toast 호출
❌ 누락함: handleDraftSave도 toast 호출하는지 확인
❌ 누락함: 호출 체인 전체에서 toast 횟수 세기
❌ 누락함: 최종 사용자가 보는 메시지 예상
```

**올바른 체크**:
```yaml
1. handleManualSave 작성 시:
   ✅ toast.success('임시 저장') 확인

2. handleDraftSave 작성 시 (handleCampaignSubmit 복사):
   ✅ toast.success('Spark Note 제출 완료') 발견
   ✅ 호출 체인 확인: handleManualSave → onDraftSave → handleDraftSave
   ✅ Toast 호출 개수: 2개 (중복!)
   ✅ 수정: handleDraftSave의 toast 제거
```

---

## 🎯 필수 체크리스트 (모든 코드 수정 시)

### ✅ 1. 함수 호출 체인 전체 추적

**새 함수 작성/수정 시**:
```yaml
- [ ] 이 함수를 호출하는 상위 함수 확인
- [ ] 이 함수가 호출하는 하위 함수 확인
- [ ] 전체 호출 체인 작성 (A → B → C → D)
- [ ] 각 단계별 Side Effect 리스트업
```

**예시**:
```typescript
// 호출 체인 추적
handleManualSave()          // 1. 사용자 클릭
  → onDraftSave()           // 2. Prop 전달
    → handleDraftSave()     // 3. 실제 구현

// Side Effect 리스트업
handleManualSave:
  - toast.success('임시 저장')
  - setIsSavingDraft(true/false)

handleDraftSave:
  - toast.success('제출 완료')    // ❌ 중복!
  - API 호출 (POST/PATCH)
  - setExistingSubmissionId()
  - queryClient.invalidateQueries()
```

---

### ✅ 2. Toast 메시지 중복 검증

```bash
# 체크 명령어
grep -r "toast\\.success\\|toast\\.error" {수정한_파일}
grep -A 10 "const {함수명}" {수정한_파일} | grep "toast"
```

**원칙**:
- ✅ 최상위 호출자만 Toast 표시
- ✅ 하위 핸들러는 Toast 제거, 에러만 throw
- ✅ 동일 액션에 메시지 1개만

**Bad**:
```typescript
// handleDraftSave (하위 핸들러)
await submitAPI(data);
toast.success('제출 완료'); // ❌

// handleManualSave (상위 호출자)
await onDraftSave(data);
toast.success('임시 저장'); // ❌
```

**Good**:
```typescript
// handleDraftSave (하위 핸들러)
await submitAPI(data);
// toast 없음 ✅

// handleManualSave (상위 호출자)
await onDraftSave(data);
toast.success('임시 저장'); // ✅ 유일
```

---

### ✅ 3. Console.log 중복 검증

```bash
# 동일 이벤트에 중복 로깅 확인
grep -r "console\\.log.*{이벤트명}" {수정한_파일}
```

**원칙**:
- ✅ 중요한 단계만 로깅 (진입, 완료, 에러)
- ✅ 동일 정보 중복 로깅 방지
- ✅ DEBUG 로그는 조건부 (개발 환경만)

---

### ✅ 4. 상태 업데이트 중복 검증

```bash
# 동일 상태 변수 업데이트 추적
grep -r "setIsSubmitting" {수정한_파일}
grep -r "setIsSavingDraft" {수정한_파일}
```

**원칙**:
- ✅ 각 상태는 1개 함수에서만 관리
- ✅ 경쟁 조건(Race Condition) 방지
- ✅ 상태 전환 순서 명확히

**Bad**:
```typescript
// handleDraftSave
setIsSubmitting(true);  // ❌
await submit();
setIsSubmitting(false);

// handleManualSave
setIsSavingDraft(true);  // ❌
await onDraftSave();
setIsSavingDraft(false);
```

**Good**:
```typescript
// handleDraftSave (하위)
await submit();
// 상태 관리 없음 ✅

// handleManualSave (상위)
setIsSavingDraft(true);  // ✅
await onDraftSave();
setIsSavingDraft(false);
```

---

### ✅ 5. Event Listener 중복/누락 검증

```bash
# addEventListener 중복 등록 확인
grep -r "addEventListener" {수정한_파일}

# removeEventListener 누락 확인
grep -r "removeEventListener" {수정한_파일}
```

**원칙**:
- ✅ useEffect cleanup에서 제거
- ✅ 동일 이벤트 중복 등록 방지
- ✅ 컴포넌트 언마운트 시 정리

---

### ✅ 6. 최종 사용자 경험 예측

**질문**:
1. 사용자가 버튼을 클릭하면 무엇을 보게 되나?
2. Toast 메시지는 몇 개 표시되나?
3. 메시지 내용이 액션과 일치하나?
4. 로딩 상태가 명확하게 표시되나?

**예상 플로우 작성**:
```
사용자: "임시 저장" 버튼 클릭
→ 버튼: "저장 중..." 표시
→ API: POST /submit 호출
→ 상태: existingSubmissionId 설정
→ Toast: "임시 저장되었습니다" (1개만!) ✅
→ 버튼: "⚠️ 제출 취소"로 변경
```

---

## 🚨 코드 복사 시 특별 주의

**기존 함수에서 로직 복사 시**:

```yaml
필수 확인:
  - [ ] 원본 함수의 모든 Side Effect 파악
  - [ ] 새 함수에서 불필요한 Side Effect 제거
  - [ ] Toast, Console, 상태 업데이트 재검토
  - [ ] 호출 체인에서 중복 확인
```

**예시** (handleCampaignSubmit → handleDraftSave 복사):
```typescript
// 원본 (handleCampaignSubmit)
await submitAPI(data);
toast.success('Spark Note 제출 완료'); // ← 이것도 복사됨!
setExistingSubmissionId(id);

// 복사 후 (handleDraftSave)
await submitAPI(data);
toast.success('Spark Note 제출 완료'); // ❌ 제거 필요!
setExistingSubmissionId(id);

// 수정 완료 (handleDraftSave)
await submitAPI(data);
// toast 제거 - 상위에서 표시 ✅
setExistingSubmissionId(id);
```

---

## 📊 체크리스트 적용 효과

**Before** (체크리스트 없음):
- 토스트 중복 → 브라우저 테스트에서 발견
- 사용자 혼란 발생
- 추가 수정 필요 (개발 시간 증가)

**After** (체크리스트 적용):
- 코드 작성 시점에 중복 감지
- 브라우저 테스트 전 완료
- 사용자 경험 일관성 보장

---

## 🔧 실전 적용 예시

### 시나리오: 새 핸들러 함수 작성

```yaml
작업: handleDraftSave 함수 작성

Step 1: 호출 체인 추적
  → handleManualSave → onDraftSave → handleDraftSave

Step 2: 각 단계별 Side Effect 확인
  handleManualSave:
    - toast.success('임시 저장')
    - setIsSavingDraft(true/false)

  handleDraftSave (작성 중):
    - API 호출
    - toast.success('제출 완료') ← 발견!
    - 상태 업데이트

Step 3: 중복 Side Effect 제거
  handleDraftSave:
    - API 호출 ✅
    - toast 제거 ✅ (상위에서 표시)
    - 상태 업데이트 ✅

Step 4: 최종 사용자 경험 예측
  클릭 → API 호출 → "임시 저장되었습니다" (1개) ✅
```

---

## 📚 참조 문서

- **error-fixer Agent**: `.claude/agents/99-utils/error-fixer.md` (Phase 2.5)
- **Pre-hook**: `.claude/hooks/pre/user-prompt-submit.sh` (detect_toast_flow)
- **실제 사례**: `docs/patterns/debugging/toast-duplication-fix-2025-11-10.md`

---

## 🎯 핵심 원칙

> **"코드를 작성하기 전에, 호출 체인 전체를 그려라"**

1. ✅ 함수 호출 체인 시각화
2. ✅ 각 단계별 Side Effect 리스트업
3. ✅ 중복 Side Effect 제거
4. ✅ 최종 사용자 경험 예측

**이 4단계만 지켜도 90% 이상의 Side Effect 버그를 사전에 방지할 수 있습니다.**
