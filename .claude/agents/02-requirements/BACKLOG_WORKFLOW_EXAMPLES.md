# _backlog & ADHOC Workflow Examples

## 📋 테스트 시나리오 (Test Scenarios)

### Scenario 1: Epic 없는 단일 Story (_backlog)

**사용자 요청**:
```
"Chrome DevTools 타임아웃 최적화"
```

**분석**:
```yaml
Epic ID: 없음
요청 규모: Story 1개 (단일 작업)
복잡도: 중간 (1-2일 예상)
의사결정:
  - Epic ID 없음? YES
  - 관련 작업 2-3개 이상? NO (단일 Story)
  - 결론: story-creator --backlog-mode
```

**예상 동작**:
```
1. story-creator Agent 호출 (--backlog-mode)
2. 자동 감지: Epic ID 없음 → _backlog 모드
3. Output: docs/epics/_backlog/S01_chrome-devtools-timeout-optimization.md
4. Story 구조:
   - ## 📋 Story 개요
   - ## 🎯 Acceptance Criteria
   - ## 📝 상세 구현 가이드
   - (Story 분해 없음, 직접 Task로 진행)
```

**결과 검증**:
```bash
# 파일 위치 확인
ls -la docs/epics/_backlog/S01_*.md

# 파일 내용 확인
head -30 docs/epics/_backlog/S01_chrome-devtools-timeout-optimization.md
```

---

### Scenario 2: Epic 없는 단일 Task (_backlog)

**사용자 요청**:
```
"User 테이블에 phone_number 컬럼 추가"
```

**분석**:
```yaml
Epic ID: 없음
요청 규모: Task 1개 (분해 불필요)
복잡도: 낮음 (2-4시간 예상)
의사결정:
  - Epic ID 없음? YES
  - Story 분해 필요? NO (단순 DB 스키마 추가)
  - 결론: task-planner --backlog-mode
```

**예상 동작**:
```
1. task-planner Agent 호출 (--backlog-mode)
2. 자동 감지: Epic ID 없음 + Story 분해 불필요
3. 스킵: Story 분해 단계 (Backlog Mode에서는 Task만 생성)
4. Output: docs/epics/_backlog/T001_add-user-phone-column.md
5. Task 구조:
   - ## 📋 Task 개요
   - ## 🎯 Acceptance Criteria
   - ## 🔧 구현 가이드
   - (Story 계층 없음)
```

**결과 검증**:
```bash
# 파일 위치 확인
ls -la docs/epics/_backlog/T###_*.md

# Task 파일 구조 확인
cat docs/epics/_backlog/T001_add-user-phone-column.md | head -50
```

---

### Scenario 3: Epic 없는 관련 작업 2-3개 (ADHOC Epic)

**사용자 요청**:
```
"로깅 시스템 개선 - Connection Logs에 API key 정보 추가, User Action Logs 도입, 로그 필터링 API 추가"
```

**분석**:
```yaml
Epic ID: 없음
요청 규모: 3개 관련 작업 (Story로 분해 필요)
복잡도: 높음 (3-5일 예상, 여러 작업 조율)
의사결정:
  - Epic ID 없음? YES
  - 관련 작업 2-3개 이상? YES (3개 작업)
  - 결론: epic-creator (--adhoc) → ADHOC Epic 생성
```

**예상 동작**:
```
1. epic-creator Agent 호출 (--adhoc 플래그)
2. ADHOC Epic ID 자동 생성: ADHOC-001
3. 폴더 생성:
   docs/epics/ADHOC-001_logging-improvements/
   ├── epic.md (epic-creator가 작성)
   ├── PROGRESS.md
   ├── stories/
   │   ├── S01_connection-logs-api-key-logging.md
   │   ├── S02_user-action-logs-system.md
   │   └── S03_log-filtering-api.md
   └── tasks/

4. 다음 Agent 체인:
   - story-creator: 각 S01, S02, S03 상세 작성
   - task-planner: 각 Story를 Task로 분해
   - code-writer: Task 구현
```

