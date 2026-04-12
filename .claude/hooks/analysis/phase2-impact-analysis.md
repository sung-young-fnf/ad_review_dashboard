# Phase 2 영향도 분석: pre-tool-use-agent-chain-guard.sh

> **작성일**: 2025-11-06
> **적용일**: 2025-11-06 ✅
> **상태**: Option 3 (조건부 차단) 적용 완료
> **목적**: pre-tool-use Hook의 메인 세션 영향 범위 평가

---

## 📊 Phase 2 개요

### 제안된 Hook
**pre-tool-use-agent-chain-guard.sh**

**기능**:
- Write/Edit/MultiEdit 직접 사용 전 Agent 체인 확인
- Agent 체인 외부에서 직접 구현 시 경고/차단
- CLAUDE.md 규칙 강제 적용

**트리거**: 모든 Write/Edit/MultiEdit 호출

---

## 🎯 영향 범위 분석

### ✅ 긍정적 영향 (Agent 체인 중단 방지)

```yaml
시나리오 1: Agent 체인 실행 중 직접 구현 시도
  - T001 (code-writer) → T002 (code-writer) → "T003 구현" → Write 직접 호출
  - ⚠️ Hook 알림: "Agent 호출 필수"
  - ✅ 효과: 체인 중단 방지 (CLAUDE.md 규칙 강제)

시나리오 2: 완전 자동 실행 모드 중단
  - 자동 실행 중 → 갑자기 직접 구현
  - ⚠️ Hook 알림: "Agent 체인 계속 필요"
  - ✅ 효과: 자동 실행 모드 유지
```

---

### ⚠️ 부정적 영향 (메인 세션 방해)

```yaml
케이스 1: 긴급 핫픽스 (error-fixer 직접 실행)
  사용자: "templateId 버그 긴급 수정"
  메인 세션: Edit(hooks.ts) 직접 사용
  → ⚠️ Hook 경고 발생
  → ❌ 방해: 빠른 수정이 늦어짐

케이스 2: 문서 작성
  사용자: "README 업데이트"
  메인 세션: Write(README.md)
  → ✅ 제외됨 (Markdown 파일 필터링)

케이스 3: Agent 스펙 파일 수정
  사용자: "error-fixer Agent 개선"
  메인 세션: Edit(.claude/agents/99-utils/error-fixer.md)
  → ✅ 제외됨 (Markdown 파일)

케이스 4: 설정 파일 수정
  사용자: "tsconfig.json 수정"
  메인 세션: Edit(tsconfig.json)
  → ⚠️ Hook 경고 발생
  → ❌ 방해: 간단한 설정 변경이 복잡해짐

케이스 5: 즉시 테스트/검증 필요
  사용자: "이 파일만 빠르게 수정해서 테스트"
  메인 세션: Edit(component.tsx)
  → ⚠️ Hook 경고 발생
  → ❌ 방해: 반복 테스트 사이클이 느려짐
```

---

## 📈 영향도 점수 (Impact Score)

### 메트릭

```yaml
방지 효과 (Agent 체인 중단 방지):
  - 체인 중단 감소: 80% → 10% (예상)
  - Agent 체인 완료율: 60% → 95%
  - 점수: +9/10

방해 리스크 (메인 세션 UX):
  - 긴급 핫픽스 지연: 5초 → 15초 (경고 읽기)
  - 설정 파일 수정 복잡도: 증가
  - 즉시 테스트 사이클: 방해
  - 점수: -6/10

순 이익: +3/10 (긍정적이지만 제한적)
```

---

## 🔍 정당한 메인 세션 Write/Edit 케이스

### 1. **긴급 핫픽스** (Emergency Fix)
```yaml
특징:
  - P0 장애, 서비스 다운
  - 즉각적인 수정 필요 (5분 이내)
  - Agent 호출 오버헤드 허용 불가

예시:
  - "API 500 에러 긴급 수정"
  - "프로덕션 크래시 즉시 패치"
  - "null 에러로 서비스 다운"

필요성: Agent 없이 직접 수정 필수
```

### 2. **설정 파일 수정** (Config Changes)
```yaml
특징:
  - tsconfig.json, .env, package.json 등
  - 단순 값 변경 (1-2줄)
  - Agent 오버헤드 불필요

예시:
  - "TypeScript strict 모드 활성화"
  - "환경 변수 추가"
  - "패키지 버전 업데이트"

필요성: 직접 수정이 더 빠름
```

### 3. **즉시 테스트/검증** (Quick Test Cycle)
```yaml
특징:
  - 반복적인 수정 → 테스트 사이클
  - 1-5줄 수정 반복
  - Agent 호출 시 사이클 느려짐

예시:
  - "이 줄만 수정해서 다시 테스트"
  - "로그 추가해서 디버깅"
  - "주석 제거하고 확인"

필요성: 빠른 피드백 루프 필수
```

