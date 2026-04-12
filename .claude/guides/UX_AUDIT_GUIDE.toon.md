# UX Audit System Guide (TOON Format)

> Token-Optimized: ~60% 절약
> v1.0 | 2025-12-14

---

## 📊 아키텍처

```
ux-master-auditor (오케스트레이터)
    ├── ux-heuristic-auditor (Nielsen 10점)
    ├── ui-tester (WCAG 2.2)
    ├── ux-writer-auditor (UX 라이팅)
    └── cognitive-load-analyzer (심리학)
            ↓
    UX-AUDIT-REPORT.md
            ↓
    epic-creator → story → task → code → test
```

---

## 🚀 Quick Start

```bash
# 전체 감사
Task(subagent_type: "05-quality/ux-master-auditor", prompt: "URL: localhost:3000")

# 개별 실행
Task(subagent_type: "05-quality/ux-heuristic-auditor", ...)
Task(subagent_type: "04-implementation/ui-tester", ...)
Task(subagent_type: "05-quality/cognitive-load-analyzer", ...)

# Epic 생성
/epic-creator:create "UX 개선 - P0/P1"
```

---

## 📦 에이전트

[agents: name, role, output]
ux-heuristic-auditor, Nielsen 10 Heuristics, UX-HEURISTIC-AUDIT-REPORT.md
ui-tester, WCAG 2.2 AA 접근성, WCAG-AUDIT-REPORT.md
ux-writer-auditor, UX 라이팅/워딩 검사, UX-WRITING-AUDIT-REPORT.md
cognitive-load-analyzer, Hick/Fitts/Miller 법칙, COGNITIVE-LOAD-REPORT.md
ux-master-auditor, 4개 오케스트레이션, UX-AUDIT-REPORT.md

---

## 📋 Nielsen 10 Heuristics

[heuristics: id, name, check]
H1, 시스템 상태 표시, 로딩스피너;토스트알림
H2, 현실 세계 일치, 사용자언어;친숙한아이콘
H3, 사용자 제어, 취소버튼;Undo
H4, 일관성, 용어통일;스타일통일
H5, 오류 방지, 확인다이얼로그;유효성검사
H6, 인식>회상, 레이블명확;툴팁
H7, 유연성, 키보드단축키;개인화
H8, 미학적 최소주의, 불필요요소제거
H9, 오류 복구, 명확한에러메시지
H10, 도움말, 검색가능문서

[severity: score, level, priority]
0, 문제없음, -
1, Cosmetic, P3
2, Minor, P2
3, Major, P1
4, Catastrophic, P0

---

## ♿ WCAG 2.2 AA (신규 7개)

[wcag22: id, name, desc]
2.4.11, Focus Not Obscured, 포커스 가려지지 않음
2.4.13, Focus Appearance, 포커스 인디케이터 2px+
2.5.7, Dragging Movements, 드래그 대체 수단
2.5.8, Target Size (24px), 클릭영역 최소 24x24px ⭐
3.2.6, Consistent Help, 도움말 위치 일관성
3.3.7, Redundant Entry, 중복 입력 방지
3.3.8, Accessible Auth, 인지테스트 없는 인증

---

## 🧠 인지 부하 법칙

[laws: name, formula, recommendation]
Hick's Law, 결정시간 ∝ log₂(n+1), 선택지 ≤7개
Fitts's Law, 이동시간 ∝ 거리/크기, 버튼 ≥44px
Miller's Law, 기억용량 = 7±2, 그룹화 필수

---

## 📊 점수 체계

[weights: area, weight]
Nielsen 휴리스틱, 35%
WCAG 접근성, 35%
UX 라이팅, 15%
인지 부하, 15%

[grades: score, grade, status]
90+, A, 🏆우수
80-89, B, ✅양호
70-79, C, ⚠️개선필요
60-69, D, 🔶주의필요
<60, F, 🔴긴급개선

---

## 📄 출력 파일

[outputs: file, content]
UX-AUDIT-REPORT.md, 종합 (4개 통합)
UX-HEURISTIC-AUDIT-REPORT.md, Nielsen 상세
WCAG-AUDIT-REPORT.md, 접근성 상세
UX-WRITING-AUDIT-REPORT.md, UX 라이팅 상세
COGNITIVE-LOAD-REPORT.md, 인지 부하 상세

---

## 🔗 워크플로우

```
감사요청 → ux-master-auditor → UX-AUDIT-REPORT.md
         → epic-creator → story → task → code → ui-tester
         → ✅ Before/After 비교 완료
```

---

_TOON Format v1.0 | Original: 4,200 tokens → Compressed: ~1,700 tokens_
