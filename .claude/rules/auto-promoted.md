---
globs: ["**"]
---

# Auto-Promoted Rules

> Learning Loop에서 반복 3회 이상 감지되어 자동 승격된 규칙들.
> self-improve-recorder.sh가 자동으로 추가합니다. 수동 편집 가능.

## Knowledge Lifecycle (Sirchmunk 패턴 적용)

> 각 규칙은 lifecycle 상태를 가지며, 시간과 참조 빈도에 따라 진화합니다.

| Lifecycle | 조건 | Agent 행동 |
|-----------|------|-----------|
| **EMERGING** | 신규 생성, Count < 3 | 참고만 (강제 아님) |
| **STABLE** | Count 3+ 또는 수동 승격 | Phase 0에서 필수 참조 |
| **CONTESTED** | 사용자가 규칙을 반박/교정 | 재검증 필요 표시, 조건부 적용 |
| **DEPRECATED** | 30일+ 미참조 또는 수동 폐기 | Phase 0에서 무시 (삭제 후보) |

**필드 설명:**
- **Lifecycle**: EMERGING / STABLE / CONTESTED / DEPRECATED
- **Confidence**: 성공 적용 횟수 / 전체 참조 횟수 (0.0~1.0)
- **Last-Active**: 마지막으로 이 규칙이 트리거된 날짜

---

## [2026-03-07] Soul Proxy DNS 에러 (누적 30회+)
- **Pattern**: `[Soul Proxy] Created MCP proxy → http://orbit-agent-backend:8001` (short DNS) + `soul_update ERROR: fetch failed`
- **Rule**: Soul Proxy 설정 시 FQDN 사용 필수 (`orbit-agent-backend.namespace.svc.cluster.local:8001`)
- **Source**: ERRORS.md 자동 감지 (2026-03-06~07 반복, 중복 18건 통합)
- **Lifecycle**: STABLE
- **Confidence**: 0.95 (30회+ 관찰)
- **Last-Active**: 2026-03-07

## [2026-03-07] Explore Agent 타임아웃 (누적 20회+)
- **Pattern**: 5분마다 만료된 pause 검사, defaultValue로 재개 또는 FAILED
- **Rule**: Explore Agent 실행 시 타임아웃 핸들링 사전 확인 필수
- **Source**: ERRORS.md 자동 감지 (2026-03-06~07 반복, 중복 3건 통합)
- **Lifecycle**: STABLE
- **Confidence**: 0.90 (20회+ 관찰)
- **Last-Active**: 2026-03-07

## [2026-03-07] 사용자 교정 반복 승격
- **Rule**: dev 서버 자동 출력 ("[Fast Refresh]", "[HMR]", "compiled") 은 사용자 교정이 아님 — Hook 필터링 필요
- **Source**: LEARNINGS.md (Count 3+)
- **Lifecycle**: STABLE
- **Confidence**: 0.80
- **Last-Active**: 2026-03-07

<!-- REMOVED: [2026-03-07] unknown 반복 에러 — DEPRECATED, Soul Proxy DNS 에러 규칙에 통합됨 -->

## [2026-03-07] 실행 가능한 지침 수정 시 즉시 테스트 필수
- **Pattern**: watch.md/스크립트 등 실행 가능한 명령어를 문서에 수정 후 테스트 없이 "완료" 보고
- **Rule**: 실행 가능한 코드/명령어를 문서에 수정했으면 → 즉시 실행 테스트 후 결과 확인 필수
- **Source**: LEARNINGS.md (Count 3+) — cmux surface parsing 수정 후 미테스트로 빈 탭 생성
- **Lifecycle**: STABLE
- **Confidence**: 0.85
- **Last-Active**: 2026-03-07

<!-- REMOVED: [2026-03-07] Explore 반복 에러 — DEPRECATED, Explore Agent 타임아웃 규칙에 통합됨 -->