**결과 검증**:
```bash
# ADHOC Epic 폴더 구조 확인
ls -la docs/epics/ADHOC-001_*

# epic.md 확인
head -50 docs/epics/ADHOC-001_logging-improvements/epic.md

# Stories 확인
ls -la docs/epics/ADHOC-001_logging-improvements/stories/
```

---

### Scenario 4: Epic ID 명시된 경우 (Regular Mode - 참고)

**사용자 요청**:
```
"EP010 Custom Evaluator System의 다음 Story를 작성해주세요"
```

**분석**:
```yaml
Epic ID: EP010 (명시됨)
요청 규모: Story 분해 필요
복잡도: 중간 (1-2주, 여러 Story)
의사결정:
  - Epic ID 있음? YES
  - 결론: story-creator (Regular Mode)
```

**예상 동작**:
```
1. story-creator Agent 호출 (Regular Mode)
2. 자동 감지: Epic ID 명시 → Regular 모드
3. Output: docs/epics/EP010_custom-evaluator-system/stories/S##_*.md
4. Story 분해 (기존 방식 유지)
```

---

## 🧪 워크플로우 테스트 체크리스트

### Test Case 1: _backlog Story 생성

```yaml
준비:
  - 새로운 Story 요청 (Epic ID 없음)
  - 단일 작업 (분해 불필요)

실행:
  - [ ] story-creator 호출 (--backlog-mode)
  - [ ] Output 폴더: docs/epics/_backlog/
  - [ ] 파일 네이밍: S##_descriptive-name.md

검증:
  - [ ] 파일 생성됨
  - [ ] Story 제목/설명 정확함
  - [ ] Story 구조 올바름 (Task 분해 없음)
  - [ ] PROGRESS.md 업데이트됨
```

### Test Case 2: _backlog Task 생성

```yaml
준비:
  - 새로운 Task 요청 (Epic/Story ID 없음)
  - 단순 작업 (Story 분해 불필요)

실행:
  - [ ] task-planner 호출 (--backlog-mode)
  - [ ] Output 폴더: docs/epics/_backlog/
  - [ ] 파일 네이밍: T###_descriptive-name.md
  - [ ] Story 분해 단계 스킵

검증:
  - [ ] 파일 생성됨
  - [ ] Task 제목/설명 정확함
  - [ ] Task 구조 올바름 (Story 계층 없음)
  - [ ] Acceptance Criteria 명확함
```

### Test Case 3: ADHOC Epic 생성

```yaml
준비:
  - 새로운 요청 (Epic ID 없음)
  - 관련 작업 2-3개
  - 여러 도메인 포함

실행:
  - [ ] epic-creator 호출 (--adhoc)
  - [ ] ADHOC ID 자동 생성: ADHOC-###
  - [ ] 폴더 구조 생성: docs/epics/ADHOC-###_*/
  - [ ] epic.md 작성
  - [ ] Story 분해 (S01, S02, S03)

검증:
  - [ ] ADHOC 폴더 생성됨
  - [ ] epic.md 작성됨
  - [ ] Stories 폴더 구조 올바름
  - [ ] 각 Story 파일 생성됨
  - [ ] story-creator 체인 연결 가능
```

### Test Case 4: 자동 감지 로직 (경계 케이스)

```yaml
Test 4.1: "도메인이 불명확한 2개 작업"
  입력: "다양한 개선작업들" (정확한 범위 불명확)
  예상: epic-creator (--adhoc) 또는 사용자에게 구체화 요청

Test 4.2: "정확히 2개 관련 작업"
  입력: "A 작업, B 작업" (2개)
  예상: epic-creator (--adhoc) [ADHOC Epic 생성]

Test 4.3: "1개 작업"
  입력: "A 작업만" (1개)
  예상: story-creator (--backlog-mode) 또는 task-planner (--backlog-mode)

Test 4.4: "4개 이상 관련 작업"
  입력: "A, B, C, D 작업" (4개+)
  예상: epic-creator (--adhoc) [경고: 추천은 2-3개, 분할 제안]
```

---

