from __future__ import annotations

import logging
import os
import time
from dataclasses import dataclass
from typing import Optional, Dict, Any

import anyio

from app.config import settings

# Optional dependencies (loaded lazily)
try:
    import cloudinary
    import cloudinary.uploader
    import cloudinary.utils
except Exception:  # pragma: no cover
    cloudinary = None  # type: ignore

try:
    import boto3
    from botocore.client import Config as BotoConfig
    from botocore.exceptions import BotoCoreError, ClientError
except Exception:  # pragma: no cover
    boto3 = None  # type: ignore

logger = logging.getLogger("app.services.media")


@dataclass
class UploadResult:
    url: str
    public_id: str
    size: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None
    duration: Optional[float] = None


class _BaseDriver:
    async def upload_image(
        self,
        data: bytes,
        filename: str,
        user_id: str,
        *,
        encrypted: bool = False,
        mime_type: Optional[str] = None,
        checksum: Optional[str] = None,
    ) -> Optional[UploadResult]:
        raise NotImplementedError

    async def upload_video(
        self,
        data: bytes,
        filename: str,
        user_id: str,
        *,
        encrypted: bool = False,
        mime_type: Optional[str] = None,
        checksum: Optional[str] = None,
    ) -> Optional[UploadResult]:
        raise NotImplementedError

    async def get_temporary_url(
        self,
        *,
        original_url: str,
        public_id: Optional[str],
        expires_in: int,
        encrypted: bool = False,
    ) -> Optional[str]:
        raise NotImplementedError

    async def delete_asset(self, *, public_id: str, resource_hint: Optional[str] = None) -> bool:
        raise NotImplementedError


class _CloudinaryDriver(_BaseDriver):
    def __init__(self) -> None:
        if not cloudinary:
            raise RuntimeError("cloudinary library not installed")
        # Configure Cloudinary once
        cloudinary.config(
            cloud_name=getattr(settings, "CLOUDINARY_CLOUD_NAME", None),
            api_key=getattr(settings, "CLOUDINARY_API_KEY", None),
            api_secret=getattr(settings, "CLOUDINARY_API_SECRET", None),
            secure=True,
        )

    async def upload_image(
        self,
        data: bytes,
        filename: str,
        user_id: str,
        *,
        encrypted: bool = False,
        mime_type: Optional[str] = None,
        checksum: Optional[str] = None,
    ) -> Optional[UploadResult]:
        folder = f"noctisapp/{user_id}/images"
        options: Dict[str, Any] = {
            "folder": folder,
            "public_id": filename,
            "resource_type": "image",
            "transformation": [
                {"width": 1920, "height": 1440, "crop": "limit"},
                {"quality": "85", "fetch_format": "auto"},
            ],
            # Attach lightweight metadata for audit
            "context": {
                "encrypted": str(encrypted).lower(),
                "checksum": checksum or "",
                "mime": mime_type or "",
                "app": "NoctisApp",
            },
        }

        def _upload():
            return cloudinary.uploader.upload(data, **options)  # type: ignore[attr-defined]

        try:
            result = await anyio.to_thread.run_sync(_upload)
            return UploadResult(
                url=result["secure_url"],
                public_id=result["public_id"],
                width=result.get("width"),
                height=result.get("height"),
                size=result.get("bytes"),
            )
        except Exception as e:
            logger.error("Cloudinary image upload failed: %s", e)
            return None

    async def upload_video(
        self,
        data: bytes,
        filename: str,
        user_id: str,
        *,
        encrypted: bool = False,
        mime_type: Optional[str] = None,
        checksum: Optional[str] = None,
    ) -> Optional[UploadResult]:
        folder = f"noctisapp/{user_id}/videos"
        options: Dict[str, Any] = {
            "folder": folder,
            "public_id": filename,
            "resource_type": "video",
            "transformation": [
                {"width": 1920, "height": 1080, "crop": "limit"},
                {"video_codec": "h264", "audio_codec": "aac"},
            ],
            "context": {
                "encrypted": str(encrypted).lower(),
                "checksum": checksum or "",
                "mime": mime_type or "",
                "app": "NoctisApp",
            },
        }

        def _upload():
            # For larger files, upload_large can be used; standard upload suffices for moderate sizes
            return cloudinary.uploader.upload(data, **options)  # type: ignore[attr-defined]

        try:
            result = await anyio.to_thread.run_sync(_upload)
            return UploadResult(
                url=result["secure_url"],
                public_id=result["public_id"],
                duration=result.get("duration"),
                size=result.get("bytes"),
            )
        except Exception as e:
            logger.error("Cloudinary video upload failed: %s", e)
            return None

    async def get_temporary_url(
        self,
        *,
        original_url: str,
        public_id: Optional[str],
        expires_in: int,
        encrypted: bool = False,
    ) -> Optional[str]:
        # If no public_id, best-effort return original URL (Cloudinary secure_url is cacheable, not expiring)
        if not public_id:
            return original_url

        # Decide resource_type by path hint
        resource_type = "image"
        if "/videos/" in public_id or public_id.startswith("noctisapp/") and "/videos/" in public_id:
            resource_type = "video"

        # Sign URL with expiration when possible
        try:
            expires_at = int(time.time()) + int(expires_in)
            url, options = cloudinary.utils.cloudinary_url(  # type: ignore[attr-defined]
                public_id,
                resource_type=resource_type,
                sign_url=True,
                expires_at=expires_at,
                secure=True,
            )
            return url
        except Exception as e:
            logger.debug("Cloudinary signed URL failed for %s: %s", public_id, e)
            # Fallback to original URL
            return original_url

    async def delete_asset(self, *, public_id: str, resource_hint: Optional[str] = None) -> bool:
        # Try hinted resource type first, then fallback attempts
        candidates = [resource_hint] if resource_hint else []
        # Infer from path
        if "/videos/" in public_id:
            candidates.append("video")
        candidates.extend(["image", "video"])

        for rt in candidates:
            if not rt:
                continue

            def _destroy():
                return cloudinary.uploader.destroy(public_id, resource_type=rt)  # type: ignore[attr-defined]

            try:
                result = await anyio.to_thread.run_sync(_destroy)
                if result and result.get("result") in ("ok", "not_found"):
                    return True
            except Exception as e:
                logger.debug("Cloudinary delete failed for %s (%s): %s", public_id, rt, e)
        return False


