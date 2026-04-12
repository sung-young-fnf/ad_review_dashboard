---
module: "{모듈명}"
date: "YYYY-MM-DD"
problem_type: "{build_error|runtime_error|performance_issue|database_issue|security_issue|api_integration|ui_bug|auth_issue|deployment_issue}"
component: "{영향받은 컴포넌트}"
symptoms:
  - "{증상 1}"
  - "{증상 2}"
root_cause: "{근본 원인 키워드}"
severity: "{critical|high|medium|low}"
service: "{mcp-orbit|ai-agent|app-hub|agent-office-phaser}"
tags: ["{태그1}", "{태그2}"]
related_docs: []
---

# {문제 제목}

## 증상

{관찰된 에러/동작. 정확한 에러 메시지 포함}

```
{에러 메시지 또는 로그}
```

## 조사 과정

### 시도 1: {접근법}
- **결과**: 실패
- **이유**: {왜 효과 없었는지}

### 시도 2: {접근법}
- **결과**: 실패/부분 성공
- **이유**: {왜 효과 없었는지}

## 근본 원인

{기술적 설명 - "무엇"이 아니라 "왜" 초점}

## 솔루션

### Before

```typescript
// {파일경로}:{라인번호}
{문제가 있던 코드}
```

### After

```typescript
// {파일경로}:{라인번호}
{수정된 코드}
```

### 변경 요약

- {변경사항 1}
- {변경사항 2}

## 예방

- {향후 같은 문제 방지 방법 1}
- {향후 같은 문제 방지 방법 2}

## 관련 문서

- {관련 docs/solutions/ 문서 링크}
- {관련 Epic/Task 링크}
