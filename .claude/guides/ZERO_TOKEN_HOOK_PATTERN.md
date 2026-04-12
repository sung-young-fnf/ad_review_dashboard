# Zero-Token Hook Pattern Guide

> **목적**: Claude Code 세션의 토큰 소비를 최소화하는 Hook 작성 가이드
> **참조 프로젝트**: claude-code-auto-memory
> **적용일**: 2025-12-02

---

## 📋 개요

### 문제점
기존 Claude Code Hook은 stdout으로 상태 메시지를 출력하여 메인 대화에 토큰을 소비합니다:

```bash
# ❌ 기존 패턴 - 매 실행마다 ~500 토큰 소비
echo "✅ Pattern compliance check passed"
echo "📊 Checked files: 5"
echo "⚠️ Warnings: 2"
```

### 해결책
Zero-Token 패턴은 stdout 대신 `.dirty-files` 마커 시스템을 사용하여 토큰 소비를 0으로 줄입니다:

```bash
# ✅ Zero-Token 패턴 - 0 토큰 소비
source "$REPO_ROOT/.claude/utils/mark-dirty.sh"
mark_dirty_file "$FILE" "pattern" "OK"
```

---

## 🏗️ 아키텍처

### 토큰 흐름 비교

```
[기존 패턴]
Hook 실행 → stdout 출력 → Claude 메인 대화로 전달 → 토큰 소비
                ↓
         ~500-1200 토큰/실행

[Zero-Token 패턴]
Hook 실행 → .dirty-files 기록 → 별도 프로세스가 처리
                ↓
           0 토큰/실행
```

### 파일 구조

```
.claude/
├── utils/
│   └── mark-dirty.sh      # 마커 유틸리티 (모든 Hook에서 공유)
├── .dirty-files           # 마커 기록 파일 (런타임 생성)
├── hooks/
│   ├── pre/
│   │   └── duplicate-detector.sh    # Zero-Token 적용
│   └── post/
│       └── pattern-compliance-checker.sh  # Zero-Token 적용
└── guides/
    └── ZERO_TOKEN_HOOK_PATTERN.md   # 이 가이드
```

---

## 🛠️ 구현 가이드

### 1. mark-dirty.sh 소스 로드

모든 Zero-Token Hook은 시작 시 유틸리티를 로드합니다:

```bash
#!/bin/bash
# Zero-Token Hook Example

# 프로젝트 루트 감지
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# mark-dirty.sh 로드 (Fallback 포함)
MARK_DIRTY_SCRIPT="$REPO_ROOT/.claude/utils/mark-dirty.sh"
if [[ -f "$MARK_DIRTY_SCRIPT" ]]; then
    source "$MARK_DIRTY_SCRIPT"
else
    # Fallback: 유틸리티 없을 때 최소 구현
    mark_dirty_file() {
        local file="$1"
        local check_type="${2:-general}"
        local check_status="${3:-OK}"
        echo "${check_status}:${check_type}:${file}" >> "$REPO_ROOT/.claude/.dirty-files"
    }
fi
```

### 2. 상태 기록 패턴

```bash
# 성공 기록
mark_dirty_file "$FILE_PATH" "pattern-check" "OK"

# 경고 기록
mark_dirty_file "$FILE_PATH" "component-conflict" "WARN"

# 에러 기록 (차단 필요 시)
mark_dirty_file "$FILE_PATH" "duplicate-page" "ERROR"
```

### 3. 차단 시에만 최소 출력

```bash
# 심각한 위반 시에만 stderr로 최소 출력
if [[ $violations -gt 0 ]]; then
    echo "❌ 중복 감지: 로그 확인 → $LOG_FILE" >&2
    exit 2
fi

# 성공 시 출력 없음 (Zero-Token)
exit 0
```

---

## 📁 .dirty-files 포맷

### 레코드 구조

```
[STATUS]:[CHECK_TYPE]:[FILE_PATH]
```

- **STATUS**: `OK`, `WARN`, `ERROR`
- **CHECK_TYPE**: 체크 종류 (예: `pattern`, `duplicate`, `quality`)
- **FILE_PATH**: 상대 경로

### 예시

```
OK:pattern:src/app/page.tsx
WARN:component-conflict:src/components/Button.tsx
ERROR:duplicate-page:src/app/admin/page.tsx
OK:duplicate-check:src/utils/helper.ts
```

---

## 🔧 사용 가능한 함수

### mark_dirty_file

파일 변경/체크 결과를 기록합니다.

