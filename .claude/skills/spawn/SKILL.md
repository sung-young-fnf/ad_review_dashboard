---
name: spawn
description: "cmux 새 워크스페이스에서 별도 Claude 세션 병렬 실행"
effort: low
---

# /spawn — cmux 병렬 Claude 세션 실행

> cmux 새 워크스페이스에서 별도 Claude 세션을 띄워 작업을 병렬 실행한다.

## Triggers
spawn, 새세션, 병렬세션, cmux session

## Use when
현재 세션을 유지하면서 별도 작업을 병렬로 실행하고 싶을 때.
모니터링 루프 유지 + 버그 수정 병렬, 여러 독립 작업 동시 실행 등.

## 사용법

```
/spawn notification_service.py:816 버그 수정해줘
/spawn --dir /Users/yun/work/other-project 다른 프로젝트 작업
/spawn /diagnose 서비스 로그 API 느린 원인 분석
```

### 옵션

| 플래그 | 설명 | 기본값 |
|--------|------|--------|
| `--dir <path>` | Claude 실행 디렉토리 | 현재 프로젝트 루트 |

## 동작

### 실행 흐름

1. **인자 파싱**: `--dir` 플래그와 프롬프트 분리
2. **디렉토리 결정**: `--dir` 지정 시 해당 경로, 아니면 현재 git 루트
3. **cmux 워크스페이스 생성**: `cmux new-workspace`
4. **디렉토리 이동**: `cmux send` → `cd {dir}`
5. **Claude 실행**: `cmux send` → `claude "{prompt}"` + Enter
6. **결과 보고**: 워크스페이스 ID 반환

### 구현

```bash
# 1. 디렉토리 결정
PROJECT_DIR="${dir:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# 2. cmux 새 워크스페이스 생성
WORKSPACE_ID=$(cmux new-workspace 2>&1 | awk '{print $2}')

# 3. 디렉토리 이동 + Claude 실행
cmux send --workspace "$WORKSPACE_ID" "cd $PROJECT_DIR"
cmux send-key --workspace "$WORKSPACE_ID" Enter
sleep 1
cmux send --workspace "$WORKSPACE_ID" "claude \"$PROMPT\""
cmux send-key --workspace "$WORKSPACE_ID" Enter
```

### 완료 보고

```
New Claude session spawned:
  Workspace: {workspace_id}
  Directory: {project_dir}
  Prompt: {first 80 chars of prompt}...

Switch: cmux 탭 전환으로 진행 상황 확인
```

## 주의사항

- cmux가 설치되어 있어야 함 (`/Applications/cmux.app`)
- 새 세션은 독립 컨텍스트 — 현재 세션의 변수/메모리 공유 안 됨
- git 충돌 주의: 두 세션이 같은 파일을 동시 수정하면 충돌 가능
- 세션 간 통신은 파일 시스템 (serena memory, docs/) 통해서만 가능
