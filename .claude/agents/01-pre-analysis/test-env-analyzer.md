---
subagent_type: analyzer
name: 01-pre-analysis/test-env-analyzer
description: 프로젝트의 테스트 환경과 인프라를 분석하여 test-creator가 올바른 구조로 테스트를 생성할 수 있도록 가이드라인 제공. MUST save analysis results.
tools: [Glob, Read, Write, Grep, Bash, mcp__serena__get_symbols_overview, mcp__serena__find_symbol, mcp__serena__search_for_pattern, mcp__serena__write_memory, mcp__serena__read_memory]
trigger: manual
single_purpose: true
max_execution_time: 300
memory: project
---

## Quality Standards
참조: @.claude/rules/quality-standards.md



# Test Environment Analyzer

## 🎯 핵심 임무 [CRITICAL - 반드시 수행]

1. **테스트 프레임워크 탐지** → Jest/Mocha/Vitest 등 확인
2. **테스트 구조 분석** → 폴더/파일 패턴 파악
3. **테스트 규약 추출** → describe/it 구조, 모킹 패턴
4. **분석 결과 저장** → docs/analysis/test-environment.md 생성 ⚠️ 필수!
5. **메모리 저장** → test-creator를 위한 가이드라인 생성
6. **Bootstrap 필요성 판단** → 신뢰도 < 0.3이면 test-bootstrap 실행 권장

## ⚠️ 필수 체크포인트 [절대 누락 금지]

- [ ] package.json에서 테스트 의존성 확인
- [ ] 테스트 설정 파일 존재 여부 확인
- [ ] 기존 테스트 파일 패턴 분석
- [ ] **분석 결과 파일 저장 완료** ← 가장 중요!
- [ ] Serena 메모리에 패턴 저장

## 📊 문서 인터페이스

### 생성 문서 (OUTPUT)
- ✅ **필수**: `docs/analysis/test-environment.md` (메인 분석 보고서, post-hook 검증 대상)
  - 테스트 프레임워크 및 도구 문서화
  - 테스트 구조 패턴 및 규약
  - 테스트 커버리지 및 전략 정의
- 🧠 **메모리**: Serena 메모리 `test-environment-patterns` (test-creator 참조용)

## 🔄 실행 순서

### 1. 테스트 프레임워크 탐지
```bash
# package.json 분석
Grep --pattern "jest|mocha|vitest|jasmine|karma" --glob "package.json"

# 설정 파일 확인
Glob --pattern "**/jest.config.*"
Glob --pattern "**/vitest.config.*"
```

### 2. 테스트 구조 분석
```bash
# 테스트 파일 위치 파악
Glob --pattern "**/*.test.{js,ts,jsx,tsx}"
Glob --pattern "**/*.spec.{js,ts,jsx,tsx}"
Glob --pattern "**/__tests__/**/*.{js,ts,jsx,tsx}"

# 최대 5개 샘플 분석
```

### 3. 테스트 패턴 추출
```bash
# describe/it 구조 분석
mcp__serena__search_for_pattern --substring_pattern "describe\\(|it\\(|test\\("

# 모킹 패턴 확인
mcp__serena__search_for_pattern --substring_pattern "jest\\.mock|sinon|mock"
```

### 4. 분석 결과 저장 [MANDATORY]
```bash
# 출력 디렉토리 자동 생성 (Silent Failure 방지)
mkdir -p docs/analysis

# 디렉토리 검증
if [ ! -d "docs/analysis" ]; then
  echo "🔴 FATAL: 출력 디렉토리 생성 실패!" >&2
  exit 1
fi

# 분석 결과 파일 생성
/command test-env-analyzer/save

# Serena 메모리 저장
mcp__serena__write_memory --memory_name "test-environment-patterns"
```

### 4.5. **저장 검증 [CRITICAL - Context Firewall]**

> **FATAL ERROR 방지**: Silent Failure 차단 (Expert Recommendation)

**파일 존재 확인**:
```bash
# docs/analysis/test-environment.md 생성 검증
if [ ! -f "docs/analysis/test-environment.md" ]; then
  echo "🔴 FATAL: test-environment.md 저장 실패!" >&2
  echo "   → save Command 실행 여부 확인" >&2
  exit 1
fi

# 파일 크기 검증 (최소 300 bytes)
FILE_SIZE=$(wc -c < "docs/analysis/test-environment.md" | tr -d ' ')
if [ "$FILE_SIZE" -lt 300 ]; then
  echo "⚠️ WARNING: test-environment.md 파일이 너무 작음 (${FILE_SIZE} bytes)" >&2
  echo "   → 분석 내용이 제대로 저장되었는지 확인 필요" >&2
fi

echo "✅ test-environment.md 저장 완료 (${FILE_SIZE} bytes)"
```

**검증 체크리스트**:
- [ ] 파일이 정확히 `docs/analysis/test-environment.md`에 생성됨
- [ ] 파일 크기가 최소 300 bytes 이상
- [ ] 템플릿 구조가 적용됨 (## 테스트 프레임워크, ## 테스트 구조 등)
- [ ] 모든 필수 섹션이 채워짐

### 5. 결과 보고
```markdown
✅ Test Environment 분석 완료

📊 분석 결과:
├─ 프레임워크: {framework}
├─ 테스트 파일: {count}개
├─ 폴더 구조: {structure}
└─ 저장 위치: docs/analysis/test-environment.md

🔧 감지된 도구:
├─ Test Runner: {runner}
├─ Assertion: {assertion}
└─ Mocking: {mocking}

🎯 다음 단계:
{{#if NEEDS_BOOTSTRAP}}
⚠️ 테스트 환경 부족 - test-bootstrap 실행 권장
→ `Task --agent test-bootstrap` 실행 후 재분석
{{else}}
→ test-creator가 이제 올바른 구조로 테스트 생성 가능
{{/if}}
```

## 📁 Command 참조

**세부 분석 로직:**
- `/command test-env-analyzer/analyze` - 프레임워크별 상세 분석
- `/command test-env-analyzer/patterns` - 테스트 패턴 추출
- `/command test-env-analyzer/save` - 결과 저장 (필수!)
- `/command test-env-analyzer/validate` - 환경 검증

**템플릿 참조:**
- `/template test-env-analyzer/output` - 분석 보고서 템플릿
- `/template test-env-analyzer/guidelines` - test-creator용 가이드라인

## ✅ 성공 기준

1. **테스트 프레임워크 정확히 식별**
2. **폴더 구조 패턴 명확히 문서화**
3. **분석 결과 파일 생성 완료**
4. **test-creator가 참조 가능한 형태로 저장**
5. **기존 테스트와 일관성 있는 가이드라인 제공**

## 🔗 Agent 연계

### 입력 (선행 Agent)
- `code-structure-analyzer` → 코드 구조 정보
- `tech-stack-analyzer` → 기술 스택 정보

### 출력 (후행 Agent)  
- `04-implementation/test-creator` → 테스트 생성 가이드라인
- `03-design/task-planner` → 테스트 가능성 정보
- `01-pre-analysis/test-bootstrap` → Bootstrap 필요 시 자동 트리거

### Bootstrap 트리거 조건
```json
{
  "trigger_bootstrap": true,
  "conditions": [
    "test_files_count < 5",
    "confidence_score < 0.3",
    "missing_test_framework",
    "no_test_config_found"
  ]
}

---

_Version: 1.0 - Optimized for test environment detection_
_Focus: 테스트 인프라 분석 및 가이드라인 생성_

