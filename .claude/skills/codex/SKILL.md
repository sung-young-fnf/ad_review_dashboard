---
name: codex
description: "OpenAI Codex CLI로 리서치/분석/코드 생성 위임"
effort: low
---

# /codex — Codex CLI로 작업 위임

> OpenAI Codex CLI를 호출하여 리서치, 분석, 코드 생성 등의 작업을 실행한다.

## 사용법

```
/codex 최신 릴리즈 노트 조사해줘
/codex -m o3 웹서치로 경쟁 제품 비교해줘
/codex --search AI 코딩 도구 시장 트렌드
/codex --write --dir ./src 테스트 코드 작성해줘
```

### 옵션

| 플래그 | 설명 | 기본값 |
|--------|------|--------|
| `-m <model>` | Codex 모델 (o3, o4-mini 등) | codex 기본 모델 |
| `--search` | 웹 검색 활성화 | off |
| `--write` | workspace 쓰기 허용 | off (read-only) |
| `--dir <path>` | 작업 디렉토리 | 현재 워크스페이스 |

## 동작

Solo 모드. 직접 `codex exec`를 실행하고 결과를 반환한다.

### 실행 흐름

1. **인자 파싱**: 플래그(`-m`, `--search`, `--write`, `--dir`)와 프롬프트를 분리
2. **명령어 구성**: 파싱된 옵션으로 `codex exec` 명령어 조립
3. **실행**: Bash로 codex exec 실행 (타임아웃 600초)
4. **결과 읽기**: 출력 파일에서 결과 캡처
5. **반환**: 결과를 사용자에게 출력

### 명령어 구성 규칙

기본 형태:
```bash
codex exec [OPTIONS] --ephemeral --skip-git-repo-check -o /tmp/codex-skill-{timestamp}.md "PROMPT"
```

옵션 매핑:
- `-m <model>` → `-m <model>`
- `--search` → `-c 'web_search="live"'`
- `--write` → `--full-auto` (없으면 `-s read-only`)
- `--dir <path>` → `-C <path>`

### 실행 예시

```bash
# 기본 리서치 (읽기 전용)
codex exec -s read-only --ephemeral --skip-git-repo-check \
  -o /tmp/codex-skill-1234.md "최신 릴리즈 노트 조사해줘"

# 웹 검색 + 모델 지정
codex exec -m o3 -c 'web_search="live"' -s read-only --ephemeral --skip-git-repo-check \
  -o /tmp/codex-skill-1234.md "경쟁 제품 비교해줘"

# 쓰기 모드
codex exec --full-auto --ephemeral \
  -C ./src -o /tmp/codex-skill-1234.md "테스트 코드 작성해줘"
```

## 백그라운드 실행

오래 걸리는 작업은 `codex-delegate` 에이전트에 위임하여 백그라운드 실행 가능:

```
Task tool → subagent_type: "99-utils/codex-delegate"
           prompt: "-m o3 --search 심층 리서치 해줘"
           run_in_background: true
```

## 완료 조건

- codex exec 정상 실행 (exit code 0)
- 출력 파일에서 결과 캡처 성공
- 결과를 사용자에게 출력 완료
- 임시 파일(`/tmp/codex-skill-*`) 정리

## 참조

- Agent: `.claude/agents/99-utils/codex-delegate.md`
- Codex CLI: `codex exec --help`
