# Git Context Injector Agent

## Purpose
Story 생성 직후 관련 Git 커밋 히스토리를 자동 분석하여 리팩토링/이름 변경 컨텍스트를 Task Planner에 제공.

## Trigger
- **자동 실행**: story-creator 완료 시
- **수동 실행**: `Task --subagent 01-pre-analysis/git-context-injector --prompt "Analyze Git history for {story_id}"`

## Input
```yaml
story_id: "EP001-S02"  # Story 식별자
keywords:              # Story.md에서 추출한 핵심 키워드
  - "campaign-submissions"
  - "weekly-okrs"
  - "API"
lookback_commits: 50   # 검색할 최근 커밋 수 (기본값)
```

## Output (Serena MCP Memory)
```json
{
  "memory_key": "git_refactoring_EP001-S02",
  "content": {
    "refactorings": [
      {
        "commit": "40c6765",
        "date": "2025-10-20",
        "message": "refactor: Rename campaign-submissions to weekly-okrs",
        "changes": [
          {
            "old_path": "apps/backend/src/campaign-submissions",
            "new_path": "apps/backend/src/weekly-okrs",
            "impact": "API endpoint changed: /api/v1/campaign-submissions → /api/v1/weekly-okrs"
          }
        ]
      }
    ],
    "related_commits": [
      {
        "commit": "3d14e0c",
        "message": "fix: Add API_BASE_URL fallback",
        "files": ["apps/frontend/src/lib/api/*.ts"]
      }
    ],
    "summary": "campaign-submissions 모듈이 weekly-okrs로 리팩토링됨 (40c6765). API 경로도 변경됨."
  }
}
```

## Workflow

### Step 1: Story 키워드 추출
```typescript
// Story.md 파싱
const storyContent = await readFile(`docs/epics/${epicId}/stories/${storyId}.md`);
const keywords = extractKeywords(storyContent);
// 예: ["campaign", "submission", "weekly", "okr", "API"]
```

### Step 2: Git 명령어 실행
```bash
# 리팩토링 감지 (이름 변경, 파일 이동)
git log --follow --diff-filter=R --oneline -50 --all-match \
  --grep="campaign" --grep="submission" --grep="weekly" --grep="okr"

# 관련 커밋 검색
git log --oneline -50 -- "apps/backend/src/*campaign*" "apps/backend/src/*weekly*"

# 커밋 상세 정보
git show {commit_hash} --name-status --pretty=format:"%H|%ad|%s"
```

### Step 3: 리팩토링 패턴 분석
```typescript
const refactorings = commits
  .filter(c => c.message.match(/refactor|rename|move/i))
  .map(c => ({
    commit: c.hash,
    date: c.date,
    message: c.message,
    changes: parseRenameChanges(c.diff),
  }));
```

### Step 4: Serena MCP 메모리 저장
```typescript
await serena.writeMemory({
  key: `git_refactoring_${storyId}`,
  content: { refactorings, related_commits, summary },
  ttl: 7 * 24 * 3600, // 7일
});
```

### Step 5: Task Planner 컨텍스트 제공
```yaml
# task-planner는 자동으로 다음 메모리 읽음
git_refactoring_{story_id}:
  summary: "campaign-submissions → weekly-okrs 리팩토링 완료"
  latest_api_path: "/api/v1/weekly-okrs"
  warning: "구버전 /api/v1/campaign-submissions 사용 금지"
```

## Edge Cases

### Case 1: 키워드 매칭 실패
```yaml
문제: Story 키워드가 Git 커밋 메시지와 불일치
해결: Fuzzy 매칭 + 파일 경로 기반 검색
예시: "OKR" → "okr", "o-k-r", "weekly_okr"
```

### Case 2: 너무 많은 커밋
```yaml
문제: 50개 커밋 초과 시 성능 저하
해결:
  - 최근 50개로 제한 (기본값)
  - 리팩토링 커밋만 필터링 (--diff-filter=R)
  - 불필요한 파일 제외 (*.md, *.json 제외)
```

### Case 3: Git 없음 (신규 프로젝트)
```yaml
문제: .git 디렉토리 없음
해결:
  - Git 확인 → 없으면 Skip
  - 메모리에 "no_git_history" 저장
  - task-planner는 현재 코드베이스만 사용
```

## Performance

### 목표 지표
- **실행 시간**: < 3초 (Git 명령어 최적화)
- **컨텍스트 절감**: 80% (200줄 커밋 로그 → 40줄 요약)
- **정확도**: 95%+ (실제 리팩토링 감지)

### Git 명령어 최적화
```bash
# ❌ 느린 방법 (모든 커밋 조회)
git log --all --grep="keyword"

# ✅ 빠른 방법 (최근 50개 + 특정 경로)
git log --oneline -50 -- "apps/backend/src/*keyword*"

# ✅ 더 빠른 방법 (리팩토링만)
git log --diff-filter=R --oneline -20 -- "apps/backend/src/**"
```

## Integration with Existing Agents

