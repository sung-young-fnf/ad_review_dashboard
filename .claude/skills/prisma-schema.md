# Prisma Schema Patterns

> Spark Note 프로젝트의 Prisma ORM 스키마 설계 패턴

## When to Use This Skill

- 새로운 DB 모델 생성 시
- 테이블 관계 설계 시
- 마이그레이션 작성 시
- 쿼리 최적화 시

## Core Concepts

### 스키마 위치
```
packages/prisma/
├── schema.prisma      # 메인 스키마
├── migrations/        # 마이그레이션 히스토리
└── seed.ts           # 시드 데이터
```

### 필수 규칙

| 규칙 | 설명 |
|------|------|
| `@@schema("sparknote")` | 모든 모델에 스키마 prefix 필수 |
| `@@map("snake_case")` | 테이블명은 snake_case |
| `@map("snake_case")` | 컬럼명은 snake_case |
| UUID | 모든 ID는 UUID 사용 |

## Patterns

### Pattern 1: 기본 모델 구조

```prisma
model User {
  id          String   @id @default(uuid()) @map("id")
  email       String   @unique @map("email")
  displayName String   @map("display_name")
  avatarUrl   String?  @map("avatar_url")
  role        String   @default("member") @map("role")
  teamId      String?  @map("team_id")
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  // Relations
  team        Team?    @relation(fields: [teamId], references: [id])
  sparkNotes  SparkNote[]

  @@map("users")
  @@schema("sparknote")
}
```

### Pattern 2: 1:N 관계

```prisma
model Team {
  id        String   @id @default(uuid())
  name      String
  createdAt DateTime @default(now()) @map("created_at")

  // 1:N - 팀에 여러 멤버
  members   User[]
  campaigns Campaign[]

  @@map("teams")
  @@schema("sparknote")
}

model User {
  id     String  @id @default(uuid())
  teamId String? @map("team_id")

  // N:1 - 멤버는 하나의 팀
  team   Team?   @relation(fields: [teamId], references: [id])

  @@map("users")
  @@schema("sparknote")
}
```

### Pattern 3: M:N 관계 (명시적 조인 테이블)

```prisma
model Campaign {
  id          String   @id @default(uuid())
  title       String

  // M:N - 캠페인에 여러 대상자
  targets     CampaignTarget[]

  @@map("campaigns")
  @@schema("sparknote")
}

model CampaignTarget {
  id         String   @id @default(uuid())
  campaignId String   @map("campaign_id")
  userId     String   @map("user_id")
  status     String   @default("pending")

  campaign   Campaign @relation(fields: [campaignId], references: [id])
  user       User     @relation(fields: [userId], references: [id])

  @@unique([campaignId, userId])
  @@map("campaign_targets")
  @@schema("sparknote")
}
```

### Pattern 4: Enum 대신 String + 상수

```typescript
// ❌ Prisma Enum 사용 금지 (마이그레이션 복잡)
enum Role {
  ADMIN
  MANAGER
  MEMBER
}

// ✅ String + TypeScript 상수
// schema.prisma
model User {
  role String @default("member") @map("role")
}

// constants/roles.ts
export const ROLES = {
  ADMIN: 'admin',
  MANAGER: 'manager',
  MEMBER: 'member',
} as const;

export type Role = typeof ROLES[keyof typeof ROLES];
```

### Pattern 5: 소프트 삭제

```prisma
model SparkNote {
  id        String    @id @default(uuid())
  content   String
  deletedAt DateTime? @map("deleted_at") // null이면 활성

  @@map("spark_notes")
  @@schema("sparknote")
}

// 쿼리 시
const activeNotes = await prisma.sparkNote.findMany({
  where: { deletedAt: null }
});
```

## Common Pitfalls

### ❌ public 스키마 사용
```prisma
// ❌ 스키마 누락 → public 스키마에 생성됨
model User {
  id String @id
  @@map("users")
  // @@schema("sparknote") 누락!
}
```

### ❌ Enum 타입 사용
```prisma
// ❌ PostgreSQL ENUM은 마이그레이션 복잡
enum Status {
  DRAFT
  SUBMITTED
}

// ✅ String으로 대체
model Submission {
  status String @default("draft")
}
```

### ❌ camelCase 테이블/컬럼명
```prisma
// ❌ DB 규칙 위반
model UserProfile {
  userId String
}

// ✅ snake_case 매핑
model UserProfile {
  userId String @map("user_id")
  @@map("user_profiles")
}
```

### ❌ 관계 필드 인덱스 누락
```prisma
// ❌ 외래키에 인덱스 없음 → 조인 느림
model SparkNote {
  authorId String @map("author_id")
}

// ✅ 외래키에 인덱스 추가
model SparkNote {
  authorId String @map("author_id")
  @@index([authorId])
}
```

## Related Skills

- @.claude/skills/fastapi-cqrs.md - Backend에서 Prisma 사용
- @.claude/guides/DATABASE_SCHEMA_RULES.md - 상세 DB 규칙
