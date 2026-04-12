---
globs: ["**"]
---

## Auto-Proceed

[condition, agent, action]
🌐 모든 요청, ux-heuristic-auditor, 의도 분류→라우팅
🎨 frontend/ux, ux-master-auditor, 4-Tier 분석→code-writer
❓ unclear, ux-heuristic-auditor, 상세 파악→재분류
DRY위반 3곳+, task-planner, 상수통합
미사용 코드, code-writer, 즉시삭제
타입/테스트 에러, error-fixer, 즉시수정
story-creator 완료, story-validator, 자동검증→story-creator 피드백
**📋 🔴 Epic/Story .md 파일 생성 직후 Plannotator 검토 (BLOCKING)**, `plannotator annotate <파일>`, Epic 생성 → epic.md에 plannotator / Story 생성 → 첫 Story .md에 plannotator → **사용자 승인 전까지 다음 단계 진행 금지** (Task/구현은 검토 없이 자동). ❌ epic.md Write 후 plannotator 미실행 = VIOLATION
**🔍 구현 완료 후 Code Review**, `plannotator review`, 커밋 전 코드 diff 시각적 리뷰 (선택적 — 대형 변경 시)
task-planner 완료, task-validator, AC커버리지+의존성→task-planner 피드백
code-writer 완료, implementation-validator, 자동검증→error-fixer loop
code-writer(UI) 완료, ui-tester, Before/After 비교검증
**🔄 규칙 위반 발견 / 2회+ 반복 실수 / 새 패턴 발견**, `/compound`, docs/solutions/에 솔루션 문서화 (지식 복리)
**🔍 유사 작업 시작**, learnings-researcher, docs/solutions/ 사전 검색 (지식 복리 읽기)
**⚡ 사용자 실수 지적**, Mistake Feedback Loop, 즉시중단→5Why원인분석→교훈저장→개선된방법재작업
**🔄 2번째 시도에 성공**, Second-Try Retro, 1차실패원인분석→프로세스개선→규칙추가
**🐛 버그 리포트 접수**, `/diagnose` → bug-reproduction-validator, 진단우선→재현→분류→error-fixer 위임
**🐛 버그 수정 시작 (코드 변경 필요)**, `/tdd-fix` (기본 권장), 진단→실패테스트→수정→통과 자율루프(최대3회)
**🧪 테스트 기반 버그 수정**, `/tdd-fix`, 진단→실패테스트→수정→통과 자율루프(최대3회)
**📊 성능 관련 기능**, performance-oracle, N+1/BigO/번들 전문 분석 (선택적)
**✂️ 100줄+ 구현 완료**, code-simplicity-reviewer, YAGNI 최종 검토 (선택적)
**🎨 UI 결과물 부족**, design-iterator, N회 반복 개선 (ux-master-auditor 후)
**📝 같은 파일 3회+ 수정 감지 (Hook)**, 즉시 ref 주석 추가, 해당 파일 핵심 지점에 `# ⚠️` + `# ref:` 커밋 해시 주석 삽입 후 커밋
**🔬 같은 영역 fix 2건+ 누적**, Codex delegate (web_search), 패치 대신 업계 패턴 리서치 → 근본 해결 (인증/캐싱/큐/스케줄링)
P0 이슈, error-fixer, 즉시수정
SQUAD_SCALE≠SOLO, Teammate.spawnTeam, Squad 자동 편성→Lead 미션 브리핑
Squad 완료, Teammate.cleanup, 전원 shutdown_request→cleanup
**제안만**: 새기능, 아키텍처변경, DB스키마변경
**📐 Epic/Story 기획 시작**, Pre-Flight Scanner → (조건부) Planning Squad, 코드 전수 검사→UX AC 보강→문서 생성
**🔬 Epic 구현 전 분석**, analysis-squad, 7개 사전분석 Agent 병렬→통합 보고서→구현 전략
**📐 대형 Story Task 설계**, design-squad, Task 분해+검증+플로우분석 병렬→설계 확정
**✅ 구현 완료 품질 검증**, quality-squad, AC+성능+보안+단순성 병렬 검증→품질 판정
**🚀 Epic 실행**, `/epic-execute`, 풀 파이프라인(분석→기획→설계→구현→검증) 자동 실행
**📦 푸시 후 배포**, `/deploy-validate`, 6단계자동검증(ArgoCD→Pod→DB→Health→Metrics)
**🧠 학습 현황 확인**, `/learning-insights`, Learning Loop HTML 대시보드 생성+브라우저 열기