## [2026-03-08] 모노레포 앱별 설정 우선 참조
- **Rule**: 에러 발생 시 해당 앱 디렉토리(apps/{app}/)의 기존 설정/스크립트를 먼저 확인 — 루트가 아닌 앱 기준으로 판단
- **Source**: LEARNINGS.md (Count 4)
- **Lifecycle**: STABLE
- **Confidence**: 0.85
- **Last-Active**: 2026-03-08

## [2026-03-12] UI 컴포넌트 렌더링 검증 필수 (Insights 기반 승격)
- **Rule**: UI 수정 전 Route→Page→Component 하향식 추적으로 실제 렌더되는 컴포넌트인지 확인 필수
- **Source**: Insights 분석 (wrong_approach 82건 중 컴포넌트 오인 다수)
- **Lifecycle**: STABLE
- **Confidence**: 0.90 (82건 마찰 이벤트 근거)
- **Last-Active**: 2026-03-12

## [2026-03-12] Datadog 로그 쿼리 3회 제한 (Insights 기반 승격)
- **Rule**: 로그 조사 시 좁은 범위(서비스명+15분)로 시작, 3회 시도 후 중간 보고 필수
- **Source**: Insights 분석 (과도한 쿼리 반복으로 세션 시간 낭비)
- **Lifecycle**: STABLE
- **Confidence**: 0.85
- **Last-Active**: 2026-03-12

## [2026-03-12] 버그 리포트 ≠ 사용자 교정 (Hook false positive 수정)
- **Rule**: "오류 확인해줘", "에러 해결해줘"는 버그 리포트(진단 요청)이며 사용자 교정이 아님 — Hook 필터링 적용
- **Source**: Insights + LEARNINGS.md 오탐 분석 (16건 중 12건이 false positive)
- **Lifecycle**: STABLE
- **Confidence**: 0.95 (12건 오탐 근거)
- **Last-Active**: 2026-03-12

## [2026-03-13] 사용자 교정 반복 승격
- **Rule**: (to be filled by agent after analysis)
- **Source**: LEARNINGS.md (Count 3+)

## [2026-03-24] Tool→Service 호출 시 Consumer 필터 필드 누락 방지
- **Pattern**: MCP Tool이 Service.create()를 호출할 때 context에 있는 sessionId 등을 DTO에 전달하지 않아, DB에 null로 저장되고 프론트엔드 필터에서 누락됨
- **Rule**: Tool→Service 호출 시 프론트엔드가 조회/필터링에 사용하는 필드(sessionId, reuseSession 등)를 반드시 DTO에 포함. "API 성공 ≠ 기능 동작" — 소비자(프론트엔드) 조회 로직까지 추적 필수
- **Source**: schedule-task.tool.ts sessionId 누락 버그 (2026-03-24)
- **Lifecycle**: STABLE
- **Confidence**: 0.90
- **Last-Active**: 2026-03-24

## [2026-04-12] Subagent Stream Idle Timeout 예방 (EP228 사례)
- **Pattern**: 대형 코드 생성(파일 3개+)을 단일 agent 턴에서 시도 → API Stream idle timeout → agent 강제 종료 → 작업 손실
- **Rule**: 구현 agent는 **한 턴에 파일 2개 이하** 생성. 3개+ 파일이 필요하면 파일별 Task 분할 또는 중간 커밋 후 다음 턴 진행. 분석 결과는 praetorian으로 압축 후 구현 agent에 전달 (컨텍스트 감소 → timeout 확률 감소)
- **Source**: EP228-S02 agent 실패 분석 — `abcaf7ae` agent가 SessionWakeService + Orchestrator 통합을 한 턴에 생성 중 timeout (2026-04-12T06:33:46Z)
- **Hook**: `stream-timeout-guard.sh` — SubagentStop에서 자동 감지 + stderr 경고 + retry 마커 생성
- **Lifecycle**: EMERGING
- **Confidence**: 0.70 (1회 관찰, 재발 시 STABLE 승격)
- **Last-Active**: 2026-04-12
