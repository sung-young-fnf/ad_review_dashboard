# 하이브리드 커밋 관리 시스템 사용 가이드

## 🎯 시스템 개요

MCP-ORCH 프로젝트의 Epic-Story-Task 구조에 맞춘 지능적 커밋 관리 시스템입니다.
각 워크플로우 단계에서 자동으로 적절한 커밋 메시지를 생성하고 검증을 수행합니다.

## 🔄 워크플로우별 사용법

### 1. Task 구현 완료 (code-writer)

```bash
# 코드 구현 후 자동 커밋
/command code-writer/complete-and-commit T01

# 수동으로 commit-manager 사용
/command commit-manager/analyze-changes
/command commit-manager/validate-changes  
/command commit-manager/generate-task-message T01 code-writer
/command commit-manager/commit-task T01 code-writer
```

**결과:**
- 구현된 파일들 자동 staging
- 린트/컴파일 검증
- Conventional Commits 형식 메시지 생성
- test-creator로 handoff 정보 생성

### 2. 테스트 작성 완료 (test-creator)

```bash
# 테스트 작성 후 검증 및 커밋
/command test-creator/verify-and-commit T01

# 수동 단계별 실행
/command commit-manager/analyze-changes
/command commit-manager/validate-changes
/command commit-manager/generate-task-message T01 test-creator
/command commit-manager/commit-task T01 test-creator
```

**결과:**
- 테스트 파일들 자동 staging
- 테스트 실행 및 통과 확인
- 테스트 결과 기반 커밋 메시지
- Implementation checkpoint 생성

### 3. Story 완료 (docs-updater)

```bash
# Story 문서 업데이트 및 통합 커밋
/command docs-updater/finalize-and-commit S01 E001

# 수동 단계별 실행  
/command commit-manager/analyze-story-changes S01 E001
/command commit-manager/validate-changes
/command commit-manager/generate-story-message S01 E001
/command commit-manager/commit-story S01 E001
```

**결과:**
- Story/Task/Epic 문서 상태 업데이트
- 전체 Task 커밋들 종합한 메시지
- Epic 진행 상황 업데이트
- Story 완료 기록 생성

## 🔧 독립 실행 명령어

### 변경사항 분석
```bash
# 현재 변경사항 분석
/command commit-manager/analyze-changes

# Story 전체 변경사항 분석  
/command commit-manager/analyze-story-changes S01 E001
```

### 검증 및 에러 처리
```bash
# 코드 품질 검증
/command commit-manager/validate-changes

# 검증 실패 시 에러 처리
/command commit-manager/handle-validation-errors lint T01
/command commit-manager/handle-validation-errors test T01

# 실패 시 롤백
/command commit-manager/rollback-changes
```

### 커밋 메시지 생성
```bash
# Task 커밋 메시지 생성
/command commit-manager/generate-task-message T01 code-writer

# Story 커밋 메시지 생성
/command commit-manager/generate-story-message S01 E001
```

## 📋 커밋 메시지 형식

### Task 커밋 (Conventional Commits)
```
feat(api): implement task T01 server restart functionality

Added files:
- src/mcp_orch/api/projects/servers.py
- web/src/app/api/projects/[projectId]/restart/route.ts

MCP Server compatibility: stdio/sse modes supported
FastAPI endpoint changes included

Task: T01
Agent: code-writer

🤖 Generated with [Claude Code](https://claude.ai/code)
Co-Authored-By: Claude <noreply@anthropic.com>
```

### Story 커밋 (통합)
```
feat(fullstack): complete S01: Server Management Interface

Story completed with comprehensive implementation:

📊 Changes Summary:
- Total files changed: 12
- Python files: 5  
- TypeScript files: 4
- Test files: 3
- Documentation: 2

🔗 Related Task Commits:
- T01: abc123 (code-writer)
- T02: def456 (test-creator)

🔌 MCP Server Features:
- stdio/sse compatibility maintained
- Project-scoped server identification

Epic: E001
Story: S01

🤖 Generated with [Claude Code](https://claude.ai/code)
Co-Authored-By: Claude <noreply@anthropic.com>
```

## 🛡️ 검증 및 안전 장치

### 자동 검증 항목
- **Python**: ruff lint + pytest
- **TypeScript**: eslint + npm test  
- **컴파일**: 문법 에러 체크
- **의존성**: 패키지 무결성 확인

### 실패 시 자동 처리
- 검증 실패 → 자동 롤백
- 커밋 실패 → 변경사항 보존
- 에러 분석 → 수정 가이드 제공

### 안전 기능
- 단계별 확인 프롬프트
- 변경사항 백업 (스태시)
- 에러 기록 및 추적

## 📁 메모리 및 기록 관리

### 생성되는 메모리 파일들
- `.serena/memories/commit_task_{task_id}.md` - Task 커밋 기록
- `.serena/memories/commit_story_{story_id}.md` - Story 커밋 기록  
- `.serena/memories/handoff_{agent}_{task_id}.md` - Agent 간 데이터 전달
- `.serena/memories/implementation_checkpoint_{task_id}.md` - 구현 체크포인트
- `.serena/memories/story_completion_{story_id}.md` - Story 완료 기록

### 활용되는 정보
- Task/Story/Epic 문서 내용
- 이전 커밋 히스토리  
- Agent 간 handoff 데이터
- 프로젝트 설정 (CLAUDE.md, pyproject.toml)

## 🔄 에러 상황별 대응

### 린트 실패
```bash
/command commit-manager/handle-validation-errors lint T01
# → 자동 수정 명령어 제시
# → ruff check --fix, npm run lint:fix 등
```

### 테스트 실패  
```bash
/command commit-manager/handle-validation-errors test T01
# → 실패한 테스트 상세 분석
# → 수정 포인트 안내
```

### 커밋 실패
```bash
/command commit-manager/rollback-changes
# → 안전한 롤백 실행
# → 변경사항 보존 옵션 제공
```

## 🎯 모범 사례

### 1. Task 구현 시
1. 코드 구현 완료
2. `complete-and-commit` 실행
3. 자동 handoff로 다음 단계 진행

### 2. 연속 작업 시
1. code-writer → test-creator → docs-updater 순서
2. 각 단계에서 자동 커밋 활용
3. handoff 정보로 맥락 유지

### 3. 에러 발생 시
1. 에러 메시지 확인
2. `handle-validation-errors` 실행  
3. 가이드에 따라 수정
4. 재시도

## 💡 고급 활용

### 복잡한 변경사항 분석
```bash
/command commit-manager/analyze-story-changes S01 E001
# → 복잡도, 위험도 평가
# → 도메인별 영향도 분석
```

### 커밋 히스토리 추적
- Task 커밋들이 Story 커밋에서 참조됨
- Epic 전체 진행 상황 추적 가능
- Agent별 기여도 분석 가능

이 시스템을 통해 일관성 있고 추적 가능한 커밋 히스토리를 구축하세요!
