---
name: dep-upgrade
description: "의존성 패키지 업그레이드 자동 분석 — 현재 버전 감지 → changelog 자동 fetch → 코드베이스 매핑 → 적용점 제안. --auto 모드로 감지→분석→수정→검증→커밋 전자동 파이프라인. Use when: 패키지 업그레이드, 라이브러리 버전 확인, SDK 업데이트 적용, 정기 의존성 관리"
effort: high
preconditions:
  - 모노레포 내 package.json이 존재하는 상태
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - WebFetch
  - WebSearch
  - mcp__serena__find_symbol
  - mcp__serena__get_symbols_overview
  - mcp__serena__search_for_pattern
  - mcp__serena__read_memory
  - mcp__serena__write_memory
  - mcp__context7__resolve-library-id
  - mcp__context7__query-docs
  - Edit
  - Write
  - mcp__praetorian__praetorian_compact
user-invocable: true
context: fork
---

# Dep-Upgrade Skill

> "패키지 업그레이드? 버전 확인부터 적용점 제안까지 자동으로."

## WHY

패키지 업그레이드 분석은 반복적이고 시간 소모적:
1. 현재 버전 확인 → 2. 최신 버전 확인 → 3. changelog 읽기 → 4. 코드베이스에서 사용처 찾기 → 5. 적용 가능한 변경 매핑

이 스킬은 **전 과정을 자동화**하여 "적용할지 말지" 결정만 하면 되게 만든다.

## 사용법

```bash
# 패키지명만 (현재 버전 자동 감지, 최신 changelog 자동 fetch)
/dep-upgrade @anthropic-ai/claude-agent-sdk

# 패키지명 + 타겟 버전 (특정 버전까지만 분석)
/dep-upgrade @anthropic-ai/claude-agent-sdk 0.2.76

# 여러 패키지 (공백 구분)
/dep-upgrade next react

# changelog 직접 제공 (붙여넣기)
/dep-upgrade @anthropic-ai/claude-agent-sdk --changelog
> (사용자가 changelog 붙여넣기)

# 모노레포 전체 outdated 스캔
/dep-upgrade --scan

# 자율 업그레이드 파이프라인 (감지 → 분석 → 수정 → 검증 → 커밋 자동)
/dep-upgrade --auto

# 특정 패키지만 자율 업그레이드
/dep-upgrade @anthropic-ai/claude-agent-sdk --auto

# 여러 패키지 자율 업그레이드
/dep-upgrade next react --auto
```

## 5-Phase 자동 워크플로우

### Phase 1: Detect (현재 상태 파악)

```bash
# 1. 모노레포 전체에서 해당 패키지 사용처 탐색
Grep "{package_name}" --glob "**/package.json" --output_mode content

# 2. 현재 설치 버전 확인
# 각 앱별 node_modules 또는 pnpm-lock.yaml에서 실제 resolved 버전
```

**출력:**
```
📦 {package_name}
  apps/ai-agent/backend: ^0.2.74 (resolved: 0.2.74)
  apps/ai-agent/frontend: (미사용)
  apps/mcp-orbit/backend: (미사용)
```

### Phase 2: Fetch (최신 정보 수집)

**자동 우선순위:**
1. `npm view {package} versions --json` — 최신 버전 확인
2. npm changelog / GitHub Releases 자동 fetch:
   - `npm view {package} repository.url` → GitHub repo 추출
   - `WebFetch` GitHub releases API 또는 CHANGELOG.md
3. `context7`로 라이브러리 문서 최신판 조회 (가능한 경우)

**changelog이 $ARGUMENTS에 직접 제공된 경우 Phase 2 스킵**

### Phase 3: Scan (코드베이스 사용 패턴 분석)

**병렬 Agent 실행:**

