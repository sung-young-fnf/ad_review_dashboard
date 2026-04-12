---
globs: [".claude/squads/**"]
---

## Squad Operations

> 상세: @.claude/squads/README.md

### Scale 판단 기준 (키워드 매칭)

```
EPIC         "시스템", "플랫폼", "아키텍처", "대형", 명시적 Epic 요청
PLANNING     "기획 스쿼드", "planning squad", "에픽 생성 스쿼드", "스토리 생성 스쿼드"
ANALYSIS     "사전분석", "전수분석", "코드분석 스쿼드", "analysis squad"
DESIGN       "설계 스쿼드", "design squad", "task 분해 스쿼드"
QUALITY      "품질 검증", "quality squad", "릴리즈 검증", "전수 검증"
STORY        "기능 추가", "API", "컴포넌트", "통합", 200자+ 설명
BUG_CRITICAL "긴급" + ("버그"|"에러"|"장애"|"다운")
DB           "스키마", "마이그레이션", "DDL", "테이블"
UX           ("ux"|"frontend") + ("개선"|"감사"|"분석")
SOLO         Code-Change minor(1-4줄) 또는 사용자 "solo만" 명시
```

키워드 매칭 순서: EPIC > PLANNING > ANALYSIS > DESIGN > QUALITY > BUG_CRITICAL > DB > UX > STORY > SOLO
**기본 Fallback**: 키워드 미매칭 + Code-Change major → **STORY Squad** (SOLO 아님)

### SOLO vs Squad 판단

| 모드 | 조건 | 비용 |
|------|------|------|
| **Solo** | Code-Change minor(1-4줄) 또는 사용자 "solo만" 명시 | 1x |
| **Squad + multi-model** (기본값) | 나머지 모든 요청 | 2-4x |

**Squad + multi-model이 기본값이다.** Codex/Gemini가 항상 참여한다.

### Non-Delegation Signals (Squad 조건 충족해도 Solo 다운그레이드)
> 상세: @.claude/squads/README.md "Non-Delegation Signals" 참조

- **Blocking Dependency**: 다음 액션이 위임 결과에 blocked → Solo
- **Same File Ownership**: 같은 파일을 여러 Agent가 수정 → Solo (순차)
- **Unframed Problem**: 문제 정의 불명확 → Solo (프레이밍 먼저)
- **Faster Alone**: 편성+통합 overhead > 단독 실행 시간 → Solo
- **Main Thread Idle**: 위임 후 병렬 작업 없음 → Solo

### +multi-model (기본값: 항상 활성)

Squad 편성 시 **일부 역할에 Codex/Gemini delegate를 자동 배치**한다.

| 영역 | 추천 모델 | 이유 |
|------|----------|------|
| 계획/설계/아키텍처 | Claude (Opus) | 구조적 사고 + 코드베이스 직접 접근 |
| UI/UX 시각 분석 | Gemini | 멀티모달 이미지 이해 강점 |
| 대규모 코드 분석 | Gemini Pro | 100만 토큰 컨텍스트 |
| 깊은 코드 디버깅 | Codex (o3/o4) | 코드 추론 체인 |
| 웹 리서치/최신 정보 | Codex (web_search) | 실시간 웹 검색 |
| 코드 생성/편집 | Claude | 코드베이스 직접 접근 + 파일 편집 |

**🔴 Claude 최종 판단 필수**: Codex/Gemini 결과를 Claude가 검증 후 채택. 무조건 수용 금지.

### 규모별 스쿼드 편성표

| 규모 | 스쿼드 | 팀원 수 |
|------|--------|--------|
| EPIC | epic-squad | 4명 (architect + dev x2 + reviewer) |
| PLANNING | planning-squad | 2-3명 (planner + code-scanner + ux-advisor) |
| ANALYSIS | analysis-squad | 3-4명 (coordinator + analyzers) |
| DESIGN | design-squad | 2-3명 (architect + validators) |
| QUALITY | quality-squad | 3-4명 (lead + checkers) |
| STORY | story-squad | 2-3명 (tech-lead + dev) |
| BUG_CRITICAL | bug-squad | 2명 (investigator x2) |
| DB | db-squad | 2명 (architect + dev) |
| UX | ux-squad | 3명 (analyst + dev + verifier) |

> 편성 상세, Lifecycle, Worktree, Merge 프로토콜 등: @.claude/squads/README.md 참조
