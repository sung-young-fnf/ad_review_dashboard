---
agent: 99-utils/proactive-assistant
model: haiku
description: "전용 세션에서 실행되는 능동적 개발 도우미. Epic/Task 진행 상황, 커밋 분석, UX 이슈를 모니터링하고 Teams로 알림."
---

# Proactive Assistant Skill

> 코드베이스 상태 분석 + 전문 Agent 위임 + 종합 리포트

## Usage

```bash
# 1회 전체 분석
/proactive-assistant analyze

# 5분 간격 반복 모니터링
/proactive-assistant watch

# 특정 영역만 분석
/proactive-assistant focus epic     # Epic 진행 상황
/proactive-assistant focus commit   # 최근 커밋 분석
/proactive-assistant focus ux       # UX 인사이트
/proactive-assistant focus quality  # 품질 지표
```

## Architecture

```
proactive-assistant (Haiku) - 경량 오케스트레이터
|
+-- ux-master-auditor (Opus)      - UX 인사이트
+-- post-commit-suggester (Opus)  - 기능 제안
+-- implementation-validator (Opus) - 품질 체크
+-- file-analyzer (Haiku)         - 단순 요약
```

## Execution

### analyze (기본)

1. **상태 수집** (Haiku 직접)
   - git status, git log
   - PROGRESS.md
   - 미완료 Task 스캔
   - 빌드/타입 상태

2. **전문 Agent 위임** (조건부)
   - UI 파일 3개+ 변경 -> ux-master-auditor
   - feat 커밋 존재 -> post-commit-suggester
   - 빌드 에러 -> implementation-validator

3. **결과 종합**
   - P0 Critical -> Teams 알림
   - P1 Warning -> Serena Memory 저장
   - P2 Info -> 콘솔 출력

### watch

```bash
# 5분마다 git status 해시 비교
# 변경 감지 시에만 분석 실행 (리소스 절약)
```

### focus [area]

```bash
# epic: Epic 진행 상황 + 미완료 Task
# commit: 최근 커밋 분석 + 제안
# ux: UI 파일 변경 + Nielsen/인지부하
# quality: 빌드/타입/테스트 상태
```

## Output

```
===============================================
PROACTIVE ASSISTANT REPORT
===============================================
Timestamp: 2026-01-29T10:30:00Z

## Epic Progress
- Active: EP090 - Chat Session Agent Restore
- Completed: 2/5 Tasks
- Blockers: 0

## Recent Commits
- feat: 3
- fix: 1
- refactor: 1

## UX Insights
- Nielsen Score: 78/100
- P0: 0, P1: 2

## Feature Suggestions
1. [B1] Agent 즐겨찾기 기능
2. [CODE] 상태 상수 통합

## Quality
- TypeScript: 0 errors
- Build: OK

## Recommended Actions
1. P1 UX 이슈 확인
2. Task T003 시작

Notification: None
===============================================
```

## Configuration

```bash
# Teams 채널 설정 (환경변수)
export TEAMS_CHANNEL="dev-alerts"

# 자동 실행 비활성화
export PROACTIVE_ASSISTANT_ENABLED=false
```

## Related

- Agent: `.claude/agents/99-utils/proactive-assistant.md`
- Memory: `serena/proactive-assistant/*`
