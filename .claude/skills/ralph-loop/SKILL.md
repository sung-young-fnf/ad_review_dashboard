---
name: ralph-loop
user-invocable: true
auto-detect: true
effort: low
triggers:
  activate: [수정, 고쳐, fix, 버그, bug, 구현, 만들어, 추가, add, implement, 리팩토링, refactor, 개선, 업데이트, update, 변경, change, 삭제, delete, remove, 생성, create]
  skip: [찾아, 분석, 뭐야, 어디, 설명, 알려, 검색, 조회, 확인해봐, 봐봐, what, where, how, why, explain, show, list]
  disable_flag: --no-guarantee
description: |
  완료 보증 메커니즘 - 모든 작업 완료까지 중단 금지
  Auto-detect: 완료 필요 키워드 감지 시 자동 활성화
  Manual triggers: ralph-loop, --guarantee, --until-done
  Use when: 완료가 필수인 작업
---

# Ralph Loop - 완료 보증 시스템

> "Boulder does not rest until it reaches the summit." - Sisyphus Pattern

## 신성한 계약 (Sacred Contract)

Ralph Loop이 활성화되면 **반드시** 모든 작업을 완료해야 합니다.
완료 선언은 오직 `<promise>DONE</promise>` 태그로만 가능합니다.

## 활성화 방법

### 자동 감지 (기본)

Hook이 사용자 입력에서 키워드를 분석하여 자동으로 활성화합니다.

**활성화 우선순위:**
```
1. --no-guarantee 플래그 있음? → OFF
2. 조사/분석 키워드만 있음? → OFF
3. 완료 필요 키워드 있음? → ON (자동)
4. Task/Story 참조 감지? → ON (자동)
5. 기타? → OFF (기본)
```

**자동 활성화 시 표시:**
```
🔄 완료 보증 모드 자동 활성화
   └─ 작업 완료까지 중단되지 않습니다
   └─ 끄려면: --no-guarantee
```

### 수동 활성화

```bash
# 명시적 활성화
/ralph-loop start

# 자동 활성화 키워드
"--guarantee", "--until-done", "ralph-loop"
```

### 비활성화

```bash
# 자동 감지 무시
"수정해줘 --no-guarantee"
```

## 검증 프로토콜 (필수)

완료 선언 전 **반드시** 다음 순서를 따릅니다:

### Step 1: 타입 검증
```bash
pnpm tsc --noEmit
```
- 에러 0개 필수
- 에러 있으면 완료 선언 불가

### Step 2: 완료 선언
```xml
<promise>DONE</promise>
```
- 이 태그 없이는 세션 종료 불가
- Hook이 자동으로 검증

## 상태 파일

`.sisyphus/ralph.json`:
```json
{
  "active": true,
  "started_at": "2025-01-14T12:00:00Z",
  "incomplete_count": 0,
  "todos": []
}
```

## 금지사항

| 표현 | 상태 |
|------|------|
| "거의 완료됐습니다" | VIOLATION |
| "나머지는 다음에" | VIOLATION |
| "대부분 구현됐습니다" | VIOLATION |
| 검증 없는 완료 선언 | VIOLATION |

## 취소 방법

정말로 중단이 필요하면:
```bash
/cancel-ralph
```

## 워크플로우

```
1. Ralph Loop 활성화
   ↓
2. 작업 수행 (모든 TODO 완료)
   ↓
3. 검증 프로토콜 실행
   - pnpm tsc --noEmit
   ↓
4. 완료 선언
   - <promise>DONE</promise>
   ↓
5. Hook 검증 통과
   ↓
6. 세션 정상 종료
```

## 이중 보증 패턴 — Monitor (권장) + `/loop` (레거시)

Ralph Loop의 Stop hook은 non-blocking 경고만 합니다. Monitor 또는 `/loop`를 결합하면 **능동적 heartbeat**로 강화됩니다.

### Monitor 기반 (권장 — 토큰 절감)

```bash
# 1) Ralph Loop 활성화 (기존 — 멈출 때 경고)
/ralph-loop start

# 2) Monitor 추가 (신규 — 미완료 이벤트 감지)
Monitor({
  description: "Ralph 미완료 작업 감시",
  persistent: true,
  command: '''
    while true; do
      if [ -f .claude/ralph.json ]; then
        COUNT=$(jq ".incomplete_count // 0" .claude/ralph.json 2>/dev/null) || COUNT=0
        if [ "$COUNT" -gt 0 ]; then
          NAMES=$(jq -r ".incomplete_tasks[:3] | .[] // empty" .claude/ralph.json 2>/dev/null) || true
          echo "INCOMPLETE: ${COUNT}개 — ${NAMES}"
        fi
      fi
      sleep 120
    done
  '''
})
# → 알림 수신 시 메인 스레드가 미완료 작업 이어서 진행
```

### `/loop` 기반 (LLM 자동 행동 필요 시)

```bash
/ralph-loop start
/loop 2m "ralph.json의 incomplete_count를 확인하고, 미완료 작업이 있으면 계속 진행해"
```

| 계층 | 메커니즘 | 역할 |
|------|---------|------|
| Stop hook | ralph-loop-enforcer.sh | 멈추려 할 때 경고 (수동적) |
| Monitor | 셸 스크립트 감시 | 미완료 감지 시 알림 (이벤트 기반) |
| `/loop` | 주기적 LLM 프롬프트 | 정체 시 자동 행동 (비싸지만 자율적) |

> **선택 기준**: 알림만 → Monitor / 알림 + 자동 재개 → `/loop`

## 조합 예시

- **코드 구현 + 완료 보증**: `code-writer` + `ralph-loop`
- **긴급 버그 수정**: `error-fixer` + `ultrawork` + `ralph-loop`
- **DB 마이그레이션**: `db-code-writer` + `ralph-loop`
- **이중 보증 (최강)**: `ralph-loop` + Monitor heartbeat
- **자율 이중 보증**: `ralph-loop` + `/loop 2m` (LLM 자동 재개 필요 시)
