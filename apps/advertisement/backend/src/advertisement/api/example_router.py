"""Example router — 개발 패턴 레퍼런스

패턴:
- APIRouter로 도메인별 라우트 분리
- Depends(get_db)로 DB 세션 주입 (DI)
- Router는 HTTP 요청/응답만, 비즈니스 로직은 Service에 위임
- HTTPException으로 에러 응답
"""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from advertisement.database import get_db
from advertisement.schemas.example import ExampleCreate, ExampleUpdate, ExampleResponse
from advertisement.services.example_service import ExampleService

router = APIRouter()


@router.get("", response_model=list[ExampleResponse])
async def list_examples(skip: int = 0, limit: int = 20, db: AsyncSession = Depends(get_db)):
    return await ExampleService.find_all(db, skip=skip, limit=limit)


@router.get("/{example_id}", response_model=ExampleResponse)
async def get_example(example_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await ExampleService.find_by_id(db, example_id)
    if not result:
        raise HTTPException(status_code=404, detail="Example not found")
    return result


@router.post("", response_model=ExampleResponse, status_code=201)
async def create_example(dto: ExampleCreate, db: AsyncSession = Depends(get_db)):
    return await ExampleService.create(db, dto)


@router.put("/{example_id}", response_model=ExampleResponse)
async def update_example(example_id: UUID, dto: ExampleUpdate, db: AsyncSession = Depends(get_db)):
    result = await ExampleService.update(db, example_id, dto)
    if not result:
        raise HTTPException(status_code=404, detail="Example not found")
    return result


@router.delete("/{example_id}", status_code=204)
async def delete_example(example_id: UUID, db: AsyncSession = Depends(get_db)):
    deleted = await ExampleService.delete(db, example_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Example not found")
