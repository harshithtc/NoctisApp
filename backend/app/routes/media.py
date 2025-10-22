from __future__ import annotations

import hashlib
import logging
import uuid
from datetime import datetime, timezone
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query
from pydantic import BaseModel, Field
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.user import User
from app.models.media import Media
from app.routes.auth import get_current_user
from app.services.media import MediaService
from app.services.encryption import EncryptionService

logger = logging.getLogger("app.routes.media")
router = APIRouter(tags=["Media"])  # No prefix; inherited from group in __init__.py

# Services
media_service = MediaService()
encryption_service = EncryptionService(settings.ENCRYPTION_KEY)

# Redis singleton for rate limit and ephemeral indices
_redis_client: Optional[Redis] = None

async def get_redis() -> Redis:
    global _redis_client
    if _redis_client is None:
        if not getattr(settings, "REDIS_URL", None):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Redis not configured",
            )
        _redis_client = Redis.from_url(settings.REDIS_URL, encoding="utf-8", decode_responses=True)
        try:
            await _redis_client.ping()
        except Exception as exc:
            logger.exception("Redis ping failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Redis not available",
            )
    return _redis_client

# Utility functions for rate limiting and validation
ALLOWED_IMAGE_MIME_TYPES = set(
    getattr(settings, "ALLOWED_IMAGE_MIME_TYPES", ["image/jpeg", "image/png", "image/webp", "image/gif"])
)
ALLOWED_VIDEO_MIME_TYPES = set(
    getattr(settings, "ALLOWED_VIDEO_MIME_TYPES", ["video/mp4", "video/webm", "video/quicktime"])
)
MAX_IMAGE_SIZE_BYTES: int = int(getattr(settings, "MAX_IMAGE_SIZE_BYTES", 10_000_000))
MAX_VIDEO_SIZE_BYTES: int = int(getattr(settings, "MAX_VIDEO_SIZE_BYTES", 150_000_000))

def _validate_mime(kind: str, content_type: str) -> None:
    if kind == "image" and content_type not in ALLOWED_IMAGE_MIME_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported image type: {content_type}")
    elif kind == "video" and content_type not in ALLOWED_VIDEO_MIME_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported video type: {content_type}")

def _validate_size(kind: str, size: int) -> None:
    if kind == "image" and size > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail=f"Image exceeds {MAX_IMAGE_SIZE_BYTES} bytes")
    elif kind == "video" and size > MAX_VIDEO_SIZE_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail=f"Video exceeds {MAX_VIDEO_SIZE_BYTES} bytes")

def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

# Response Models
class ImageUploadResponse(BaseModel):
    id: str
    url: str
    width: Optional[int] = None
    height: Optional[int] = None

class VideoUploadResponse(BaseModel):
    id: str
    url: str
    duration: Optional[float] = None

class TemporaryUrlResponse(BaseModel):
    id: str
    url: str
    expires_in: int = Field(600, description="Seconds until URL expiry")

class MediaListItem(BaseModel):
    id: str
    media_type: str
    mime_type: str
    file_name: str
    file_size: int
    created_at: str
    url: Optional[str] = None

