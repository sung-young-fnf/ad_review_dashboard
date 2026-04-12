# 📚 DOCUMENTATION ARCHITECTURE (Index + Detail Pattern)

> **원칙**: 문서의 80/20 법칙 - Index는 80% 이해 제공 (300-500 tokens), Detail은 20% 심화 (1000-2000 tokens)

## 📊 패턴 개요

**문제**: 단일 문서(God Object)가 비대해지면 Agent가 전체를 읽어 토큰 낭비 + 컨텍스트 오염

**해결**: Index + Detail 2단계 문서화
```yaml
Index (Primary):
  위치: docs/analysis/{topic}.md
  크기: 300-500 tokens (~1500-2500 bytes)
  목적: Agent가 80% 이해 달성
  내용: High-level 개요, 핵심 패턴, Quick Reference

Detail (Secondary):
  위치: docs/analysis/architecture/{topic}-{aspect}.md
  크기: 1000-2000 tokens (~5000-10000 bytes)
  목적: 20% 심화 학습
  내용: 상세 구현, 코드 예제, 고급 패턴
```

## 📋 실제 적용 사례

### ✅ code-structure.md (Index 역할)
**경로**: [docs/analysis/code-structure.md](docs/analysis/code-structure.md)
**크기**: 4272 bytes (~500 tokens)
**목적**: "프로젝트 아키텍처가 어떻게 구성되어 있는가?" 80% 답변

**포함 내용**:
```markdown
## High-Level Architectural Pattern
- 패턴 이름 + 1-2문장 설명 (FSD, CQRS Light)

## Core Application Flow
- Request → Response 경로 (3-5 스텝)

## Key Directory Map
- 5-10개 핵심 디렉토리만 (전체 구조 아님)

## 핵심 패턴 Quick Reference (3-5개)
- 각 패턴마다 1-2줄 + 상세 문서 링크

## Further Reading
- architecture/*.md로 연결
```

**금지 사항** (Detail 영역):
- ❌ 의존성 버전 정보 (tech-stack.md 전용)
- ❌ 전체 디렉토리 트리 (architecture/*.md에만)
- ❌ 상세 코드 예제 (architecture/*.md에만)

### ✅ architecture/frontend-structure.md (Detail 역할)
**경로**: [docs/analysis/architecture/frontend-structure.md](docs/analysis/architecture/frontend-structure.md)
**목적**: "FSD 패턴이 구체적으로 어떻게 적용되었는가?" 20% 심화

**포함 내용**:
- Next.js App Router 설정 상세
- Widget 의존성 규칙 예제
- React 컴포넌트 패턴 코드

### ✅ tech-stack.md (Index 역할)
**경로**: [docs/analysis/tech-stack.md](docs/analysis/tech-stack.md)
**목적**: "무엇으로 만들어졌는가?"

**책임 범위**:
- ✅ 의존성 목록 (dependencies)
- ✅ 버전 정보 (versions)
- ✅ 보안 취약점 (security vulnerabilities)

**금지 사항** (Single Responsibility):
- ❌ 아키텍처 패턴 → code-structure.md로 이관
- ❌ 디렉토리 구조 → code-structure.md로 이관

## 🎯 Agent 사용 가이드라인

### Phase 1: Index 우선 읽기
```bash
# ✅ 올바른 순서
1. Read docs/analysis/code-structure.md  # 80% 이해
2. 필요 시만: Read docs/analysis/architecture/frontend-structure.md  # 20% 심화
```

```bash
# ❌ 잘못된 순서 (토큰 낭비)
1. Read docs/analysis/architecture/frontend-structure.md  # 상세부터 읽음
2. Read docs/analysis/code-structure.md
```

### Phase 2: 조건부 Detail 읽기
```yaml
Detail 문서 읽기 조건:
  ✅ Index에서 찾을 수 없는 구체적 구현 정보 필요
  ✅ 코드 예제가 반드시 필요한 경우
  ✅ 특정 패턴의 에지 케이스 처리 방법

Detail 읽지 않아도 됨:
  ❌ Index로 충분히 답변 가능
  ❌ 일반적인 개요 질문
  ❌ 단순 확인 작업
```

## 📐 문서 작성 템플릿

### Index 문서 템플릿
```markdown
# {Topic} - Index

> **개요**: {핵심 질문에 대한 1줄 답변}
> **세부 문서**: architecture/{topic}-*.md 참조

## High-Level Overview (2-3 문단)
- 패턴/도구의 핵심 개념
- 프로젝트에서의 역할

## Key Concepts (5-10개 항목)
- 각 개념마다 1-2줄 설명
- 상세 링크: @docs/analysis/architecture/{topic}-{concept}.md

## Quick Reference (3-5개 패턴)
- 자주 사용하는 패턴 요약
- 코드 예제는 최소화 (1-2줄)

## Further Reading
- architecture/*.md 링크 (5-10개)
```

### Detail 문서 템플릿
```markdown
# {Topic} - {Aspect} 상세

> **전제**: [docs/analysis/{topic}.md](../{topic}.md) Index를 먼저 읽을 것

## 개요
- Index에서 제시한 개념의 구체적 구현

## 상세 구현 가이드
- 코드 예제 포함 (10-30줄)
- 실제 프로젝트 파일 참조

## 고급 패턴
- 에지 케이스 처리
- 최적화 기법

## 실제 사례
- 프로젝트에서의 실제 구현 예제
```

## 🔗 Cross-Reference 규칙

### Index → Detail 연결
```markdown
## 핵심 패턴 Quick Reference

### 1. Admin Impersonation (관리자 전환)
- `session.backendToken` 사용
- `X-Impersonate-User` 헤더 추가
- 상세: @docs/patterns/fullstack/admin-impersonation.md
```

### Detail → Index 역참조
```markdown
# Admin Impersonation 상세

> **전제**: [code-structure.md](../../analysis/code-structure.md) Index를 먼저 읽을 것

이 문서는 API Routes의 Admin Impersonation 패턴을 상세히 설명합니다.
```

## ✅ 성공 기준

1. **토큰 효율**: Index 읽기만으로 80% 질문 답변 가능
2. **크기 제한**: Index 500 tokens 이하, Detail 2000 tokens 이하
3. **중복 제거**: 같은 정보가 여러 문서에 존재하지 않음
4. **명확한 책임**: 각 문서가 하나의 핵심 질문에 답변

## 📊 효과 측정 (Phase 2 완료 시점)

**Before (God Object)**:
- code-structure.md: 6411 bytes (~750 tokens)
- Agent가 전체 읽어야 함

**After (Index + Detail)**:
- code-structure.md: 4272 bytes (~500 tokens, -33%)
- architecture/*.md: 필요 시에만 읽음
- **평균 토큰 소비: 30% 절감**

---

**참조**: `.claude/CLAUDE.md` → Agent Discovery, Context Firewall
