# Design Diverge Skill

> **Verbalized Sampling 기반 창의적 UI/UX 제안 생성**
> Stanford 연구 (arXiv:2510.01171) - Mode Collapse 방지, 다양성 1.6~2.1배 향상

---

## 🎯 목적

AI가 생성하는 **뻔한 디자인 패턴을 방지**하고 창의적인 UI/UX 해결책을 제안합니다.

### 문제 (Mode Collapse)
- 보라색-파란색 그라데이션
- shadcn/ui 기본 스타일 그대로
- 카드 그리드 3열 배치
- 회전 스피너 로딩
- 모달 하단 [취소] [확인] 패턴

### 해결책 (VS Design Diverge)
1. 먼저 "가장 뻔한 선택" 출력
2. 그 뻔한 것을 금지 (BLACKLIST)
3. 창의적 대안 + 신뢰도 점수 생성
4. 품질 가드레일 통과 검증

---

## ⚡ 사용법

### 기본 호출
```bash
# UI/UX 개선 제안 시 자동 활성화
/design-diverge

# 특정 컴포넌트에 적용
/design-diverge --component "login-form"

# 특정 문제에 적용
/design-diverge --issue "12개 폼 필드 인지 과부하"
```

### 자동 트리거
다음 상황에서 자동으로 VS Protocol이 활성화됩니다:
- `ux-heuristic-auditor` TO-BE 생성 시
- `ux-master-auditor` Tier 5 Diverge Phase
- `cognitive-load-analyzer` 개선안 제안 시
- `code-writer` UI 컴포넌트 구현 시

---

## 📋 VS Protocol 3단계

### STEP 1: BLACKLIST 생성
```
┌─────────────────────────────────────────────────────────────────┐
│ 🚫 BLACKLIST - 금지된 뻔한 제안들                               │
├─────────────────────────────────────────────────────────────────┤
│ 1. 보라색-파란색 그라데이션 배경                                │
│ 2. shadcn/ui Button variant="default" 그대로                    │
│ 3. 카드 컴포넌트 3열 그리드 배치                                │
│ 4. 회전 스피너 (Spinner) 로딩                                   │
│ 5. 모달 하단 [취소] [확인] 버튼 배치                            │
│ 6. 스텝 위자드 3단계 분리 (폼 개선)                             │
│ 7. 햄버거 메뉴 (모바일 네비게이션)                              │
└─────────────────────────────────────────────────────────────────┘
```

### STEP 2: 창의적 대안 생성
```
┌─────────────────────────────────────────────────────────────────┐
│ ✨ 창의적 대안 (with 신뢰도 점수)                               │
├─────────────────────────────────────────────────────────────────┤
│ 1. Progressive Disclosure + AI 자동완성           [87%] ⭐      │
│ 2. Conversation UI 전환                           [72%]         │
│ 3. Smart Default + 편집 모드                      [81%]         │
│ 4. Command Palette (⌘K) 기반 탐색                 [85%]         │
│ 5. Adaptive Navigation (사용자 행동 기반)         [78%]         │
└─────────────────────────────────────────────────────────────────┘
```

### STEP 3: 품질 가드레일 검증
```javascript
function passesQualityGate(solution) {
  return (
    solution.nielsenScore >= 3 &&        // Nielsen 3점 이상
    solution.wcagCompliant === true &&    // WCAG 2.2 AA 준수
    solution.cognitiveLoad <= 5 &&        // 인지 부하 5점 이하
    solution.confidence >= 0.6            // 60% 이상 신뢰도
  )
}
```

---

## 🎨 카테고리별 BLACKLIST

### 색상/스타일
```yaml
blacklist:
  - 보라색-파란색 그라데이션
  - shadcn/ui 기본 primary 색상
  - 무채색 회색 계열만 사용
  - CSS 글로벌 리셋만 적용

creative_alternatives:
  - 브랜드 컬러 + 보색 대비
  - 다크모드 시 컬러 변환 (not invert)
  - 컨텍스트 기반 동적 색상
```