```
┌─ Explore Agent ────────────────────────────────────┐
│  해당 패키지의 import/require 전수 검색              │
│  사용 중인 API, 클래스, 함수 목록 추출               │
│  파일별 사용 패턴 매핑                               │
└────────────────────────────────────────────────────┘
┌─ Codex Delegate (병렬) ────────────────────────────┐
│  changelog 각 항목의 기술적 의미 분석                │
│  Breaking Change 여부 판단                          │
│  마이그레이션 가이드 존재 시 요약                     │
└────────────────────────────────────────────────────┘
```

### Phase 4: Map (변경사항 ↔ 코드 매핑)

각 changelog 항목을 현재 코드와 대조:

| 분류 | 의미 | 행동 |
|------|------|------|
| 🔴 **Breaking** | 현재 사용 중인 API가 변경/삭제됨 | 마이그레이션 필수, 코드 수정 제안 |
| 🟡 **Improve** | 현재 코드를 더 나은 API로 교체 가능 | 적용 권장, Before/After 코드 제시 |
| 📊 **New** | 새 기능, 현재 미사용 | 활용 시나리오 제안 |
| ⚪ **Skip** | 사용하지 않는 영역의 변경 | 무시 |

### Phase 5: Propose (적용점 제안)

**출력 형식:**

```markdown
## 📦 {package} {current} → {latest}

### 🔴 Breaking Changes (즉시 조치)
| 변경 | 영향 파일 | 수정 방법 |
|------|----------|----------|
| `oldAPI()` 삭제 | service.ts:42 | `newAPI()` 으로 교체 |

### 🟡 개선 적용 가능 (권장)
| 신규 기능 | 현재 패턴 | 개선 후 | 파일:라인 |
|-----------|----------|---------|----------|
| `forkSession()` | 수동 세션 복제 | 네이티브 분기 | streaming.ts:1204 |

### 📊 새 기능 (선택)
| 기능 | 활용 시나리오 | 우선순위 |
|------|-------------|---------|
| `tagSession()` | 세션 분류/검색 | Medium |

### ⚪ 무관 (생략 가능)
- {변경1}: 미사용 영역
- {변경2}: 미사용 영역

### 업그레이드 명령어
​```bash
pnpm --filter {app} add {package}@{version}
​```

### 다음 단계
- "적용해줘" → code-writer로 자동 마이그레이션
- "Epic으로 만들어줘" → epic-creator로 업그레이드 계획
- "나중에" → serena 메모리에 저장
```

## --scan 모드 (전체 outdated 검사)

```bash
/dep-upgrade --scan
```

1. `pnpm outdated --json` 실행 (모노레포 전체)
2. major 업데이트가 있는 패키지만 필터링
3. 각 패키지별 간략 요약:
   ```
   📦 Outdated Summary (major only)
   | Package | Current | Latest | Apps | Risk |
   |---------|---------|--------|------|------|
   | next | 15.3 | 15.4 | 3 apps | 🟡 |
   | prisma | 6.3 | 7.0 | 2 apps | 🔴 |
   ```
4. "상세 분석할 패키지 선택하세요" → 선택된 패키지에 Phase 1-5 실행

## 메모리 저장

분석 완료 후 자동 저장:
```yaml
serena/write_memory:
  memory_file_name: "dep-upgrade-{package}-{version}"
  content: |
    Package: {package}
    From: {current} → To: {target}
    Date: {date}
    Breaking: {count}
    Improvements: {count}
    Applied: [pending/done]
```

## 사용자 응답 처리

| 사용자 응답 | 행동 |
|------------|------|
| "적용해줘" / "ㄱ" | code-writer Agent로 마이그레이션 자동 실행 |
| "Breaking만" | 🔴 항목만 code-writer로 수정 |
| "나중에" | serena 메모리 저장 + 다음 세션에서 리마인드 |
| "Epic으로" | epic-creator로 업그레이드 계획 생성 |
| "무시" | 기록 없이 종료 |

## --auto 모드 (자율 업그레이드 파이프라인)

> "감지 → 분석 → 수정 → 검증 → 리뷰 → 커밋" 전 과정을 단일 명령으로 실행