### 4. **문서/주석 작성** (Documentation)
```yaml
특징:
  - Markdown 파일 (이미 제외됨) ✅
  - 코드 주석 추가
  - JSDoc, 타입 주석

예시:
  - "함수 설명 주석 추가"
  - "타입 정의에 JSDoc 추가"

필요성: 일부 제외되지만 코드 주석은 걸림
```

### 5. **Agent 워크플로우 개선** (Meta-Work)
```yaml
특징:
  - Agent 스펙 파일 수정 (Markdown, 이미 제외됨) ✅
  - Hook 스크립트 수정 (.sh 파일)
  - 워크플로우 개선 작업

예시:
  - "error-fixer Agent 로직 추가"
  - "Hook 스크립트 버그 수정"

필요성: Meta-work는 Agent 사용 비효율적
```

---

## 🎯 Phase 2 적용 옵션

### Option 1: **완전 차단** (Strict Mode)
```yaml
동작:
  - Write/Edit 직접 사용 시 Hook 실패 (exit 1)
  - 강제로 Agent 호출 요구
  - 메인 세션 중단

장점:
  ✅ Agent 체인 중단 100% 방지
  ✅ CLAUDE.md 규칙 강제 적용

단점:
  ❌ 긴급 핫픽스 차단 (심각)
  ❌ 설정 파일 수정 방해
  ❌ 테스트 사이클 느려짐
  ❌ UX 크게 저하

권장: ❌ 비추천 (메인 세션 과도 방해)
```

---

### Option 2: **경고만 표시** (Warning Mode) ⭐
```yaml
동작:
  - Write/Edit 직접 사용 시 경고 메시지
  - Hook 성공 (exit 0)
  - 작업 계속 진행

장점:
  ✅ Agent 체인 중단 인지
  ✅ 메인 세션 방해 최소화
  ✅ 정당한 케이스 허용
  ✅ 학습 효과 (규칙 반복 노출)

단점:
  ⚠️ 강제력 없음 (무시 가능)
  ⚠️ 경고 피로 (Fatigue)

권장: ⭐ 추천 (균형잡힌 접근)
```

**구현 예시**:
```bash
# 경고만 표시 (exit 0)
if [[ "$AGENT_TYPE" != "04-implementation/code-writer" ]]; then
  cat <<EOF >&2
⚠️ Agent 체인 외부에서 직접 구현 감지
파일: $file_path
권장: code-writer Agent 호출 (CLAUDE.md 규칙)
EOF
  # 차단하지 않고 계속 진행
  exit 0
fi
```

---

### Option 3: **조건부 차단** (Conditional Mode)
```yaml
동작:
  - Agent 체인 활성 상태 + 코드 파일 → 차단 (exit 1)
  - 그 외 (설정, 긴급, 단독 작업) → 경고만 (exit 0)

조건:
  1. agent-chain-state.json 존재 (체인 활성)
  2. file_path가 .ts/.tsx/.js/.jsx (코드 파일)
  3. 최근 10분 이내 Agent 완료 (TIMESTAMP 확인)

  → 모두 충족 시 차단

장점:
  ✅ Agent 체인 중단 80% 방지
  ✅ 긴급 핫픽스 허용 (체인 비활성 시)
  ✅ 설정 파일 방해 없음
  ✅ 선택적 강제력

단점:
  ⚠️ 로직 복잡도 증가
  ⚠️ 경계 케이스 처리 필요

권장: ⭐⭐ 가장 추천 (스마트한 접근)
```

**구현 예시**:
```bash
# 조건부 차단
CHAIN_STATE="$REPO_ROOT/.claude/hooks-cache/agent-chain-state.json"

if [[ -f "$CHAIN_STATE" ]]; then
  LAST_TIMESTAMP=$(jq -r '.timestamp // 0' "$CHAIN_STATE")
  CURRENT_TIME=$(date +%s)
  TIME_DIFF=$((CURRENT_TIME - LAST_TIMESTAMP))

  # 10분 이내 (600초) + 코드 파일 → 차단
  if [[ $TIME_DIFF -lt 600 ]] &&
     [[ "$file_path" =~ \.(ts|tsx|js|jsx)$ ]]; then
    # 차단 (exit 1)
    echo "⛔ BLOCKED: Agent 체인 활성 중 직접 구현 금지" >&2
    exit 1
  fi
fi

# 그 외는 경고만
echo "⚠️ WARNING: 직접 구현 (Agent 권장)" >&2
exit 0
```

---

## 📋 최종 권장사항

### 🥇 **권장: Option 3 (조건부 차단)**

**이유**:
1. ✅ Agent 체인 활성 시에만 차단 (스마트함)
2. ✅ 긴급 상황 허용 (체인 비활성 or 10분 경과)
3. ✅ 설정 파일 방해 없음
4. ✅ 코드 파일만 차단 (타겟 명확)