### 레이아웃
```yaml
blacklist:
  - 카드 그리드 3열 배치
  - 왼쪽 사이드바 + 오른쪽 콘텐츠
  - 상단 네비게이션 바 고정

creative_alternatives:
  - Bento Grid (다양한 크기 혼합)
  - Full-width 스크롤 섹션
  - Command-driven UI (⌘K)
  - Adaptive layout (사용 패턴 기반)
```

### 폼/입력
```yaml
blacklist:
  - 수직 나열 레이블 + 입력 필드
  - 빨간색 에러 메시지
  - 별표(*) 필수 표시
  - 스텝 위자드 분리

creative_alternatives:
  - Progressive Disclosure (필요한 필드만)
  - Inline validation with suggestions
  - Conversation UI 방식
  - Smart Default + 편집 모드
```

### 로딩/상태
```yaml
blacklist:
  - 회전 스피너
  - 기본 스켈레톤 UI
  - 프로그레스 바

creative_alternatives:
  - Content-aware skeleton (실제 구조 반영)
  - Optimistic UI (즉시 반영 후 동기화)
  - Progressive image loading (blur → sharp)
  - Background prefetching
```

### 버튼/CTA
```yaml
blacklist:
  - 오른쪽 정렬 Primary 버튼
  - 모달 하단 [취소] [확인] 배치
  - hover 시 배경색 약간 어둡게

creative_alternatives:
  - 컨텍스트 기반 버튼 위치
  - Inline actions (테이블 행 내)
  - Floating action button (FAB) with context
  - Gesture-based actions (스와이프)
```

---

## 📝 출력 형식

### TO-BE 제안 템플릿
```markdown
## Issue: [문제 설명]

### 🚫 금지된 뻔한 해결책
1. ~~[뻔한 해결책 1]~~ - [금지 이유]
2. ~~[뻔한 해결책 2]~~ - [금지 이유]
3. ~~[뻔한 해결책 3]~~ - [금지 이유]

### ✨ 창의적 대안 (with 신뢰도)

| # | 제안 | 신뢰도 | Nielsen | WCAG | 인지부하 | 선택 |
|---|------|--------|---------|------|----------|------|
| 1 | **[최적 해결책]** | 87% | 4/4 | ✅ | 3.2 | ⭐ |
| 2 | [대안 2] | 81% | 4/4 | ✅ | 3.8 | |
| 3 | [대안 3] | 72% | 3/4 | ✅ | 4.1 | |

### AS-IS → TO-BE (창의적)

\`\`\`
AS-IS:                              TO-BE (VS Protocol):
┌────────────────────┐              ┌────────────────────────┐
│ [뻔한 구조]        │      →      │ [창의적 구조]          │
│                    │              │ AI 추천: [...]         │
│                    │              │ 컨텍스트 기반 UI       │
└────────────────────┘              └────────────────────────┘
\`\`\`

### 구현 가이드
\`\`\`tsx
// [코드 스니펫]
\`\`\`

### 예상 효과
| 지표 | Before | After | 개선율 |
|------|--------|-------|--------|
| [지표 1] | [값] | [값] | [%] |
```

---

## 🔗 연관 Agent

| Agent | VS 적용 위치 | 설명 |
|-------|-------------|------|
| ux-heuristic-auditor | Section 4 | TO-BE 생성 시 |
| ux-master-auditor | Tier 5 | Diverge Phase |
| cognitive-load-analyzer | Section 6 | 개선안 제안 시 |
| code-writer | UI 구현 시 | 컴포넌트 스타일링 |

---

## 📚 참조

- [Stanford VS Research](https://github.com/CHATS-lab/verbalized-sampling) - arXiv:2510.01171
- [Nielsen Norman Group](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [WCAG 2.2](https://www.w3.org/WAI/WCAG22/quickref/)

---

_Version: 1.0 - Verbalized Sampling Design Diverge Skill_
_Author: Claude Code Agent System_
