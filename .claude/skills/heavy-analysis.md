---
context: fork
agent: file-analyzer
description: "무거운 분석 작업을 fork된 컨텍스트에서 실행"
---

# Heavy Analysis Skill

이 skill은 대용량 파일 분석을 fork된 컨텍스트에서 실행합니다.
메인 컨텍스트를 오염시키지 않고 분석 결과만 반환합니다.

## 사용 시나리오

### 1. 대용량 로그 분석
```bash
@heavy-analysis /var/log/application.log
```
- 10MB+ 로그 파일 분석
- 에러 패턴 추출
- 메인 컨텍스트에는 요약만 반환

### 2. 전체 디렉토리 코드 분석
```bash
@heavy-analysis apps/frontend/src/
```
- 수백 개 파일 스캔
- 중복 코드, 미사용 import 탐지
- fork 컨텍스트에서 실행 후 결과만 반환

### 3. 테스트 커버리지 분석
```bash
@heavy-analysis coverage/lcov-report/
```
- HTML 리포트 파싱
- 낮은 커버리지 영역 식별
- 압축된 리포트만 메인으로 전달

## 동작 원리

### Fork Context의 장점
1. **메인 컨텍스트 보존**: 분석 중간 결과가 메인을 오염시키지 않음
2. **메모리 효율**: fork는 별도 메모리에서 실행
3. **실패 격리**: 분석 실패해도 메인 세션 영향 없음

### 반환 형식
```yaml
summary: "분석 결과 요약 (1-3줄)"
findings:
  - type: "error|warning|info"
    location: "파일:라인"
    message: "발견 내용"
recommendation: "권장 조치"
```

## 제한사항

- Fork 컨텍스트는 메인과 상태 공유 불가
- 파일 수정은 메인에서 수행 필요
- 분석 결과만 반환 (중간 과정 미포함)

## 관련 Skills

- `@file-analyzer`: 단일 파일 분석 (fork 불필요)
- `@code-analyzer`: 코드 품질 분석
- `@test-runner`: 테스트 실행 및 결과 분석