### WHY

기존 Phase 1-5는 **분석 + 제안**까지만 수행하고 적용은 사용자 응답("적용해줘")을 대기한다.
`--auto` 모드는 분석부터 커밋까지 **완전 자동화**하여, 정기 의존성 관리에 수동 개입을 제거한다.

### 활성화 조건

`$ARGUMENTS`에 `--auto` 플래그가 포함되면 이 모드로 실행.
특정 패키지가 지정되면 해당 패키지만, 미지정이면 주요 의존성 전체를 대상으로 한다.

### `/changelog` 스킬과의 관계

| 스킬 | 역할 | 입력 | 출력 |
|------|------|------|------|
| `/changelog` | 특정 버전 상세 분석 | 단일 버전 또는 범위 | Impact Analysis 보고서 |
| `/dep-upgrade` | 범용 업그레이드 분석 + 제안 | 패키지명 | 매핑 테이블 + 적용 제안 |
| `/dep-upgrade --auto` | **전자동 파이프라인** | 패키지명 (선택) | 코드 수정 + 커밋 완료 |

`--auto`는 `/changelog`의 fetch + 파싱 로직을 **재활용**하되, 수동 확인 단계를 생략하고 자동 적용까지 진행한다.

---

### Auto Phase 1: Version Scan (현재 → 최신 비교)

**목표**: 업그레이드 필요 패키지 목록이 확정된 상태

```bash
# 1. 패키지 지정 시: 해당 패키지만 스캔
# 2. 패키지 미지정 시: 주요 의존성 자동 스캔
#    - @anthropic-ai/claude-code
#    - @anthropic-ai/claude-agent-sdk (또는 @anthropic-ai/agent-sdk)
#    - 기타 사용자 지정 패키지

# 현재 버전 감지 (모든 package.json 탐색)
Grep "{package_name}" --glob "**/package.json" --output_mode content

# 최신 버전 확인
Bash: npm view {package_name} version

# 또는 claude CLI 자체 버전
Bash: claude --version 2>/dev/null
```

**출력 예시:**
```
## Version Scan Results

| Package | Current | Latest | Gap | Apps |
|---------|---------|--------|-----|------|
| @anthropic-ai/claude-agent-sdk | 0.2.92 | 0.2.99 | 7 versions | ai-agent/backend |
| @anthropic-ai/claude-code | 2.1.98 | 2.1.105 | 7 versions | (CLI) |

업그레이드 대상: 2개 패키지
```

**중단 조건**: 모든 패키지가 최신이면 "All up to date" 출력 후 종료.

---

### Auto Phase 2: Multi-Version Changelog Collection

**목표**: 현재 → 최신 사이 모든 버전의 changelog이 수집/파싱된 상태

**수집 전략** (`/changelog` Phase 2 로직 재활용):

1. **GitHub Releases 일괄 fetch**:
   ```
   WebFetch https://github.com/anthropics/claude-code/releases
   ```
   - 현재 버전 ~ 최신 버전 사이의 모든 릴리즈 항목 추출
   - 각 버전별 변경사항을 개별 항목으로 분리

2. **npm 보완**:
   ```bash
   npm view {package} versions --json
   ```
   - GitHub에 없는 버전은 npm에서 보완

3. **Fallback**: WebSearch로 changelog 검색

**파싱 결과 구조:**
```
v0.2.93:
  - [breaking] Task resume 파라미터 제거 → SendMessage 사용
  - [feature] SubagentStop hook에 agent_transcript_path 추가
  - [fix] worktree 초기화 시 부분 실패 허용

v0.2.94:
  - [feature] isolation: "worktree" frontmatter 지원
  - [fix] MCP HTTP 메모리 누수 수정
  ...
```

**각 항목 분류:**
- `breaking` — API 변경, 삭제, 기본값 변경, 시그니처 변경
- `feature` — 새 기능, 새 옵션, 새 설정
- `fix` — 버그 수정
- `perf` — 성능 개선
- `docs` — 문서 변경

