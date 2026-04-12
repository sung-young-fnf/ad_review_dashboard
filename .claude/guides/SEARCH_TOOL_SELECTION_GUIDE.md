# 검색 도구 선택 가이드

> 상황별 최적 검색 도구 선택으로 토큰 효율 극대화

## 검색 도구 비교

```
[search-tools: tool, type, speed, use-case]
Grep, 텍스트 기반 (ripgrep), 매우 빠름, 문자열/정규식 패턴 검색
Glob, 파일명 패턴, 매우 빠름, 파일 경로 찾기
Serena, 심볼 기반 (LSP), 보통, 프로젝트 내부 심볼 관계 추적
ast-grep, AST 기반 구조, 보통, 코드 구조 패턴 매칭/리팩토링
```

## 상황별 추천 도구

```
[scenario: need, tool, example]
"이 문자열 어디에?", Grep, pattern="fetchWithAuth" → 텍스트 매칭
"이 파일 어디에?", Glob, pattern="**/user*.tsx" → 파일 경로
"이 클래스 어디서 사용?", Serena, find_referencing_symbols → 심볼 관계
"빈 의존성 useEffect?", ast-grep, pattern="useEffect($$$, [])" → 구조 매칭
"console.log 전부 찾기", ast-grep, pattern="console.log($$$)" → 정확한 호출만
```

## 도구별 상세

### Grep (내장) - 기본 선택
```
용도: 텍스트/정규식 패턴 검색
장점: 빠름, 정규식, 컨텍스트 라인(-A/-B/-C)
단점: 구문 비인식 (주석/문자열 구분 불가)
```
```bash
Grep pattern="fetchWithAuth" glob="*.ts" output_mode="content" -C=2
```

### Glob (내장) - 파일 찾기
```
용도: 파일 경로/이름 패턴 검색
장점: 매우 빠름, 간단한 패턴
단점: 파일 경로만 검색
```
```bash
Glob pattern="**/components/**/*.tsx"
```

### Serena (MCP) - 심볼 추적
```
용도: 클래스/함수 정의 및 참조 추적
장점: 정확한 심볼 위치, 관계 추적, 리팩토링 지원
단점: 외부 라이브러리 불가 (React hooks 등)
```
```bash
mcp-cli call serena/find_symbol '{"name_path_pattern": "McpServer"}'
mcp-cli call serena/find_referencing_symbols '{"name_path": "McpServer", "relative_path": "src/models.ts"}'
```

### ast-grep (MCP) - 구조 검색
```
용도: AST 기반 코드 구조 패턴 검색
장점: 구문 구조 이해, 변수 캡처($VAR, $$$), 정확한 패턴 매칭
단점: 언어별 설정 필요, 복잡한 패턴 작성
```
```bash
# 빈 의존성 배열 useEffect 찾기
mcp-cli call ast-grep/find_code '{"project_folder": "/path", "pattern": "useEffect(() => { $$$BODY }, [])", "language": "tsx"}'

# async 함수 찾기
mcp-cli call ast-grep/find_code '{"project_folder": "/path", "pattern": "async function $NAME($ARGS)", "language": "typescript"}'

# YAML 규칙으로 복잡한 패턴
mcp-cli call ast-grep/find_code_by_rule '{"project_folder": "/path", "yaml": "id: find-console\nlanguage: typescript\nrule:\n  pattern: console.log($$$)"}'
```

## 검색 전략 흐름도

```
┌─────────────────────────────────────────────────────┐
│ 무엇을 찾는가?                                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  파일 경로/이름 ────────────→ Glob                   │
│                                                     │
│  문자열/정규식 ─────────────→ Grep                   │
│                                                     │
│  심볼 정의/참조 ────────────→ Serena                 │
│                                                     │
│  코드 구조/패턴 ────────────→ ast-grep               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## 실전 비교 예시

### "useEffect 찾기" - 도구별 결과 차이

```bash
# Grep: 모든 useEffect 텍스트 매칭 (의존성 무관)
Grep pattern="useEffect\(\(\) =>"
→ 결과: 모든 useEffect (주석 포함)

# ast-grep: 빈 의존성 배열만 정확히
mcp-cli call ast-grep/find_code '{"pattern": "useEffect(() => { $$$BODY }, [])"}'
→ 결과: [] 의존성만 12개 (구조적 매칭)
```

### "클래스 사용처 찾기" - 도구별 결과 차이

```bash
# Grep: McpServer 텍스트 포함 모든 곳
Grep pattern="McpServer"
→ 결과: 정의, 사용, 주석, 문서 모두 포함

