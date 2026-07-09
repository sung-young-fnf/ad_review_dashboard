"""Upload router.

- POST /presign : 브라우저가 S3 에 직접 PUT 하도록 presigned URL 발급 (버킷 CORS 필요)
- POST ""       : 프록시 업로드 — 브라우저→백엔드→S3 (CORS 불필요, 기본 사용)
"""
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from advertisement.schemas.upload import PresignRequest, PresignResponse, UploadResult
from advertisement.security.auth import get_current_user
from advertisement.services.s3_service import S3Service

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.post("", response_model=UploadResult)
async def upload_object(purpose: str = Form(...), file: UploadFile = File(...)):
    """프록시 업로드 — 파일을 받아 S3 로 스트리밍 전송하고 key 를 반환."""
    if purpose not in ("original", "generated"):
        raise HTTPException(status_code=400, detail="purpose must be 'original' or 'generated'")
    key = await S3Service.upload_fileobj(
        file.file,
        purpose,
        file.filename or "upload",
        file.content_type or "application/octet-stream",
    )
    return UploadResult(
        key=key,
        file_name=file.filename,
        file_size=getattr(file, "size", None),
        content_type=file.content_type,
    )


@router.post("/presign", response_model=PresignResponse)
async def create_presigned_upload(req: PresignRequest):
    """(대안) 브라우저 직접 PUT용 presigned URL — 버킷 CORS 허용 시 사용."""
    upload_url, key = S3Service.presign_put(req.purpose, req.filename, req.content_type)
    return PresignResponse(upload_url=upload_url, key=key)
