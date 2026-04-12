---
name: debate
description: "Claude × Codex 라운드제 토론으로 편향 없는 결론 도출"
effort: medium
---

# /debate — Claude × Codex 라운드제 토론

> 두 AI가 동등한 피어로 토론하여 편향 없는 결론을 도출한다.

## 사용법

```
/debate 이 책의 Part 구조가 최선인가?
/debate --rounds 4 FSD vs 다른 프론트엔드 구조 비교
/debate --search 토큰 관리 보안 방안
/debate -m o3 AI 코딩 도구 시장에서 우리 책의 포지셔닝
```

### 옵션

| 플래그 | 설명 | 기본값 |
|--------|------|--------|
| `--rounds <N>` | 최대 라운드 수 (3~5) | 3 (독립분석 + 반론 + 재반론) |
| `--search` | Codex 웹 검색 활성화 | off |
| `-m <model>` | Codex 모델 오버라이드 | codex 기본 모델 |
| `--dir <path>` | 분석 대상 디렉토리 | 현재 워크스페이스 |

## 동작

**cowork-squad** (3인)를 편성하여 라운드제 토론을 진행한다.

### 라운드 구조

```
Round 1: 독립 분석 (병렬)
  ├─ Claude Analyst: 워크스페이스 직접 탐색 + 자체 분석
  └─ Codex Analyst: codex exec로 독립 분석

Round 2: 교차 반론 (병렬)
  ├─ Claude: Codex R1을 읽고 동의/반박
  └─ Codex: Claude R1을 읽고 동의/반박

Round 3: 재반론 (필요 시, 병렬)
  ├─ Claude: Codex R2 반박에 재반론 또는 수용
  └─ Codex: Claude R2 반박에 재반론 또는 수용

최종: 합의 도출 (Moderator)
  └─ 합의점 + 미합의점(양쪽 입장 병기) + 권고안
```

### 재반론 판정 기준

Round 2 완료 후, moderator가 아래 기준으로 Round 3 진행 여부를 판단:

- **재반론 진행**: 한쪽이라도 강하게 반박하여 쟁점이 남아있을 때
- **바로 합의**: 양쪽 모두 상대 의견을 대부분 수용했을 때
- **추가 라운드(4+)**: `--rounds` 지정 + 아직 쟁점이 해소되지 않았을 때

### 실행 상세

#### 1. 토론 세션 초기화

```bash
DEBATE_ID=$(date +%s)
mkdir -p /tmp/debate-${DEBATE_ID}
```

#### 2. Round 1 — 독립 분석 (병렬)

**Claude Analyst** (Task → general-purpose):
- 워크스페이스에서 토픽 관련 파일을 직접 읽고 분석
- 결과를 `/tmp/debate-{id}/round1-claude.md`에 저장

**Codex Analyst** (Task → general-purpose → codex exec):
```bash
codex exec [-c 'web_search="live"'] -s read-only --ephemeral --skip-git-repo-check \
  -C {workspace} \
  -o /tmp/debate-{id}/round1-codex.md \
  "[프레이밍된 프롬프트]"
```

#### 3. Round 2 — 교차 반론 (병렬)

양측에 상대방 Round 1 결과를 전달하고 반론을 요청한다.

**Claude**: `/tmp/debate-{id}/round1-codex.md` 읽기 → 동의/반박 → `round2-claude.md`
**Codex**: Claude R1을 프롬프트에 포함 → codex exec → `round2-codex.md`

#### 4. Round 3 — 재반론 (조건부, 병렬)

Round 2에서 쟁점이 남아있으면 진행. 구조는 Round 2와 동일하되 상대의 Round 2 결과에 반응.

**Claude**: `round2-codex.md` 읽기 → 재반론/수용 → `round3-claude.md`
**Codex**: Claude R2를 프롬프트에 포함 → codex exec → `round3-codex.md`

#### 5. 최종 — 합의 도출 (Moderator)

전체 라운드 파일을 읽고 종합:

```
# 토론 결과: {토픽}

## 합의 사항
- [양측 동의한 결론들]

## 미합의 사항
| 항목 | Claude 입장 | Codex 입장 | 근거 차이 |

## 권고안
- [moderator의 종합 판단]

## 라운드별 하이라이트
### Round 1: [각자의 핵심 주장]
### Round 2: [주요 반박 포인트]
### Round 3: [입장 변화 또는 고수]
```

## 완료 조건

- 최소 Round 1 + Round 2 완료
- 합의점/미합의점이 구분되어 정리됨
- moderator가 최종 권고안 제시
- 임시 파일(`/tmp/debate-{id}/`) 정리

## 참조

- Squad 템플릿: `.claude/squads/templates/cowork-squad.yaml`
- 역할 정의: `.claude/squads/roles/moderator.md`, `debater-claude.md`, `debater-codex.md`
- Codex Agent: `.claude/agents/codex-delegate.md`