### story-creator 수정
```typescript
// .claude/agents/02-requirements/story-creator/agent.ts (Step 8 추가)

// Step 7: Story.md 생성 완료

// 🆕 Step 8: Git Context Injection (자동 실행)
await executeSubAgent({
  type: '01-pre-analysis/git-context-injector',
  prompt: `Analyze Git history for ${storyId}`,
  input: {
    story_id: storyId,
    keywords: extractKeywords(storyContent),
  },
});

// Step 9: progress-updater에 상태 전달
```

### task-planner 수정
```typescript
// .claude/agents/03-design/task-planner/agent.ts (Step 2 추가)

// Step 1: Story.md 읽기

// 🆕 Step 2: Git 컨텍스트 읽기 (있으면)
const gitContext = await serena.readMemory(`git_refactoring_${storyId}`);
if (gitContext) {
  console.log('📜 Git Refactoring Context:', gitContext.summary);
  // Task 생성 시 최신 경로 사용
}

// Step 3: Task 분해
```

## Success Metrics

### Before (현재)
```yaml
케이스: "Weekly OKR API 추가"
문제: campaign-submissions API 호출 시도
결과: 404 에러 → 사용자 알림 → 수동 수정
시간: 5분 (에러 + 수정)
```

### After (개선)
```yaml
케이스: "Weekly OKR API 추가"
자동: Git 분석 → weekly-okrs API 발견
결과: 정확한 경로로 즉시 구현
시간: 3초 (Git 분석)
절감: 4분 57초
```

### ROI 계산
```yaml
발생 빈도: 주 2회 (리팩토링 빈번한 프로젝트)
절감 시간: 5분/회 × 2회 = 10분/주
개발 비용: 2시간 (Agent 구현)
Break-even: 12주 (3개월)

결론: 충분히 가치 있음 (장기 프로젝트)
```

## Phase 1 Scope (MVP)

### 포함
- [x] Git 리팩토링 감지 (파일 이동, 이름 변경)
- [x] Serena MCP 메모리 저장
- [x] task-planner 컨텍스트 제공
- [x] story-creator 자동 연동

### 제외 (Phase 2)
- [ ] 커밋 메시지 AI 분석 (Zen MCP)
- [ ] 리팩토링 패턴 학습 (Machine Learning)
- [ ] 자동 문서 업데이트 (docs/patterns/)
- [ ] Epic 전체 히스토리 분석

## Risks

### Risk 1: Git 명령어 느림
```yaml
확률: 중
영향: 중
완화:
  - 최근 50개 커밋으로 제한
  - 리팩토링 커밋만 필터링
  - 타임아웃 3초 설정
```

### Risk 2: 키워드 매칭 실패
```yaml
확률: 중
영향: 중
완화:
  - Fuzzy 매칭 (Levenshtein Distance)
  - 파일 경로 기반 검색 (fallback)
  - 사용자 피드백 루프 (Pattern Learning)
```

### Risk 3: 불필요한 실행
```yaml
확률: 높음
영향: 낮음
완화:
  - 신규 Epic은 Git 히스토리 적음 → Skip
  - 캐시 메커니즘 (같은 Story 반복 조회 방지)
  - 사용자 설정 (git_context_enabled: true/false)
```

## Future Enhancements (Phase 2)

### E1: Zen MCP Integration
```yaml
기능: 커밋 메시지 AI 분석
트리거: 복잡한 리팩토링 감지 시
효과: 자동 문서 생성 (docs/patterns/refactoring/)
```

### E2: Pattern Learning
```yaml
기능: 리팩토링 패턴 학습
데이터: 성공한 Task vs 실패한 Task
출력: "이 패턴은 weekly-okrs → campaign-results 리팩토링과 유사 (95%)"
```

### E3: Auto Documentation
```yaml
기능: 리팩토링 히스토리 자동 문서화
트리거: Epic 완료 시
출력: docs/epics/{epic_id}/REFACTORING_LOG.md
```

---

## Implementation Plan

### Week 1: Core Agent
- [ ] Git 명령어 래퍼 함수 (bash wrapper)
- [ ] 키워드 추출 로직 (Story.md 파싱)
- [ ] Serena MCP 메모리 저장/읽기

### Week 2: Integration
- [ ] story-creator 연동 (Step 8 추가)
- [ ] task-planner 연동 (Step 2 추가)
- [ ] 테스트 케이스 (okr2 프로젝트)

### Week 3: Optimization
- [ ] Git 명령어 최적화 (성능 측정)
- [ ] Edge Case 처리 (키워드 매칭 실패)
- [ ] 문서화 (AGENT_CATALOG.md 업데이트)

---

## Conclusion

**핵심 가치**:
- 리팩토링 히스토리 컨텍스트 → 정확한 Task 생성
- 사용자 개입 최소화 (자동 Git 분석)
- 장기적 시간 절감 (주 10분 × 52주 = 8.6시간/년)

**우선순위**: Phase 1 (MVP) 먼저 구현 → 실제 효과 측정 → Phase 2 결정
