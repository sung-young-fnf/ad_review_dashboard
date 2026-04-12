# Hook 디버깅 가이드

## 🎯 개요

`.claude/hooks/pre/user-prompt-submit.sh` Hook에 상세 디버깅 로그가 추가되었습니다.

## 🔧 디버그 모드 활성화

### 방법 1: 환경 변수 설정

```bash
export HOOK_DEBUG=true
```

### 방법 2: 일회성 실행

```bash
HOOK_DEBUG=true echo "테스트 입력" | .claude/hooks/pre/user-prompt-submit.sh
```

## 📝 로그 파일 위치

```bash
/tmp/hook-debug.log
```

## 📊 로그 내용

### 1. Phase 0: stdin 읽기

```
[2025-11-21 15:16:27] === HOOK START ===
[2025-11-21 15:16:27] stdin detected, INPUT_JSON length: 3
[2025-11-21 15:16:27] jq not available or invalid JSON, using raw INPUT_JSON
[2025-11-21 15:16:27] Final USER_INPUT: '나자나' (length: 3)
```

**주요 확인 사항**:
- `INPUT_JSON length`: stdin 입력 길이
- `jq available` vs `jq not available`: JSON 파싱 여부
- `Final USER_INPUT`: 최종 추출된 사용자 입력

### 2. 빈 입력 체크

```
[2025-11-21 15:16:27] Empty or short input detected, exiting silently (length: 0)
```

**조건**:
- `length == 0` → 빈 입력
- `length < 2` → 너무 짧은 입력 (1자)

### 3. Agent 패턴 감지

```
[2025-11-21 15:16:27] Agent pattern detected, exiting to prevent recursion
```

**조건**: `🛑 STOP.*ANALYZE.*ROUTE` 패턴 포함 시 (무한 재귀 방지)

### 4. Phase 1: 키워드 분석

```
[2025-11-21 15:16:27] analyze_keywords called with input: '나자나'
[2025-11-21 15:16:27] Matched: bug
[2025-11-21 15:16:27] Matched: frontend
[2025-11-21 15:16:27] analyze_keywords result: ' bug frontend'
[2025-11-21 15:16:27] KEYWORDS extracted: ' bug frontend'
```

**주요 확인 사항**:
- 어떤 키워드가 매칭되었는지
- 최종 Agent 라우팅 방향

### 5. Phase 2: 출력 생성

```
[2025-11-21 15:16:27] Phase 2: Generating output
[2025-11-21 15:16:27] === HOOK END (exit 0) ===
```

## 🐛 간헐적 에러 디버깅

### 문제: "짧은 입력 시 Hook이 실행되지 않는다"

**디버깅 단계**:

1. **로그 수집**:
   ```bash
   HOOK_DEBUG=true
   # 문제 재현
   cat /tmp/hook-debug.log
   ```

2. **입력 길이 확인**:
   ```bash
   grep "Final USER_INPUT" /tmp/hook-debug.log
   # 출력: Final USER_INPUT: 'abc' (length: 3)
   ```

3. **빈 입력 체크 확인**:
   ```bash
   grep "Empty or short" /tmp/hook-debug.log
   ```

4. **JSON 파싱 확인**:
   ```bash
   grep "jq parsing" /tmp/hook-debug.log
   ```

### 문제: "jq 파싱 실패"

**로그 예시**:
```
[2025-11-21 15:17:44] jq parsing returned empty/null, using raw INPUT_JSON as fallback
```

**해결**:
- jq가 `user_prompt` 또는 `prompt` 키를 찾지 못함
- Hook이 자동으로 raw JSON 전체를 사용 (fallback)
- 정상 동작입니다.

### 문제: "Hook이 전혀 실행되지 않는다"

**디버깅**:
```bash
# Hook 실행 권한 확인
ls -l .claude/hooks/pre/user-prompt-submit.sh
# 출력: -rwxr-xr-x (실행 권한 있어야 함)

# 권한 추가
chmod +x .claude/hooks/pre/user-prompt-submit.sh
```

## 📈 성능 영향

**디버그 모드 비활성화 (기본)**:
- 로그 파일 생성 없음
- 성능 영향 없음 (조건 체크만)

**디버그 모드 활성화**:
- 로그 파일 크기: ~1KB/요청
- 성능 영향: ~5ms (무시 가능)

## 🔄 실제 케이스: 짧은 입력 ("나자나")

### 예상 동작

```
입력: "나자나" (3자)
길이: 3
조건: 3 >= 2 → 통과 ✅
결과: Hook 정상 실행
```

### 실제 로그

```
[2025-11-21 15:16:27] === HOOK START ===
[2025-11-21 15:16:27] stdin detected, INPUT_JSON length: 3
[2025-11-21 15:16:27] jq not available or invalid JSON, using raw INPUT_JSON
[2025-11-21 15:16:27] Final USER_INPUT: '나자나' (length: 3)
[2025-11-21 15:16:27] Input validation passed, continuing to Phase 1
...
[2025-11-21 15:16:27] === HOOK END (exit 0) ===
```

**결론**: 정상 작동 확인

## 🎓 개선 사항

### 이전 (v3.0)

```bash
if command -v jq &> /dev/null && echo "$INPUT_JSON" | jq -e . &>/dev/null; then
  USER_INPUT=$(echo "$INPUT_JSON" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null || echo "$INPUT_JSON")
else
  USER_INPUT="$INPUT_JSON"
fi
```

**문제**: jq 파싱 실패 시 fallback 불완전

### 이후 (v3.1 - 현재)

```bash
if command -v jq &> /dev/null; then
  if echo "$INPUT_JSON" | jq -e . &>/dev/null; then
    USER_INPUT=$(echo "$INPUT_JSON" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null)

    # jq 파싱 실패 시 fallback
    if [[ -z "$USER_INPUT" ]] || [[ "$USER_INPUT" == "null" ]]; then
      USER_INPUT="$INPUT_JSON"
    fi
  else
    USER_INPUT="$INPUT_JSON"
  fi
else
  USER_INPUT="$INPUT_JSON"
fi
```

**개선**:
1. jq 파싱 결과가 `empty` 또는 `null`인 경우 감지
2. raw JSON 전체를 fallback으로 사용
3. 모든 엣지 케이스 방어

## 🚀 디버그 모드 해제

```bash
unset HOOK_DEBUG
```

## 📚 참조

- Hook 파일: `.claude/hooks/pre/user-prompt-submit.sh`
- HOOK DEVELOPMENT RULES: `.claude/CLAUDE.md`
- Graceful Degradation 원칙: 모든 Hook은 `exit 0`으로 종료