**적용 조건**:
```yaml
차단 (exit 1):
  - agent-chain-state.json 존재
  - 마지막 Agent 완료 10분 이내
  - 파일 확장자: .ts, .tsx, .js, .jsx

경고 (exit 0):
  - 체인 비활성 (state.json 없음)
  - 10분 경과 (긴급 상황 간주)
  - 설정 파일 (.json, .config.js 등)
```

---

## 🔧 구현 우선순위

### 즉시 적용 (Phase 1, 3)
- ✅ **Phase 1**: agent-complete.sh (다음 Task 알림) → 완료
- ✅ **Phase 3**: session-start-loader.sh (체인 복원) → 완료

### 조건부 적용 (Phase 2)
- ⏸️ **Phase 2**: pre-tool-use-agent-chain-guard.sh (조건부 차단)
  - 구현 전 **2주 테스트 기간** 권장
  - Phase 1 + 3 효과 측정 후 결정
  - False Positive 발생률 모니터링

---

## 📊 측정 지표 (Phase 1+3 효과)

### 2주 후 평가 항목
```yaml
긍정 지표:
  - Agent 체인 완료율: 현재 60% → 목표 85%+
  - 체인 중단 횟수: 주당 5회 → 목표 1회 이하
  - 다음 Task 자동 호출률: 목표 90%+

부정 지표:
  - 메인 세션 Write/Edit 사용 빈도: 주당 X회
  - 정당한 직접 구현 케이스: X%
  - Phase 2 False Positive 예상: Y%

의사 결정:
  - False Positive < 20% → Phase 2 Option 3 적용
  - False Positive > 30% → Phase 2 보류
  - 20-30% → Phase 2 Option 2 (경고만)
```

---

## 💡 Phase 2 대안: 교육적 접근

### Hook 대신 CLAUDE.md 강화
```yaml
현재 상태:
  - ✅ CLAUDE.md에 규칙 명시
  - ✅ Phase 1 알림 (다음 Task 자동 감지)
  - ✅ Phase 3 복원 (세션 복원)

추가 가능:
  - Pre-Hook: 사용자 입력 분석 시 "구현" 키워드 감지
    - "T003 구현" → "⚠️ code-writer Agent 호출하세요" (경고만)
  - Post-Hook: Agent 완료 시 다음 액션 제안
    - "✅ T002 완료 → Task(code-writer, T003) 호출"

효과:
  - 교육적 (규칙 학습)
  - 비침습적 (차단 없음)
  - 점진적 개선
```

---

## 🎯 결론 및 Next Steps

### 즉시 적용 ✅
1. **Phase 1 완료** (agent-complete.sh)
   - code-writer 완료 후 다음 Task 자동 알림
   - 체인 상태 JSON 저장

2. **Phase 3 완료** (session-start-loader.sh)
   - 세션 시작 시 Agent 체인 복원
   - 24시간 이내 체인 이어하기

### 평가 대기 ⏸️
3. **Phase 2 보류** (pre-tool-use-agent-chain-guard.sh)
   - **2주 테스트 기간**: Phase 1+3 효과 측정
   - **측정 항목**: 체인 완료율, 중단 횟수, False Positive
   - **의사 결정**: False Positive < 20% → Option 3 적용

### 대안 검토 💡
4. **교육적 접근** (Hook 대신)
   - user-prompt-submit.sh에 "구현" 키워드 감지 추가
   - 경고만 표시 (exit 0)
   - 사용자 학습 효과

---

## 📝 모니터링 체크리스트

**Phase 1 + 3 적용 후 2주간**:
```yaml
일주일 후 체크:
  - [ ] Agent 체인 알림 발생 횟수
  - [ ] 다음 Task 자동 호출 성공률
  - [ ] 세션 복원 성공 케이스
  - [ ] 메인 세션 직접 Write/Edit 빈도

2주 후 체크:
  - [ ] 체인 완료율 85% 달성 여부
  - [ ] 체인 중단 주당 1회 이하 달성 여부
  - [ ] Phase 2 필요성 재평가
  - [ ] False Positive 예상치 계산
```

---

## 🚀 최종 권장

**현재 적용 (2025-11-06)**:
- ✅ Phase 1: agent-complete.sh (체인 추적)
- ✅ Phase 3: session-start-loader.sh (세션 복원)

**2주 후 재평가 (2025-11-20)**:
- 📊 Phase 1+3 효과 측정
- 🔍 False Positive 분석
- 🎯 Phase 2 적용 여부 결정
  - Option 3 (조건부 차단) 또는
  - 교육적 접근 (경고만)

**장기 목표**:
- Agent 체인 완료율 95%+
- 메인 세션 UX 저하 없음
- 자연스러운 워크플로우 내재화