class _S3Driver(_BaseDriver):
    def __init__(self) -> None:
        if not boto3:
            raise RuntimeError("boto3 not installed")
        self.bucket = getattr(settings, "S3_BUCKET", None)
        if not self.bucket:
            raise RuntimeError("S3_BUCKET not configured")
        region = getattr(settings, "AWS_REGION", "us-east-1")
        self.client = boto3.client(
            "s3",
            region_name=region,
            aws_access_key_id=getattr(settings, "AWS_ACCESS_KEY_ID", None),
            aws_secret_access_key=getattr(settings, "AWS_SECRET_ACCESS_KEY", None),
            config=BotoConfig(s3={"addressing_style": "virtual"}),
        )

    def _key(self, user_id: str, kind: str, filename: str) -> str:
        prefix = f"noctisapp/{user_id}/{kind}s"
        return f"{prefix}/{filename}"

    async def upload_image(
        self,
        data: bytes,
        filename: str,
        user_id: str,
        *,
        encrypted: bool = False,
        mime_type: Optional[str] = None,
        checksum: Optional[str] = None,
    ) -> Optional[UploadResult]:
        key = self._key(user_id, "image", filename)

        def _put():
            extra = {"ContentType": mime_type or "application/octet-stream"}
            self.client.put_object(Bucket=self.bucket, Key=key, Body=data, **extra)

        try:
            await anyio.to_thread.run_sync(_put)
            url = f"https://{self.bucket}.s3.amazonaws.com/{key}"
            return UploadResult(url=url, public_id=key, size=len(data))
        except (BotoCoreError, ClientError) as e:
            logger.error("S3 image upload failed: %s", e)
            return None

    async def upload_video(
        self,
        data: bytes,
        filename: str,
        user_id: str,
        *,
        encrypted: bool = False,
        mime_type: Optional[str] = None,
        checksum: Optional[str] = None,
    ) -> Optional[UploadResult]:
        key = self._key(user_id, "video", filename)

        def _put():
            extra = {"ContentType": mime_type or "application/octet-stream"}
            self.client.put_object(Bucket=self.bucket, Key=key, Body=data, **extra)

        try:
            await anyio.to_thread.run_sync(_put)
            url = f"https://{self.bucket}.s3.amazonaws.com/{key}"
            return UploadResult(url=url, public_id=key, size=len(data))
        except (BotoCoreError, ClientError) as e:
            logger.error("S3 video upload failed: %s", e)
            return None

    async def get_temporary_url(
        self,
        *,
        original_url: str,
        public_id: Optional[str],
        expires_in: int,
        encrypted: bool = False,
    ) -> Optional[str]:
        if not public_id:
            return original_url
        try:
            params = {"Bucket": self.bucket, "Key": public_id}
            return self.client.generate_presigned_url("get_object", Params=params, ExpiresIn=int(expires_in))
        except (BotoCoreError, ClientError) as e:
            logger.error("S3 presigned URL failed: %s", e)
            return None

    async def delete_asset(self, *, public_id: str, resource_hint: Optional[str] = None) -> bool:
        try:
            def _delete():
                self.client.delete_object(Bucket=self.bucket, Key=public_id)
            await anyio.to_thread.run_sync(_delete)
            return True
        except (BotoCoreError, ClientError) as e:
            logger.error("S3 delete failed: %s", e)
            return False