---

### Auto Phase 3: Impact Analysis (코드베이스 종합 매핑)

**목표**: 각 breaking change가 코드베이스 어디에 영향을 주는지 파악된 상태

**검색 범위** (기존 Phase 3 Scan과 동일):
```bash
# 1. 소스 코드
Grep "{keyword}" --glob "apps/**/src/**/*.ts" --glob "apps/**/src/**/*.tsx"

# 2. .claude/ 설정
Grep "{keyword}" --glob ".claude/**/*"

# 3. Hook 스크립트
Grep "{keyword}" --glob ".claude/hooks/**/*"

# 4. Agent/Skill 정의
Grep "{keyword}" --glob ".claude/agents/**/*" --glob ".claude/skills/**/*"

# 5. CLAUDE.md 규칙
Grep "{keyword}" --glob "**/CLAUDE.md"
```

**종합 테이블 출력:**
```markdown
## Impact Analysis (전체 버전 통합)

### 자동 수정 가능 (Auto-Fix)
| # | 버전 | 변경사항 | 영향 파일 | 수정 방법 |
|---|------|---------|----------|----------|
| 1 | v0.2.93 | Task resume 제거 | hooks/retry.sh | SendMessage 패턴으로 교체 |
| 2 | v0.2.95 | settings.json 키 변경 | .claude/settings.json | 키 이름 rename |

### 수동 확인 필요 (Manual Review)
| # | 버전 | 변경사항 | 영향 파일 | 이유 |
|---|------|---------|----------|------|
| 1 | v0.2.97 | 인증 흐름 변경 | auth-middleware.ts | 비즈니스 로직 판단 필요 |

### 영향 없음 (Skip)
- v0.2.94: worktree 관련 — 현재 미사용
- v0.2.96: Python SDK 변경 — TypeScript만 사용
```

---

### Auto Phase 4: Auto-Apply (자동 수정 + 검증)

**목표**: 모든 자동 수정 가능 항목이 적용되고, 빌드가 통과한 상태

**실행 순서:**

#### Step 1: 버전 업그레이드
```bash
# 패키지 버전 업데이트
pnpm --filter {app} add {package}@{latest_version}
# 또는 전역
pnpm add {package}@{latest_version}
```

#### Step 2: Breaking Change 자동 수정
각 Auto-Fix 항목에 대해 순차적으로:
```
1. Grep으로 대상 패턴 검색
2. Edit으로 패턴 교체
3. 파일별 수정 후 즉시 `pnpm tsc --noEmit` 확인 (증분 검증)
```

#### Step 3: 빌드 검증 (3-Strike Rule)
```bash
pnpm install
pnpm tsc --noEmit
pnpm build
```

**실패 시 자동 수정 루프 (최대 3회):**
```
시도 1: 빌드 에러 분석 → 자동 수정 시도
시도 2: 다른 접근법 시도 (historian/get_error_solutions 참조)
시도 3: 마지막 시도
실패 3회: STOP → 사용자에게 보고
```

```markdown
## 3-Strike 보고 (빌드 실패 시)

시도 1: [수정 내용 + 실패 이유]
시도 2: [수정 내용 + 실패 이유]  
시도 3: [수정 내용 + 실패 이유]

수동 확인 필요:
- [에러 메시지]
- [관련 파일:라인]
- [제안 수정 방법]
```

#### Step 4: 수동 확인 필요 항목 안내
Auto-Fix 이후 Manual Review 항목이 있으면:
```
수동 확인 필요 항목 {n}개:
1. {파일:라인} — {변경 설명} — {확인 필요 이유}
2. ...

이 항목들은 자동 수정하지 않았습니다. 확인 후 "수정해줘"로 요청하세요.
```

---

### Auto Phase 5: Review & Commit

**목표**: Codex 리뷰 통과 + 구조화된 커밋으로 완료된 상태

