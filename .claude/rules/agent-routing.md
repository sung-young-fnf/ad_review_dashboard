---
globs: ["**"]
---

## Agent Routing

### UX-First Development (MANDATORY)
> "사용자가 직접 경험하는가?"를 먼저 묻고, UX 관점으로 접근
> API 응답도, DB 스키마도, 에러 처리도 - 결국 사용자에게 영향을 준다

#### User Impact 경량 체크 (3초 판단)
1. **사용자가 이 결과를 직접 보거나 경험하는가?** (화면, 응답, 에러 메시지)
2. **사용자의 대기 시간에 영향을 주는가?** (성능, 로딩)
3. **사용자의 데이터 이해에 영향을 주는가?** (데이터 구조, 표현)

→ 하나라도 Yes: UX 관점 먼저 고려 → 모두 No: Quick Pass (순수 인프라)

#### UX Gateway 워크플로우
```
모든 사용자 요청
        ↓
┌─────────────────────────────────┐
│  User Impact 자문 (3초)          │
│  "사용자가 직접 경험하는가?"     │
└─────────────────────────────────┘
        ↓
   [Quick Pass?] ──Yes──→ 순수 인프라로 바로 진행
        │                 (CI/CD, Docker, K8s, 린터, 빌드설정)
        No
        ↓
   ┌─ UX Gateway: Yes ─────────────────────────────────────────┐
   │  ⚠️ Code-Change와 독립적으로 판단                          │
   │  기획/설계/분석도 UX 검토 대상 (AS-IS/TO-BE, 정보구조 등) │
   └────────────────────────────────────────────────────────────┘
        ↓
   [분류 결과]
   ├─ 🎨 frontend/ux → ux-master-auditor → AS-IS/TO-BE → code-writer → ui-tester
   ├─ 📋 기획/설계   → ux-heuristic-auditor (UX 관점 검토) → 계획 수립
   ├─ 🔧 backend    → UX 관점 고려 후 구현 (API 응답 = 사용자 경험)
   ├─ 🗄️ db/schema  → UX 관점 고려 후 구현 (데이터 = 표현 가능성)
   ├─ 🐛 에러 처리  → UX 관점 고려 후 구현 (에러 메시지 = 사용자 피드백)
   └─ ❓ unclear    → ux-heuristic-auditor (의도 상세 파악)
```

### 🔴 우선순위 규칙 + Agent 라우팅 (MANDATORY)

| 우선순위 | 조건 | Agent | 설명 |
|:--------:|------|-------|------|
| **0** | 🌐 모든 요청 (Universal Gateway) | ux-heuristic-auditor | 의도 분류 후 라우팅 |
| **1** | frontend/ux 분류됨 | ux-master-auditor | 전체 UX 분석 (4-Tier) |
| **2** | unclear (모호한 요청) | ux-heuristic-auditor | 상세 의도 파악 후 재라우팅 |
| 3 | bug/error | error-fixer | 병렬분석 |
| 4 | db/schema | db-code-writer | DB전용 |
| 5 | epic/대형 | epic-creator (+ Pre-Flight Scanner) | 새기능 |
| 5.1 | epic 기획 + Squad | planning-squad | 코드검증+UX보강 (5+ Story/크로스도메인/UX영향) |
| 5.2 | 사전분석 + Squad | analysis-squad | 7개 분석 Agent 병렬 (코드구조/품질/기술스택/비즈니스) |
| 5.3 | Task 설계 + Squad | design-squad | Task 분해+검증+플로우분석 병렬 (5+ Task/크로스도메인) |
| 5.4 | 품질 검증 + Squad | quality-squad | 4개 검증 Agent 병렬 (AC/성능/보안/단순성) |
| 6 | story/중형 | story-creator | API추가 |
| 7 | task/소형 | task-planner | 버그수정 |
| 8 | 코드구현 | code-writer | 실제구현 |
| 9 | 간단수정 | quick-modifier | 컨텍스트효율 |
| **10** | 🏋️ Squad 편성 | Teammate.spawnTeam | Hook SQUAD_SCALE≠SOLO 시 자동 편성 |
| - | Story검증 | story-validator | AC품질→의존성→필수섹션→story-creator 피드백 |
| - | Task검증 | task-validator | AC커버리지→순환의존성→크기→task-planner 피드백 |
| - | 코드검증 | implementation-validator | Task AC검증→API체인→DB컬럼→error-fixer loop |
| - | 성능검증 | performance-oracle | N+1/BigO/번들사이즈 전문분석 |
| - | 단순성검증 | code-simplicity-reviewer | YAGNI최종리뷰→LOC감소리포트 |
| - | 버그재현 | bug-reproduction-validator | error-fixer앞단→6가지분류 |
| - | 플로우분석 | spec-flow-analyzer | Story플로우완전성→permutation/gap발견 |
| - | 솔루션검색 | learnings-researcher | docs/solutions/검색→지식복리읽기 |
| - | **업계패턴리서치** | **Codex delegate (web_search)** | **인프라패턴 신규 도입 or fix 2건+ 반복 시 필수** |
| - | UI반복개선 | design-iterator | N회스크린샷→분석→1개개선→반복 |
| - | 커밋 | commit-manager | Git커밋 |
| - | 배포확인 | deployment-watcher | 백그라운드CI/CD모니터링(GitHub→ArgoCD→Datadog) |
| - | **버그진단** | `/diagnose` | 코드변경금지→근본원인분석→수정방안제시 |
| - | **TDD버그수정** | `/tdd-fix` | 진단→실패테스트→수정→통과까지 자율루프(최대3회) |
| - | **Epic실행** | `/epic-execute` | 풀 파이프라인(분석→기획→설계→구현→검증) 자동 실행 |
| - | **배포검증** | `/deploy-validate` | ArgoCD→Pod→Migration→Health→Metrics 6단계 |
| - | **학습 인사이트** | `/learning-insights` | Learning Loop 대시보드 HTML 보고서 + 브라우저 열기 |

#### Quick Pass 조건 (UX 고려 불필요)
CI/CD, GitHub Actions, ArgoCD, Docker, K8s, Helm, ESLint, Prettier, webpack, vite.config, tsconfig, 순수 리팩토링

#### UX 고려 필요 (Quick Pass 아님)
API 응답/에러, DB 스키마, 에러 처리, 성능 최적화, 로그/모니터링