## 🎯 Agent 출력 검증 항목

### epic-creator (ADHOC Mode) 검증

```markdown
✅ Output 확인:
  - [ ] ADHOC-{nnn} 폴더 생성됨
  - [ ] epic.md 파일 작성됨
  - [ ] PROGRESS.md 초기화됨
  - [ ] 폴더 구조: stories/, tasks/ 생성됨

✅ Content 확인:
  - [ ] Epic ID: ADHOC-{nnn}_{descriptive}
  - [ ] Epic Title: 명확한 이름
  - [ ] MVP Scope: 현재 필요한 기능만 포함
  - [ ] Story 개수: 2-3개 권장
  - [ ] Acceptance Criteria: 명확함
```

### story-creator (Backlog Mode) 검증

```markdown
✅ Output 확인:
  - [ ] docs/epics/_backlog/S##_*.md 생성됨
  - [ ] 이전 Story 번호 기반 자동 증가 (S01, S02, ...)

✅ Content 확인:
  - [ ] Story Title: 명확한 이름
  - [ ] Story 개요: 비즈니스 가치 명시
  - [ ] Acceptance Criteria: 5-7개, 검증 가능
  - [ ] Task 분해 없음 (Backlog Story는 분해 불필요)
  - [ ] Tech Stack: 기존 패턴 참조

✅ 구조 확인:
  - [ ] Story 계층: Epic 없음 (ROOT 레벨)
  - [ ] PROGRESS.md: story-overview.md 업데이트됨
```

### task-planner (Backlog Mode) 검증

```markdown
✅ Output 확인:
  - [ ] docs/epics/_backlog/T###_*.md 생성됨
  - [ ] 이전 Task 번호 기반 자동 증가 (T001, T002, ...)
  - [ ] Story 분해 단계 스킵됨 (검증: Task 파일만 생성)

✅ Content 확인:
  - [ ] Task Title: 명확한 이름
  - [ ] Task 범위: 1-2일 이내 완료 예상
  - [ ] Acceptance Criteria: 구체적, 검증 가능
  - [ ] 구현 가이드: code-writer가 바로 진행 가능한 수준

✅ 구조 확인:
  - [ ] Task 계층: Story ID 없음 (T### 형식만)
  - [ ] 의존성: 독립적 작업 (병렬 실행 가능)
```

---

## 📊 예상 결과 정리

| 요청 유형 | Epic ID | 작업 수 | Agent | Output | Story 분해 |
|----------|--------|--------|-------|--------|-----------|
| Regular Story | 있음 | 2-4개 | story-creator | EP{nnn}/stories/ | YES |
| Backlog Story | 없음 | 1개 | story-creator | _backlog/S##_*.md | NO |
| ADHOC Epic | 없음 | 2-3개 | epic-creator | ADHOC-{nnn}_*/ | YES |
| Backlog Task | 없음 | 1개 | task-planner | _backlog/T###_*.md | N/A |
| Regular Task | 있음 | 1-4개 | task-planner | EP{nnn}/tasks/ | N/A |

---

## 🔗 관련 문서

- **구조 규칙**: `docs/epics/_backlog/STRUCTURE.md`
- **사용 가이드**: `docs/epics/_backlog/README.md`
- **Epic Creator**: `.claude/agents/02-requirements/epic-creator.md`
- **Story Creator**: `.claude/agents/02-requirements/story-creator.md`
- **Task Planner**: `.claude/agents/03-design/task-planner.md`
- **AUTO-WORKFLOW**: `.claude/CLAUDE.md` (Step 0.5)

---

## ✅ 구현 완료 체크리스트

- [x] epic-creator ADHOC 모드 추가
- [x] story-creator Backlog 모드 추가
- [x] task-planner Backlog 모드 추가
- [x] CLAUDE.md AUTO-WORKFLOW Step 0.5 추가
- [x] 테스트 시나리오 문서화 (이 파일)
- [ ] 실제 테스트 실행 (사용자가 실행)

---

_S03 Story: Agent 워크플로우에 _backlog 구조 반영 - 완료_
