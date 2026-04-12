# 05-post-implementation

Epic 완료 후 정리 및 백로그 관리를 담당하는 Post-Implementation Agent들입니다.

## Agent 목록

### epic-finalizer.md
- Epic 완료 상태 검증 및 최종 정리
- 하이브리드 백로그 구조 생성 (완료/미완료 분리)
- Epic 대시보드 및 완료 리포트 생성

### backlog-organizer.md  
- _backlog/ 폴더 구조 관리
- 미완료 Task 우선순위 재평가
- 백로그 정리 및 README.md 생성

## 실행 흐름

1. **epic-finalizer**: Epic 완료 검증 → 백로그 정리 → 대시보드 생성
2. **backlog-organizer**: 백로그 구조 관리 → 우선순위 재평가

## 명령어

- `/claude epic-finalizer verify` - Epic 완료 상태 검증
- `/claude epic-finalizer finalize` - Epic 완료 처리 및 백로그 정리  
- `/claude epic-finalizer dashboard` - 완료 대시보드 생성
- `/claude backlog-organizer organize` - 백로그 구조 정리
- `/claude backlog-organizer prioritize` - 백로그 우선순위 재평가