# Serena: 심볼 정의 위치만 정확히
mcp-cli call serena/find_symbol '{"name_path_pattern": "McpServer"}'
→ 결과: Interface 정의 3곳 (정확한 위치)
```

## 복합 검색 패턴

### 리팩토링 대상 찾기
```bash
# Step 1: ast-grep으로 안티패턴 검색
mcp-cli call ast-grep/find_code '{"pattern": "console.log($$$)"}'

# Step 2: Serena로 해당 함수의 호출처 확인
mcp-cli call serena/find_referencing_symbols '{"name_path": "targetFunction", "relative_path": "found/file.ts"}'
```

### deprecated 함수 마이그레이션
```bash
# Step 1: Grep으로 대략적 사용처 파악
Grep pattern="deprecated_function" output_mode="files_with_matches"

# Step 2: ast-grep으로 정확한 호출 패턴 확인
mcp-cli call ast-grep/find_code '{"pattern": "deprecated_function($ARGS)"}'
```

## 주의사항

```
[warnings: tool, warning]
Grep, 주석/문자열 내 매칭 포함 → 수동 필터링 필요
Serena, 외부 라이브러리 심볼 추적 불가 (React hooks 등)
ast-grep, 언어 파라미터 명시 권장 (tsx/typescript/python 등)
Bash find/grep, 내장 도구 사용 권장 → 토큰 효율
```

## 권장 우선순위

```
1. Glob     → 파일 위치 확인 (가장 빠름)
2. Grep     → 텍스트 패턴 검색 (기본 선택)
3. ast-grep → 코드 구조 패턴 (정확한 매칭)
4. Serena   → 심볼 관계 추적 (리팩토링)
```

## 검색 결과 해석 휴리스틱 (Mantic Brain Scorer 착안)

> WHY: Grep/Glob 결과가 다수일 때 어떤 파일을 먼저 봐야 하는지 판단 기준.
> 파일 내용을 읽기 전에 경로/파일명만으로 관련성을 추론하여 토큰 절감.

### 1. Definition > Implementation > Test 우선순위

검색 결과에서 **정의 파일을 먼저 확인**하고, 테스트 파일은 후순위로.

```
[priority: pattern, type, action]
높음, .model. / .schema. / .entity. / .type. / /models/ / /schemas/, Definition, 먼저 읽기
중간, .service. / .controller. / .handler. / /services/ / /controllers/, Implementation, 두 번째
낮음, .test. / .spec. / .e2e. / /__tests__/ / /tests/, Test, 필요 시만
```

예시: `Grep "PaymentService"` 결과가 15건이면:
1. `payment.schema.ts` → 먼저 (데이터 구조 파악)
2. `payment.service.ts` → 그다음 (비즈니스 로직)
3. `payment.test.ts` → 필요 시만 (테스트 참고)

### 2. CamelCase 정규화 검색

검색 대상이 CamelCase/snake_case 혼용일 때, **양쪽 패턴을 모두 검색**.

```
[query: input, grep-patterns]
ScriptController, "ScriptController" + "script_controller" + "script-controller"
UserService, "UserService" + "user_service" + "user-service"
handleLogin, "handleLogin" + "handle_login" + "handle-login"
```

적용 방법:
```bash
# CamelCase 심볼 검색 시 snake_case 변환도 함께
Grep pattern="ScriptController|script_controller|script-controller"
```

Python(snake_case) ↔ TypeScript(camelCase) 모노레포에서 특히 중요.

### 3. 최근 수정 파일 우선 탐색 (Recency Boost)

code-writer Phase 0에서 **최근 수정된 파일을 먼저 탐색**.

```bash
# Phase 0 시작 시 실행
git diff --name-only HEAD~3   # 최근 3커밋 변경 파일
git diff --name-only           # 현재 unstaged 변경 파일
```

이유: 최근 수정 파일이 현재 작업과 관련될 확률이 높음.
적용: 검색 결과 중 최근 수정 파일이 있으면 **먼저 Read**.

---

## 참조
- Grep: Claude Code 내장 (ripgrep 기반)
- Glob: Claude Code 내장
- Serena: `.mcp.json` 설정 (LSP 기반)
- ast-grep: `.mcp.json` 설정 (https://ast-grep.github.io/)
- 휴리스틱 출처: Mantic.sh Brain Scorer 알고리즘 (v1.0.25) 분석 후 개념 차용
