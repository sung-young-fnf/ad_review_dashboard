# FastAPI + CQRS Patterns

> Spark Note 프로젝트의 FastAPI 백엔드 CQRS 패턴

## When to Use This Skill

- 새로운 API 엔드포인트 생성 시
- Command/Query 핸들러 작성 시
- 서비스 레이어 구현 시
- 에러 핸들링 구현 시

## Core Concepts

### 디렉토리 구조
```
apps/backend/src/
├── auth/                    # 인증 모듈
│   ├── jwt_strategy.py
│   └── dependencies.py
├── [domain]/                # 도메인별 모듈
│   ├── router.py           # 라우터 (Controller)
│   ├── commands/           # 쓰기 작업
│   │   ├── create_xxx.py
│   │   └── update_xxx.py
│   ├── queries/            # 읽기 작업
│   │   ├── get_xxx.py
│   │   └── list_xxx.py
│   ├── schemas.py          # Pydantic DTO
│   └── service.py          # 비즈니스 로직
└── prisma/
    └── client.py           # Prisma 클라이언트
```

### CQRS Light 원칙

| 구분 | Command | Query |
|------|---------|-------|
| 목적 | 상태 변경 | 데이터 조회 |
| 메서드 | POST, PUT, PATCH, DELETE | GET |
| 반환 | 성공/실패 | 데이터 |
| 복잡도 | 높음 (검증, 트랜잭션) | 낮음 |

## Patterns

### Pattern 1: Router (Controller)

```python
# domains/campaigns/router.py
from fastapi import APIRouter, Depends, HTTPException
from .schemas import CampaignCreate, CampaignResponse
from .commands.create_campaign import CreateCampaignHandler
from .queries.get_campaign import GetCampaignHandler
from auth.dependencies import get_current_user

router = APIRouter(prefix="/campaigns", tags=["campaigns"])

@router.post("/", response_model=CampaignResponse)
async def create_campaign(
    data: CampaignCreate,
    current_user = Depends(get_current_user),
    handler: CreateCampaignHandler = Depends()
):
    return await handler.execute(data, current_user)

@router.get("/{campaign_id}", response_model=CampaignResponse)
async def get_campaign(
    campaign_id: str,
    current_user = Depends(get_current_user),
    handler: GetCampaignHandler = Depends()
):
    campaign = await handler.execute(campaign_id)
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    return campaign
```

### Pattern 2: Command Handler

```python
# domains/campaigns/commands/create_campaign.py
from prisma import Prisma
from ..schemas import CampaignCreate, CampaignResponse
from auth.schemas import CurrentUser

class CreateCampaignHandler:
    def __init__(self, prisma: Prisma = Depends(get_prisma)):
        self.prisma = prisma

    async def execute(
        self,
        data: CampaignCreate,
        current_user: CurrentUser
    ) -> CampaignResponse:
        # 1. 권한 검증
        if current_user.role not in ['admin', 'manager']:
            raise HTTPException(403, "권한이 없습니다")

        # 2. 비즈니스 로직
        campaign = await self.prisma.campaign.create(
            data={
                "title": data.title,
                "description": data.description,
                "teamId": current_user.team_id,
                "createdById": current_user.id,
                "startDate": data.start_date,
                "endDate": data.end_date,
            }
        )

        # 3. 응답 변환
        return CampaignResponse.from_orm(campaign)
```

### Pattern 3: Query Handler

```python
# domains/campaigns/queries/list_campaigns.py
from prisma import Prisma
from typing import List, Optional
from ..schemas import CampaignResponse, CampaignFilter

class ListCampaignsHandler:
    def __init__(self, prisma: Prisma = Depends(get_prisma)):
        self.prisma = prisma

    async def execute(
        self,
        team_id: str,
        filter: Optional[CampaignFilter] = None
    ) -> List[CampaignResponse]:
        where = {"teamId": team_id}

        if filter:
            if filter.status:
                where["status"] = filter.status
            if filter.is_active:
                where["endDate"] = {"gte": datetime.now()}

        campaigns = await self.prisma.campaign.findMany(
            where=where,
            orderBy={"createdAt": "desc"},
            include={"createdBy": True}
        )

        return [CampaignResponse.from_orm(c) for c in campaigns]
```

### Pattern 4: Pydantic Schemas

```python
# domains/campaigns/schemas.py
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class CampaignBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None

class CampaignCreate(CampaignBase):
    start_date: datetime
    end_date: datetime
    template_id: str

class CampaignUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None

class CampaignResponse(CampaignBase):
    id: str
    status: str
    team_id: str
    created_at: datetime
    created_by: Optional[dict] = None

    class Config:
        from_attributes = True  # Pydantic v2
```

### Pattern 5: 에러 핸들링

```python
# common/exceptions.py
from fastapi import HTTPException

class DomainException(HTTPException):
    def __init__(self, detail: str, status_code: int = 400):
        super().__init__(status_code=status_code, detail=detail)

class NotFoundError(DomainException):
    def __init__(self, resource: str, id: str):
        super().__init__(
            detail=f"{resource} not found: {id}",
            status_code=404
        )

class ForbiddenError(DomainException):
    def __init__(self, message: str = "권한이 없습니다"):
        super().__init__(detail=message, status_code=403)

# 사용
if not campaign:
    raise NotFoundError("Campaign", campaign_id)
```

## Common Pitfalls

### ❌ Router에 비즈니스 로직
```python
# ❌ Router가 비대해짐
@router.post("/")
async def create(data: CreateDTO):
    # 검증 로직
    # DB 접근
    # 알림 발송
    # 로깅
    return result

# ✅ Handler로 분리
@router.post("/")
async def create(data: CreateDTO, handler = Depends()):
    return await handler.execute(data)
```

### ❌ N+1 쿼리
```python
# ❌ 루프 내 쿼리
campaigns = await prisma.campaign.findMany()
for c in campaigns:
    c.members = await prisma.user.findMany(where={"campaignId": c.id})

# ✅ include로 한 번에
campaigns = await prisma.campaign.findMany(
    include={"members": True}
)
```

### ❌ 트랜잭션 누락
```python
# ❌ 중간에 실패하면 불일치
await prisma.campaign.create(...)
await prisma.campaignTarget.createMany(...)  # 여기서 실패하면?

# ✅ 트랜잭션으로 감싸기
async with prisma.tx() as tx:
    campaign = await tx.campaign.create(...)
    await tx.campaignTarget.createMany(...)
```

## Related Skills

- @.claude/skills/prisma-schema.md - DB 스키마 설계
- @.claude/skills/auth-patterns.md - 인증/인가