class _NoopDriver(_BaseDriver):
    async def upload_image(self, *args, **kwargs) -> Optional[UploadResult]:
        logger.error("No media provider configured")
        return None

    async def upload_video(self, *args, **kwargs) -> Optional[UploadResult]:
        logger.error("No media provider configured")
        return None

    async def get_temporary_url(self, *args, **kwargs) -> Optional[str]:
        logger.error("No media provider configured")
        return None

    async def delete_asset(self, *args, **kwargs) -> bool:
        logger.error("No media provider configured")
        return False


def _select_driver() -> _BaseDriver:
    # Prefer Cloudinary when fully configured
    if (
        cloudinary
        and getattr(settings, "CLOUDINARY_CLOUD_NAME", None)
        and getattr(settings, "CLOUDINARY_API_KEY", None)
        and getattr(settings, "CLOUDINARY_API_SECRET", None)
    ):
        try:
            return _CloudinaryDriver()
        except Exception as e:
            logger.warning("Cloudinary driver init failed, falling back: %s", e)

    # Fallback to S3 when configured
    if boto3 and getattr(settings, "S3_BUCKET", None):
        try:
            return _S3Driver()
        except Exception as e:
            logger.warning("S3 driver init failed, falling back: %s", e)

    return _NoopDriver()


class MediaService:
    """
    Media service that abstracts provider differences (Cloudinary or S3).
    - Methods are async; blocking SDK calls run in worker threads.
    - Returns provider-agnostic structures used by routes and models.
    """

    def __init__(self) -> None:
        self.driver = _select_driver()

    async def upload_image(
        self,
        data: bytes,
        filename: str,
        user_id: str,
        *,
        encrypted: bool = False,
        mime_type: Optional[str] = None,
        checksum: Optional[str] = None,
    ) -> Optional[dict]:
        res = await self.driver.upload_image(
            data,
            filename,
            user_id,
            encrypted=encrypted,
            mime_type=mime_type,
            checksum=checksum,
        )
        if not res:
            return None
        return {
            "url": res.url,
            "public_id": res.public_id,
            "width": res.width,
            "height": res.height,
            "size": res.size,
        }

    async def upload_video(
        self,
        data: bytes,
        filename: str,
        user_id: str,
        *,
        encrypted: bool = False,
        mime_type: Optional[str] = None,
        checksum: Optional[str] = None,
    ) -> Optional[dict]:
        res = await self.driver.upload_video(
            data,
            filename,
            user_id,
            encrypted=encrypted,
            mime_type=mime_type,
            checksum=checksum,
        )
        if not res:
            return None
        return {
            "url": res.url,
            "public_id": res.public_id,
            "duration": res.duration,
            "size": res.size,
        }

    async def get_temporary_url(
        self,
        *,
        original_url: str,
        public_id: Optional[str],
        expires_in: int,
        encrypted: bool = False,
    ) -> Optional[str]:
        return await self.driver.get_temporary_url(
            original_url=original_url,
            public_id=public_id,
            expires_in=expires_in,
            encrypted=encrypted,
        )

    async def delete_asset(self, *, public_id: str, resource_hint: Optional[str] = None) -> bool:
        return await self.driver.delete_asset(public_id=public_id, resource_hint=resource_hint)

    # Backward compatibility alias (older code may call delete_media)
    async def delete_media(self, public_id: str, resource_type: str = "image") -> bool:
        return await self.delete_asset(public_id=public_id, resource_hint=resource_type)
