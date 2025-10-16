from __future__ import annotations

import hashlib
import logging
import uuid
from datetime import datetime, timezone
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query
from pydantic import BaseModel, Field
from redis.asyncio import Redis
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.user import User
from app.models.media import Media
from app.routes.auth import get_current_user
from app.services.media import MediaService
from app.services.encryption import EncryptionService

logger = logging.getLogger("app.routes.media")

router = APIRouter(prefix="/api/v1/media", tags=["Media"])

# Services (MediaService should internally choose Cloudinary/S3 based on settings)
media_service = MediaService()
encryption_service = EncryptionService(settings.ENCRYPTION_KEY)

# Redis singleton for rate-limit and ephemeral indices
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


async def rate_limit(
    redis: Redis,
    user_id: str,
    action_key: str,
    limit: int = 20,
    window_seconds: int = 60,
) -> None:
    key = f"rl:{user_id}:{action_key}"
    try:
        current = await redis.incr(key)
        if current == 1:
            await redis.expire(key, window_seconds)
        if current > limit:
            ttl = await redis.ttl(key)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Try again in {ttl if ttl > 0 else window_seconds} seconds.",
            )
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("Rate limiter error for %s: %s", key, exc)


# Validation helpers and defaults
ALLOWED_IMAGE_MIME_TYPES = set(
    getattr(settings, "ALLOWED_IMAGE_MIME_TYPES", ["image/jpeg", "image/png", "image/webp", "image/gif"])
)
ALLOWED_VIDEO_MIME_TYPES = set(
    getattr(settings, "ALLOWED_VIDEO_MIME_TYPES", ["video/mp4", "video/webm", "video/quicktime"])
)
MAX_IMAGE_SIZE_BYTES: int = int(getattr(settings, "MAX_IMAGE_SIZE_BYTES", 10_000_000))  # 10 MB
MAX_VIDEO_SIZE_BYTES: int = int(getattr(settings, "MAX_VIDEO_SIZE_BYTES", 150_000_000))  # 150 MB


def _validate_mime(kind: str, content_type: str) -> None:
    if kind == "image":
        if content_type not in ALLOWED_IMAGE_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported image type: {content_type}",
            )
    elif kind == "video":
        if content_type not in ALLOWED_VIDEO_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported video type: {content_type}",
            )


def _validate_size(kind: str, size: int) -> None:
    if kind == "image" and size > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image exceeds limit of {MAX_IMAGE_SIZE_BYTES} bytes",
        )
    if kind == "video" and size > MAX_VIDEO_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Video exceeds limit of {MAX_VIDEO_SIZE_BYTES} bytes",
        )


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# Pydantic responses
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
    url: Optional[str] = None  # optional signed URL preview