#### Step 1: Codex 코드 리뷰
```
Agent(subagent_type='99-utils/codex-delegate', prompt='''
아래 diff를 리뷰해주세요:

{git diff --cached 또는 git diff}

확인 사항:
1. Breaking change 마이그레이션이 올바른가?
2. 누락된 수정 사항이 있는가?
3. 새 API 활용 기회가 있는가?

형식: APPROVED / NEEDS_CHANGE + 사유
''')
```

#### Step 2: 리뷰 결과 처리
- **APPROVED**: 커밋 진행
- **NEEDS_CHANGE**: 피드백 반영 후 재빌드 → 재리뷰 (1회 추가)

#### Step 3: 구조화된 커밋
```
[agent:dep-upgrade] feat(deps): upgrade {package} v{old} -> v{new}

Breaking changes applied:
- {change1}: {파일} ({수정 방법})
- {change2}: {파일} ({수정 방법})

New features available:
- {feature1}: {활용 가능 시나리오}

Codex review: {approved/approved-with-changes}

Manual review needed:
- {항목1} (if any)
```

#### Step 4: 세션 메모리 저장
```bash
mcp__serena__write_memory({
  memory_file_name: "dep-upgrade-auto-{package}-{date}",
  content: "# Auto Upgrade: {package} v{old} -> v{new}\n\nDate: {date}\nBreaking Applied: {n}\nManual Remaining: {n}\nBuild: PASS\nCodex Review: APPROVED\n\n## Applied Changes\n{목록}"
})
```

```bash
mcp__praetorian__praetorian_compact({
  summary: "dep-upgrade --auto: {package} v{old}->v{new}. Breaking {n}개 자동 수정, 빌드 통과, Codex 승인."
})
```

---

### --auto 모드 전체 플로우 요약

```
/dep-upgrade --auto
    |
    v
[Phase 1] Version Scan
    |- 현재 버전 감지 (package.json)
    |- 최신 버전 확인 (npm view)
    |- 업그레이드 필요 패키지 목록
    |  (모두 최신 → "All up to date" 종료)
    v
[Phase 2] Changelog Collection
    |- GitHub Releases 일괄 fetch
    |- 현재→최신 모든 버전 파싱
    |- breaking/feature/fix 분류
    v
[Phase 3] Impact Analysis
    |- 코드베이스 전수 검색
    |- Auto-Fix / Manual Review / Skip 분류
    |- 종합 영향 테이블 출력
    v
[Phase 4] Auto-Apply
    |- pnpm add {package}@{latest}
    |- Breaking change 순차 수정 (Grep → Edit)
    |- pnpm install → tsc → build (3-Strike)
    |- 수동 확인 항목 안내
    v
[Phase 5] Review & Commit
    |- Codex delegate 코드 리뷰
    |- 리뷰 피드백 반영
    |- 구조화된 커밋 메시지
    |- serena + praetorian 메모리 저장
    v
    DONE
```

---

### --auto 모드 안전장치

| 안전장치 | 동작 |
|---------|------|
| **3-Strike Rule** | 빌드 3회 실패 → 자동 중단 + 사용자 보고 |
| **Manual Review 분리** | 비즈니스 로직 판단 필요 항목은 자동 수정 안 함 |
| **Codex 리뷰 필수** | 리뷰 미통과 시 커밋 안 함 |
| **증분 검증** | 파일 수정마다 `tsc --noEmit` (누적 에러 방지) |
| **롤백 가능** | 커밋 단위로 분리되어 `git revert` 가능 |
| **최신 확인** | 이미 최신이면 불필요한 작업 안 함 |

## 연결 Agent

- **Explore**: 코드베이스 사용 패턴 전수 검색
- **codex-delegate**: changelog 기술 분석 (병렬) + `--auto` 모드 코드 리뷰
- **code-writer**: 마이그레이션 자동 실행
- **epic-creator**: 대규모 업그레이드 계획
- **reference-integrator:analyze-changelog**: Claude Code 자체 업데이트 분석 시 연계