# Upload Image
@router.post("/upload/image", response_model=ImageUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile = File(...),
    encrypted: bool = Query(False, description="Indicates encryption"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    await rate_limit(redis, str(current_user.id), "media:upload_image", limit=15, window_seconds=60)
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File must be an image")
    _validate_mime("image", file.content_type)
    data = await file.read()
    _validate_size("image", len(data))
    if getattr(settings, "ENFORCE_MEDIA_ENCRYPTION", False) and not encrypted:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Media must be encrypted")
    checksum = _sha256(data)
    unique_name = f"{uuid.uuid4()}_{file.filename or 'image'}"
    result = await media_service.upload_image(data, unique_name, str(current_user.id), encrypted=encrypted, mime_type=file.content_type, checksum=checksum)
    if not result or "url" not in result:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Upload failed")
    media = Media(
        user_id=current_user.id,
        media_type="image",
        file_name=file.filename or unique_name,
        file_size=result.get("size", len(data)),
        original_url=result["url"],
        width=result.get("width"),
        height=result.get("height"),
        mime_type=file.content_type,
        checksum=checksum,
        provider_public_id=result.get("public_id"),
        encrypted=encrypted,
    )
    db.add(media)
    await db.commit()
    await db.refresh(media)
    return ImageUploadResponse(id=str(media.id), url=result["url"], width=result.get("width"), height=result.get("height"))

# Upload Video
@router.post("/upload/video", response_model=VideoUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_video(
    file: UploadFile = File(...),
    encrypted: bool = Query(False, description="Indicates encryption"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    await rate_limit(redis, str(current_user.id), "media:upload_video", limit=8, window_seconds=60)
    if not file.content_type or not file.content_type.startswith("video/"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File must be a video")
    _validate_mime("video", file.content_type)
    data = await file.read()
    _validate_size("video", len(data))
    if getattr(settings, "ENFORCE_MEDIA_ENCRYPTION", False) and not encrypted:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Media must be encrypted")
    checksum = _sha256(data)
    unique_name = f"{uuid.uuid4()}_{file.filename or 'video'}"
    result = await media_service.upload_video(data, unique_name, str(current_user.id), encrypted=encrypted, mime_type=file.content_type, checksum=checksum)
    if not result or "url" not in result:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Upload failed")
    media = Media(
        user_id=current_user.id,
        media_type="video",
        file_name=file.filename or unique_name,
        file_size=result.get("size", len(data)),
        original_url=result["url"],
        duration=result.get("duration"),
        mime_type=file.content_type,
        checksum=checksum,
        provider_public_id=result.get("public_id"),
        encrypted=encrypted,
    )
    db.add(media)
    await db.commit()
    await db.refresh(media)
    return VideoUploadResponse(id=str(media.id), url=result["url"], duration=result.get("duration"))

# Get Temporary Media URL
@router.get("/{media_id}/url", response_model=TemporaryUrlResponse)
async def get_temporary_media_url(
    media_id: str,
    expires_in: int = Query(600, ge=60, le=3600),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        mid = uuid.UUID(media_id)
    except:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid media_id")
    result = await db.execute(select(Media).where(Media.id == mid))
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media not found")
    if media.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    signed_url = await media_service.get_temporary_url(
        original_url=media.original_url,
        public_id=getattr(media, "provider_public_id", None),
        expires_in=expires_in,
        encrypted=getattr(media, "encrypted", False),
    )
    if not signed_url:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to generate URL")
    return TemporaryUrlResponse(id=str(media.id), url=signed_url, expires_in=expires_in)

# List My Media
@router.get("/me", response_model=List[MediaListItem])
async def list_my_media(
    include_urls: bool = Query(False, description="If true, returns temporary URLs for each item"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Media)
        .where(Media.user_id == current_user.id)
        .order_by(Media.created_at.desc())
        .limit(50)
    )
    items = result.scalars().all()
    out: List[MediaListItem] = []

    for m in items:
        url = None
        if include_urls:
            url = await media_service.get_temporary_url(
                original_url=m.original_url,
                public_id=getattr(m, "provider_public_id", None),
                expires_in=600,
                encrypted=getattr(m, "encrypted", False),
            )
        out.append(MediaListItem(
            id=str(m.id),
            media_type=m.media_type,
            mime_type=m.mime_type,
            file_name=m.file_name,
            file_size=m.file_size,
            created_at=(m.created_at or datetime.now(timezone.utc)).isoformat(),
            url=url,
        ))
    return out

# Delete Media
@router.delete("/{media_id}")
async def delete_media(
    media_id: str,
    hard: bool = Query(False, description="If true, delete from provider and DB"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        mid = uuid.UUID(media_id)
    except:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid media_id")
    result = await db.execute(select(Media).where(Media.id == mid))
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media not found")
    if media.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    if hard:
        if getattr(media, "provider_public_id", None):
            await media_service.delete_asset(public_id=media.provider_public_id)
        await db.delete(media)
        await db.commit()
        return {"ok": True, "hard_deleted": True}
    if hasattr(Media, "deleted_at"):
        media.deleted_at = datetime.now(timezone.utc)
        await db.commit()
        return {"ok": True, "hard_deleted": False}
    media.original_url = ""
    await db.commit()
    return {"ok": True, "hard_deleted": False}
