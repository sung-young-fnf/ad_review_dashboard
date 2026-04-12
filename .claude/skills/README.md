# Skills 폴더

> **Progressive Disclosure Architecture** - 필요할 때만 로드되는 재사용 가능한 지식 모듈

## 📋 Skills vs Guides 차이

| 구분 | Skills | Guides |
|------|--------|--------|
| **로딩** | 필요할 때만 | 항상 참조 가능 |
| **목적** | 특정 작업 수행용 지식 | 일반 참고 문서 |
| **구조** | When to Use + Core Concepts + Patterns | 자유 형식 |
| **토큰** | 최적화됨 (Progressive) | 전체 로드 |

## 📁 Skill 파일 구조

```markdown
# [Skill Name]

## When to Use This Skill
[이 스킬이 활성화되어야 하는 조건]

## Core Concepts
[핵심 개념 요약]

## Patterns
### Pattern 1: [이름]
[코드 예시 + 설명]

### Pattern 2: [이름]
[코드 예시 + 설명]

## Common Pitfalls
[자주 하는 실수]

## Related Skills
[관련 스킬 참조]
```

## 🗂️ 현재 Skills 목록

### Frontend
- `nextjs-app-router.md` - Next.js 15 App Router 패턴
- `tanstack-query.md` - TanStack Query 데이터 페칭
- `shadcn-ui.md` - shadcn/ui 컴포넌트 패턴

### Backend
- `fastapi-cqrs.md` - FastAPI + CQRS 패턴
- `prisma-schema.md` - Prisma 스키마 설계

### Fullstack
- `api-route-proxy.md` - Next.js API Route → Backend 프록시
- `auth-patterns.md` - NextAuth + MS Entra ID 인증

## 🔗 Agent에서 참조하는 방법

```markdown
## Related Skills
- @.claude/skills/nextjs-app-router.md
- @.claude/skills/prisma-schema.md
```

## 📝 새 Skill 추가 가이드

1. 위 템플릿 구조를 따라 `.md` 파일 생성
2. `When to Use` 섹션에 활성화 조건 명시
3. 실제 코드 예시를 `Patterns` 섹션에 포함
4. 이 README에 목록 추가