```bash
mark_dirty_file "path/to/file.ts"                    # 기본: OK:general
mark_dirty_file "path/to/file.ts" "pattern"          # OK:pattern
mark_dirty_file "path/to/file.ts" "pattern" "ERROR"  # ERROR:pattern
```

### get_dirty_files

기록된 모든 레코드를 조회합니다.

```bash
get_dirty_files                  # 전체 조회
get_dirty_files "^ERROR:"        # ERROR만 필터
get_dirty_files ":pattern:"      # pattern 체크만 필터
```

### get_dirty_file_paths

파일 경로만 추출합니다 (중복 제거).

```bash
paths=$(get_dirty_file_paths)
paths=$(get_dirty_file_paths "^ERROR:")  # ERROR 파일만
```

### get_dirty_count

레코드 수를 반환합니다.

```bash
total=$(get_dirty_count)
errors=$(get_dirty_count "^ERROR:")
```

### has_dirty_files

dirty 파일 존재 여부를 반환합니다 (exit code).

```bash
if has_dirty_files; then
    echo "처리할 파일 있음"
fi

if has_dirty_files "^ERROR:"; then
    echo "에러 있음"
fi
```

### has_errors

ERROR 상태 파일 존재 여부 (편의 함수).

```bash
if has_errors; then
    echo "에러 발생!"
fi
```

### clear_dirty_files

레코드를 비웁니다.

```bash
clear_dirty_files              # 전체 삭제
clear_dirty_files "^ERROR:"    # ERROR만 삭제
```

### remove_dirty_file

특정 파일 레코드를 삭제합니다.

```bash
remove_dirty_file "src/app/page.tsx"
```

### export_dirty_summary

디버그용 요약을 출력합니다.

```bash
export_dirty_summary
# 출력:
# Dirty Files Summary:
#   Total: 10
#   OK: 7
#   ERROR: 2
#   WARN: 1
```

---

## 📊 토큰 절감 효과

### 변환 전후 비교

| Hook | 기존 | Zero-Token | 절감률 |
|------|------|------------|--------|
| pattern-compliance-checker | ~500 토큰 | 0 토큰 | **100%** |
| duplicate-detector | ~1200 토큰 | ~50 토큰* | **96%** |

\* 차단 시에만 최소 stderr 출력

### 세션당 예상 절감

- 평균 Hook 실행: 10-20회/세션
- 예상 절감: **~15,000 토큰/세션**

---

## ✅ 체크리스트: Hook Zero-Token 변환

기존 Hook을 Zero-Token으로 변환할 때:

### 필수 변경
- [ ] `source "$REPO_ROOT/.claude/utils/mark-dirty.sh"` 추가
- [ ] Fallback `mark_dirty_file` 함수 정의
- [ ] 모든 `echo` 문을 `mark_dirty_file` 호출로 변환
- [ ] 성공 시 stdout 출력 완전 제거

### 선택 변경 (권장)
- [ ] 로그 파일 사용 (`LOG_FILE="/tmp/hook-name.log"`)
- [ ] 로깅 함수 정의 (`log() { echo "[$(date)] $*" >> "$LOG_FILE"; }`)
- [ ] 차단 시에만 stderr로 최소 메시지

### 검증
- [ ] 성공 시 stdout 출력 없음 확인
- [ ] `.dirty-files`에 레코드 기록 확인
- [ ] 기존 기능 정상 동작 확인

---

## 🧪 테스트 방법

### 단위 테스트

```bash
.claude/tests/test-dirty-files.sh
```

### 통합 테스트

```bash
.claude/tests/test-zero-token-integration.sh
```

### 수동 테스트

```bash
# 1. dirty 파일 초기화
rm -f .claude/.dirty-files

# 2. Hook 수동 실행
echo '{"tool_name":"Write","tool_input":{"file_path":"src/app/page.tsx"}}' | \
  .claude/hooks/pre/duplicate-detector.sh

# 3. 결과 확인
cat .claude/.dirty-files
```

---

## 🔗 관련 문서

- `.claude/utils/mark-dirty.sh` - 마커 유틸리티 소스
- `.claude/tests/test-dirty-files.sh` - 유틸리티 단위 테스트
- `.claude/tests/test-zero-token-integration.sh` - 통합 테스트
- `.reference/claude-code-auto-memory/` - 참조 프로젝트

---

## 📝 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|----------|
| 2025-12-02 | 1.0 | 초기 작성 - S01 Zero-Token Hook Pattern 구현 |

---

_이 가이드는 EP001_hook-memory-optimization Epic의 S01_zero-token-hook-pattern Story 구현 결과입니다._
