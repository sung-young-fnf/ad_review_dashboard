"""S3 service — cloudy 'advertisement' 프로젝트 전용

규칙(apps/advertisement/CLAUDE.md):
- 버킷 dt-ane2-s3-dev-dcs-cloudy 의 advertisement/ prefix 아래만 read/write
- AWS SDK 는 프로필 cloudy-advertisement 사용 (영구키 — credential_process 자동 갱신)
- boto3 직접 사용 (presigned URL 발급). 브라우저는 presigned URL 로 S3 에 직접 PUT/GET.

presigned URL 생성은 로컬 서명 연산이라 논블로킹. delete 는 네트워크 호출이므로 threadpool 로 처리.
"""
import logging
import os
import re
import uuid

import boto3
from fastapi.concurrency import run_in_threadpool

from advertisement.config import settings

logger = logging.getLogger(__name__)

_ALLOWED_PURPOSES = {"original", "generated"}
_EXT_RE = re.compile(r"[^a-z0-9.]")

_session: boto3.Session | None = None


def _client():
    """프로필 기반 S3 클라이언트(세션 캐시)."""
    global _session
    if _session is None:
        if settings.aws_profile:
            _session = boto3.Session(profile_name=settings.aws_profile, region_name=settings.aws_region)
        else:  # 프로필 미지정 시 환경 자격증명 사용(CI 등)
            _session = boto3.Session(region_name=settings.aws_region)
    return _session.client("s3")


def _build_key(purpose: str, filename: str) -> str:
    """advertisement/uploads/{purpose}/{uuid}{ext} — 소문자/숫자/하이픈만."""
    if purpose not in _ALLOWED_PURPOSES:
        raise ValueError(f"purpose must be one of {_ALLOWED_PURPOSES}")
    ext = os.path.splitext(filename or "")[1].lower()
    ext = _EXT_RE.sub("", ext)  # 확장자에서 안전 문자만
    return f"{settings.s3_prefix}uploads/{purpose}/{uuid.uuid4().hex}{ext}"


def _assert_owned(key: str) -> None:
    """prefix 밖 키 접근 차단 (권한 밖 경로 보호)."""
    if not key.startswith(settings.s3_prefix):
        raise ValueError(f"key must start with '{settings.s3_prefix}'")


class S3Service:

    @staticmethod
    def presign_put(purpose: str, filename: str, content_type: str) -> tuple[str, str]:
        """업로드용 presigned PUT URL 발급. returns (upload_url, key)."""
        key = _build_key(purpose, filename)
        url = _client().generate_presigned_url(
            "put_object",
            Params={"Bucket": settings.s3_bucket, "Key": key, "ContentType": content_type},
            ExpiresIn=settings.s3_presign_expiry,
        )
        return url, key

    @staticmethod
    async def upload_fileobj(fileobj, purpose: str, filename: str, content_type: str) -> str:
        """프록시 업로드 — 파일 스트림을 S3 로 직접 전송(멀티파트). 브라우저 CORS 불필요.

        boto3 upload_fileobj 는 블로킹이라 threadpool 에서 실행.
        """
        key = _build_key(purpose, filename)
        ct = content_type or "application/octet-stream"
        await run_in_threadpool(
            lambda: _client().upload_fileobj(fileobj, settings.s3_bucket, key, ExtraArgs={"ContentType": ct})
        )
        logger.info(f"Uploaded to S3 (proxy): {key}")
        return key

    @staticmethod
    def presign_get(key: str) -> str:
        """재생/다운로드용 presigned GET URL 발급."""
        _assert_owned(key)
        return _client().generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.s3_bucket, "Key": key},
            ExpiresIn=settings.s3_presign_expiry,
        )

    @staticmethod
    async def delete(key: str) -> None:
        """S3 객체 삭제(존재하지 않아도 조용히 통과)."""
        _assert_owned(key)
        await run_in_threadpool(
            lambda: _client().delete_object(Bucket=settings.s3_bucket, Key=key)
        )
        logger.info(f"Deleted S3 object: {key}")