@router.post("/upload/image", response_model=ImageUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile = File(...),
    encrypted: bool = Query(False, description="Indicates the file bytes are already end-to-end encrypted"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """
    Upload an image with server-side validation and provider upload.
    If encrypted=True, bytes are treated as ciphertext; store as-is and never transform.
    """
    await rate_limit(redis, str(current_user.id), "media:upload_image", limit=15, window_seconds=60)

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File must be an image")

    _validate_mime("image", file.content_type)

    # Read bytes (note: for very large files, prefer streaming to temp file; current limit keeps it safe)
    data = await file.read()
    _validate_size("image", len(data))

    # If not encrypted and policy enforces encryption, reject
    if getattr(settings, "ENFORCE_MEDIA_ENCRYPTION", False) and not encrypted:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Media must be end-to-end encrypted")

    checksum = _sha256(data)

    # Provider upload
    unique_name = f"{uuid.uuid4()}_{file.filename or 'image'}"
    result = await media_service.upload_image(
        data,
        unique_name,
        str(current_user.id),
        encrypted=encrypted,
        mime_type=file.content_type,
        checksum=checksum,
    )

    if not result or "url" not in result:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to upload image")

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

    return ImageUploadResponse(
        id=str(media.id),
        url=result["url"],
        width=result.get("width"),
        height=result.get("height"),
    )


@router.post("/upload/video", response_model=VideoUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_video(
    file: UploadFile = File(...),
    encrypted: bool = Query(False, description="Indicates the file bytes are already end-to-end encrypted"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """
    Upload a video with server-side validation and provider upload.
    If encrypted=True, bytes are treated as ciphertext; store as-is and never transform.
    """
    await rate_limit(redis, str(current_user.id), "media:upload_video", limit=8, window_seconds=60)

    if not file.content_type or not file.content_type.startswith("video/"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File must be a video")

    _validate_mime("video", file.content_type)

    data = await file.read()
    _validate_size("video", len(data))

    if getattr(settings, "ENFORCE_MEDIA_ENCRYPTION", False) and not encrypted:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Media must be end-to-end encrypted")

    checksum = _sha256(data)

    unique_name = f"{uuid.uuid4()}_{file.filename or 'video'}"
    result = await media_service.upload_video(
        data,
        unique_name,
        str(current_user.id),
        encrypted=encrypted,
        mime_type=file.content_type,
        checksum=checksum,
    )

    if not result or "url" not in result:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to upload video")

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

    return VideoUploadResponse(
        id=str(media.id),
        url=result["url"],
        duration=result.get("duration"),
    )


@router.get("/{media_id}/url", response_model=TemporaryUrlResponse, status_code=status.HTTP_200_OK)
async def get_temporary_media_url(
    media_id: str,
    expires_in: int = Query(600, ge=60, le=3600),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns a provider-signed, temporary URL for the given media if owned by the current user.
    """
    try:
        mid = uuid.UUID(media_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid media_id")

    result = await db.execute(select(Media).where(Media.id == mid))
    media: Optional[Media] = result.scalar_one_or_none()

    if not media:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media not found")

    if media.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to access this media")

    signed_url = await media_service.get_temporary_url(
        original_url=media.original_url,
        public_id=getattr(media, "provider_public_id", None),
        expires_in=expires_in,
        encrypted=getattr(media, "encrypted", False),
    )

    if not signed_url:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to generate URL")

    return TemporaryUrlResponse(id=str(media.id), url=signed_url, expires_in=expires_in)


@router.get("/me", response_model=List[MediaListItem], status_code=status.HTTP_200_OK)
async def list_my_media(
    include_urls: bool = Query(False, description="If true, returns temporary URLs for each item"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Lists recent media for the authenticated user.
    """
    result = await db.execute(
        select(Media)
        .where(Media.user_id == current_user.id)
        .order_by(Media.created_at.desc())
        .limit(50)
    )
    items: List[Media] = result.scalars().all()

    out: List[MediaListItem] = []
    if include_urls:
        # Generate signed URL per item with a short default expiry
        for m in items:
            url = await media_service.get_temporary_url(
                original_url=m.original_url,
                public_id=getattr(m, "provider_public_id", None),
                expires_in=600,
                encrypted=getattr(m, "encrypted", False),
            )
            out.append(
                MediaListItem(
                    id=str(m.id),
                    media_type=m.media_type,
                    mime_type=m.mime_type,
                    file_name=m.file_name,
                    file_size=m.file_size,
                    created_at=(m.created_at or datetime.now(timezone.utc)).isoformat(),
                    url=url,
                )
            )
    else:
        for m in items:
            out.append(
                MediaListItem(
                    id=str(m.id),
                    media_type=m.media_type,
                    mime_type=m.mime_type,
                    file_name=m.file_name,
                    file_size=m.file_size,
                    created_at=(m.created_at or datetime.now(timezone.utc)).isoformat(),
                    url=None,
                )
            )

    return out


@router.delete("/{media_id}", status_code=status.HTTP_200_OK)
async def delete_media(
    media_id: str,
    hard: bool = Query(False, description="If true, attempts provider delete and permanent DB removal"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Deletes media owned by the current user.
    - soft delete: keeps DB row (optionally add a `deleted_at` column in the model)
    - hard delete: removes from provider (Cloudinary/S3) and DB
    """
    try:
        mid = uuid.UUID(media_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid media_id")

    result = await db.execute(select(Media).where(Media.id == mid))
    media: Optional[Media] = result.scalar_one_or_none()

    if not media:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media not found")

    if media.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this media")

    if hard:
        # Provider delete
        if getattr(media, "provider_public_id", None):
            await media_service.delete_asset(public_id=media.provider_public_id)
        # Hard delete DB row
        await db.delete(media)
        await db.commit()
        return {"ok": True, "hard_deleted": True}

    # Soft delete path (add a deleted_at field in Media model for full support)
    if hasattr(Media, "deleted_at"):
        media.deleted_at = datetime.now(timezone.utc)  # type: ignore[attr-defined]
        await db.commit()
        return {"ok": True, "hard_deleted": False}

    # If no soft-delete column, emulate by clearing URL (revokes access) but keep record
    media.original_url = ""
    await db.commit()
    return {"ok": True, "hard_deleted": False}
