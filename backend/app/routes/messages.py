from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query
from redis.asyncio import Redis
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.message import Message, MessageStatus
from app.models.user import User
from app.routes.auth import get_current_user
from app.schemas.message import MessageCreate, MessageResponse, MessageReaction

logger = logging.getLogger("app.routes.messages")

router = APIRouter(tags=["Messages"])  # Prefix handled by grouped router

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
    limit: int = 60,
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

@router.post("/", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def send_message(
    body: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """Send a client-encrypted message (idempotent via client_id)."""
    await rate_limit(redis, str(current_user.id), "messages:send", limit=60, window_seconds=60)
    if body.client_id:
        existing = (await db.execute(select(Message).where(Message.client_id == body.client_id))).scalar_one_or_none()
        if existing:
            return MessageResponse.from_orm(existing)
    try:
        receiver_uuid = uuid.UUID(body.receiver_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid receiver_id")
    if not body.encrypted_content or not body.encryption_iv:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing encrypted content or IV")
    message = Message(
        client_id=body.client_id,
        sender_id=current_user.id,
        receiver_id=receiver_uuid,
        message_type=body.message_type,
        encrypted_content=body.encrypted_content,
        encryption_iv=body.encryption_iv,
        media_url=body.media_url,
        media_thumbnail_url=body.media_thumbnail_url,
        media_metadata=body.media_metadata,
        reply_to_id=uuid.UUID(body.reply_to_id) if body.reply_to_id else None,
        is_view_once=body.is_view_once,
        self_destruct_timer=body.self_destruct_timer,
        status=MessageStatus.SENT,
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    try:
        await redis.incr(f"unread:{str(message.receiver_id)}:{str(message.sender_id)}")
        await redis.expire(f"unread:{str(message.receiver_id)}:{str(message.sender_id)}", 86400)
    except Exception as exc:
        logger.debug("Unread counter update failed: %s", exc)
    try:
        await redis.publish(f"ws:messages:{str(message.receiver_id)}", str(message.id))
    except Exception as exc:
        logger.debug("WS publish failed: %s", exc)
    return MessageResponse.from_orm(message)

@router.get("/", response_model=List[MessageResponse], status_code=status.HTTP_200_OK)
async def get_messages(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    last_sync: Optional[datetime] = Query(None, description="Return items updated after"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """Retrieve paginated messages with incremental sync and deletion filters."""
    await rate_limit(redis, str(current_user.id), "messages:list", limit=120, window_seconds=60)
    query = select(Message).where(
        or_(Message.sender_id == current_user.id, Message.receiver_id == current_user.id),
        Message.deleted_for_everyone.is_(False),
    )
    if last_sync:
        query = query.where(Message.updated_at > last_sync)
    query = query.order_by(Message.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(query)
    messages = result.scalars().all()
    filtered: List[Message] = []
    for msg in messages:
        if msg.sender_id == current_user.id and not msg.deleted_by_sender:
            filtered.append(msg)
        elif msg.receiver_id == current_user.id and not msg.deleted_by_receiver:
            filtered.append(msg)
    return [MessageResponse.from_orm(m) for m in filtered]

@router.delete("/{message_id}", status_code=status.HTTP_200_OK)
async def delete_message(
    message_id: str,
    delete_for_everyone: bool = Query(False),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """Delete messages with optional delete-for-everyone within 24 hours."""
    await rate_limit(redis, str(current_user.id), "messages:delete", limit=60, window_seconds=60)
    try:
        msg_uuid = uuid.UUID(message_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid message_id")
    result = await db.execute(select(Message).where(Message.id == msg_uuid))
    message = result.scalar_one_or_none()
    if not message:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    if delete_for_everyone:
        if message.sender_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Can only delete own messages for everyone")
        time_diff = (datetime.now(timezone.utc) - (message.created_at or datetime.now(timezone.utc))).total_seconds()
        if time_diff > 86400:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Delete window expired")
        message.deleted_for_everyone = True
        message.deleted_for_everyone_at = datetime.now(timezone.utc)
    else:
        if message.sender_id == current_user.id:
            message.deleted_by_sender = True
        elif message.receiver_id == current_user.id:
            message.deleted_by_receiver = True
        else:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete")
    await db.commit()
    return {"message": "Message deleted successfully"}

@router.post("/{message_id}/react", status_code=status.HTTP_200_OK)
async def react_to_message(
    message_id: str,
    body: MessageReaction,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """Toggle reaction emoji on message by current user."""
    await rate_limit(redis, str(current_user.id), "messages:react", limit=120, window_seconds=60)
    try:
        msg_uuid = uuid.UUID(message_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid message_id")
    result = await db.execute(select(Message).where(Message.id == msg_uuid))
    message = result.scalar_one_or_none()
    if not message:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    if current_user.id not in (message.sender_id, message.receiver_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to react")
    reactions = message.reactions or {}
    emoji = body.emoji
    users = set(reactions.get(emoji, []))
    uid = str(current_user.id)
    if uid in users:
        users.remove(uid)
    else:
        users.add(uid)
    if users:
        reactions[emoji] = list(users)
    else:
        reactions.pop(emoji, None)
    message.reactions = reactions
    await db.commit()
    try:
        await redis.publish(f"ws:messages:react:{str(message.receiver_id)}", str(message.id))
    except Exception as exc:
        logger.debug("WS publish (react) failed: %s", exc)
    return {"message": "Reaction updated", "reactions": reactions}

@router.post("/{message_id}/mark-read", status_code=status.HTTP_200_OK)
async def mark_message_read(
    message_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    """Mark a message read by receiver only."""
    await rate_limit(redis, str(current_user.id), "messages:mark_read", limit=120, window_seconds=60)
    try:
        msg_uuid = uuid.UUID(message_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid message_id")
    result = await db.execute(select(Message).where(Message.id == msg_uuid, Message.receiver_id == current_user.id))
    message = result.scalar_one_or_none()
    if not message:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    if not message.read_at:
        message.status = MessageStatus.READ
        message.read_at = datetime.now(timezone.utc)
        await db.commit()
        try:
            await redis.delete(f"unread:{str(current_user.id)}:{str(message.sender_id)}")
            await redis.publish(f"ws:messages:read:{str(message.sender_id)}", str(message.id))
        except Exception as exc:
            logger.debug("Unread/WS read update failed: %s", exc)
    return {"message": "Message marked as read"}
