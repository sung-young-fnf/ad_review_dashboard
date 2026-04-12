# TOON Format Guide

> Token-Oriented Object Notation - 40% fewer tokens than JSON/Markdown tables

## 📋 Why TOON?

[format-comparison: format, 100rows, tokens]
JSON, `[{"name":"A"...}]`, ~2000
Markdown Table, `| name | ver |`, ~1500
**TOON**, `[schema] + CSV`, ~800

**결과**: 40-60% 토큰 절약

---

## 🔧 Core Syntax

### 1. Schema Header
```
[schema-name: field1, field2, field3]
```

### 2. Data Rows (CSV-style)
```
value1, value2, value3
value1, value2, value3
```

### 3. Complete Example
```
[deps: name, version, purpose, status]
Next.js, 15.1.0, Framework, stable
React, 19.0.0, UI Library, stable
TypeScript, 5.3.3, Language, stable
```

---

## 📐 Patterns

### Pattern A: Simple Table
```
[users: id, name, role]
1, Alice, admin
2, Bob, user
```

### Pattern B: Multi-value (semicolons)
```
[config: key, values, default]
themes, dark;light;system, system
languages, ko;en;ja, ko
```

### Pattern C: API Routes
```
[api-routes: method, path, handler, auth]
GET, /users, UserController.list, required
POST, /users, UserController.create, admin-only
```

### Pattern D: Status Flags
```
[features: name, status, priority]
Dark Mode, ✅done, P1
SSO Login, 🔄progress, P0
Export PDF, ⏳pending, P2
```

---

## 🚫 Anti-Patterns

[anti-pattern: bad, good, reason]
`| Col | Col |` table, `[schema: col, col]`, 40% 토큰 절약
반복 `## Header` + bullets, `[items: name, value]`, 구조 일관성
JSON array, `[data: field1, field2]`, 가독성 + 절약

---

## 🎯 When to Use

[use-case: scenario, recommendation]
3+ 동일구조 항목, ✅ TOON 필수
2개 항목, ⚠️ TOON 선택
1개 항목, ❌ 일반 텍스트
복잡한 중첩, ❌ YAML/JSON 유지
코드 예시, ❌ 코드블록 유지

---

## 🔄 Conversion Rules

[conversion: from, to, example]
Markdown Table, TOON, `| A | B |` → `[t: a, b]` + `A, B`
Bullet Lists, TOON, `- **X**: val` → `[items: name, val]` + `X, val`
JSON Array, TOON, `[{"a":1}]` → `[data: a]` + `1`

---

## 📁 File Types

[file-type: extension, toon-usage]
*.md (docs), ✅ 테이블/목록 대체
CLAUDE.md, ✅ 규칙/매핑 테이블
tech-stack.md, ✅ 의존성/설정
code-structure.md, ✅ 폴더/패턴 매핑
*.yaml, ⚠️ 복잡한 중첩 유지
*.json, ⚠️ API 응답 유지

---

## 🤖 Auto-Apply Rules

[auto-apply: trigger, action]
3+ 동일구조 데이터, → TOON 변환
기존 Markdown 테이블, → TOON 변환
반복 bullet list, → TOON 변환

[exception: case, reason]
코드 블록 내용, 실행 가능 코드
1-2개 단순 항목, 오버헤드 > 이득
복잡한 중첩 구조, YAML/JSON 적합
API 스펙/스키마, 표준 포맷 유지

---

## ✅ Checklist

[checklist: question, if-yes]
3+ 동일구조 데이터?, → TOON 적용
Markdown 테이블 있음?, → TOON 변환
반복 bullet list?, → TOON 변환
위 모두 No?, → 현재 포맷 유지

---

**Version**: 1.1 (Self-TOONified)
**Created**: 2025-12-07
