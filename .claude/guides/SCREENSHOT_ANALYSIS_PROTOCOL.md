# Screenshot Analysis Protocol

> **핵심**: 스크린샷만 보고 추측 금지. Metadata 수집 → 컨텍스트 병합 → 정확한 위치 파악

## 필수 6-Phase (모든 스크린샷 수신 시)

### Phase 0: Screenshot Detection (자동 - Hook 시스템)
- user-prompt-submit hook이 스크린샷 키워드/base64 감지
- Screenshot Protocol 컨텍스트 자동 주입

### Phase 1: Screenshot Analysis (먼저 시도)

스크린샷에서 직접 읽기:
- URL 바에서 경로 확인 (/admin/teams)
- 페이지 제목 확인 (탭 또는 헤더)
- UI 요소 위치 파악

결과:
- ✅ 명확함 → Phase 2로 진행
- ❌ 불명확 → Phase 1.5 실행

### Phase 1.5: Metadata Collection (조건부 - Chrome DevTools)

**조건**: 스크린샷 분석만으로 불충분할 때
- URL 안 보임
- 페이지 제목 불명확
- Active Element 특정 필요

**Tools**:
```bash
mcp__chrome-devtools__list_pages    # URL, Title 확인
mcp__chrome-devtools__take_snapshot # Active Element 확인
```

**제약사항**: 페이지가 닫혔으면 chrome-error 반환 → 스크린샷 분석으로 폴백

### Phase 1.6: 능동적 Git Context 탐색 (항상 실행)

**목적**: 해당 영역의 최근 변경 이력 파악

**검색 전략 (우선순위 순)**:
```bash
# 1. 파일 경로 기반
git log --oneline -5 -- "**/spark-note/**"

# 2. 컴포넌트명 기반
git log --all --grep="SparkNote" --oneline -5

# 3. URL 키워드 기반
git log --all --grep="spark-note" --oneline -5
```

**출력 예시**:
```
📚 최근 변경 이력 (자동 탐색):
- 3일 전: "제출 로직 리팩토링" (c8a2c33)
- 1주 전: "상태 관리 방식 변경" (45ab763)
→ 주의: 상태 관리 방식이 최근 변경됨
```

### Phase 1.7: 컴포넌트 영향도 사전 분석

**목적**: 수정 대상 컴포넌트의 사용처 미리 파악

**조건**: PascalCase 컴포넌트명이 식별된 경우

**실행 방법**:
```bash
grep -rn --include="*.tsx" --include="*.ts" \
     -E "(import.*{Component}|<{Component})" \
     apps/frontend/src/ | grep -v "node_modules" | head -15
```

**임계값**:
- 🟡 MEDIUM: 3-4곳 사용 (경고)
- 🟠 HIGH: 5-9곳 사용 (주의 필요)
- 🔴 CRITICAL: 10곳+ 사용 (신중한 수정 필요)

**출력 예시**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 PRE-REVIEW IMPACT ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟠 SparkNoteSidebar (9곳에서 사용, HIGH)
   영향받는 파일:
   - app/(authenticated)/spark-note/SparkNotePageClient.tsx
   - app/(authenticated)/team/TeamPageClient.tsx
   - app/(authenticated)/leader-spark-note/...
💡 이 컴포넌트 수정 시 위 파일들에 영향이 있습니다.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Phase 2: Context Merge (분석)

**URL → 파일 경로 매핑**:
```yaml
/admin/teams → app/(authenticated)/admin/teams/page.tsx
/spark-note → app/(authenticated)/spark-note/page.tsx
```

**Title → 컴포넌트 추론**:
```yaml
"Team Dashboard" → TeamDashboard
"Spark Note" → SparkNoteView
```

**Active Element → 문제 영역**:
```yaml
button[data-testid="action-btn"] → ActionButton 컴포넌트
div[role="dialog"] → Modal/Dialog 컴포넌트
```

### Phase 3: Accurate Location (결론)

**📍 출력 형식**:
```
- 파일: app/(authenticated)/admin/teams/page.tsx:45
- 컴포넌트: TeamDashboard
- 문제 영역: ActionButton (조건부 렌더링 미적용)
```

---

## 금지 사항

- ❌ "화면을 보니 Dashboard 같습니다" (추측)
- ❌ "Admin 페이지일 것 같습니다" (불명확)
- ❌ URL 확인 없이 스크린샷만 분석

## 올바른 패턴

- ✅ "URL /admin/teams 확인 → TeamDashboard 컴포넌트"
- ✅ "app/(authenticated)/admin/teams/page.tsx:45 수정 필요"
- ✅ Metadata 수집 → 정확한 답변
