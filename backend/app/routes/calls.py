from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from typing import List, Optional, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from redis.asyncio import Redis
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models.message import Call
from app.models.user import User
from app.routes.auth import get_current_user

logger = logging.getLogger("app.routes.calls")

router = APIRouter(tags=["Calls"])  # Prefix handled by api_router

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

class IceServer(BaseModel):
    urls: List[str]
    username: Optional[str] = None
    credential: Optional[str] = None

class TurnCredentialsResponse(BaseModel):
    iceServers: List[IceServer]
    ttl: int = 3600

class InitiateCallRequest(BaseModel):
    receiver_id: uuid.UUID
    call_type: Literal["voice", "video"] = "voice"

class InitiateCallResponse(BaseModel):
    id: str
    status: Literal["initiated", "answered", "ended", "declined"] = "initiated"
    started_at: str

class SimpleMessageResponse(BaseModel):
    message: str
    duration: Optional[int] = None

class CallStatusResponse(BaseModel):
    id: str
    type: Literal["voice", "video"]
    status: Literal["initiated", "answered", "ended", "declined"]
    duration: Optional[int]
    started_at: str
    answered_at: Optional[str] = None
    ended_at: Optional[str] = None
    caller_id: str
    receiver_id: str

def _default_ice_servers() -> List[IceServer]:
    servers: List[IceServer] = [
        IceServer(urls=["stun:stun.l.google.com:19302"]),
        IceServer(urls=["stun:global.stun.twilio.com:3478"]),
    ]
    turn_url: Optional[str] = getattr(settings, "TURN_SERVER_URL", None)
    turn_user: Optional[str] = getattr(settings, "TURN_USERNAME", None)
    turn_pass: Optional[str] = getattr(settings, "TURN_PASSWORD", None)
    if turn_url:
        urls = [turn_url]
        if "?transport=" not in turn_url:
            urls.append(f"{turn_url}?transport=udp")
            urls.append(f"{turn_url}?transport=tcp")
        servers.append(
            IceServer(
                urls=urls,
                username=turn_user,
                credential=turn_pass,
            )
        )
    return servers

async def _write_call_state(redis: Redis, call_id: str, data: dict, ttl: int = 3600) -> None:
    await redis.set(f"call:{call_id}", json.dumps(data, default=str), ex=ttl)

async def _read_call_state(redis: Redis, call_id: str) -> Optional[dict]:
    raw = await redis.get(f"call:{call_id}")
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None

@router.get("/turn-credentials", response_model=TurnCredentialsResponse)
async def get_turn_credentials(current_user: User = Depends(get_current_user)) -> TurnCredentialsResponse:
    return TurnCredentialsResponse(iceServers=_default_ice_servers(), ttl=3600)

@router.post("/initiate", response_model=InitiateCallResponse, status_code=status.HTTP_201_CREATED)
async def initiate_call(
    payload: InitiateCallRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
) -> InitiateCallResponse:
    await rate_limit(redis, str(current_user.id), "calls:initiate", limit=10, window_seconds=30)
    call = Call(
        caller_id=current_user.id,
        receiver_id=payload.receiver_id,
        call_type=payload.call_type,
        status="initiated",
    )
    db.add(call)
    await db.commit()
    await db.refresh(call)
    call_id = str(call.id)
    now = (call.started_at or datetime.now(timezone.utc)).isoformat()
    ttl_seconds = 3600
    state = {
        "call_id": call_id,
        "status": "initiated",
        "caller_id": str(call.caller_id),
        "receiver_id": str(call.receiver_id),
        "call_type": call.call_type,
        "started_at": now,
        "answered_at": call.answered_at.isoformat() if call.answered_at else None,
        "ended_at": call.ended_at.isoformat() if call.ended_at else None,
        "duration": call.duration,
        "channel": f"ws:call:{call_id}",
        "meta": {},
    }
    await _write_call_state(redis, call_id, state, ttl=ttl_seconds)
    await redis.sadd(f"user:{call.caller_id}:calls", call_id)
    await redis.sadd(f"user:{call.receiver_id}:calls", call_id)
    await redis.expire(f"user:{call.caller_id}:calls", ttl_seconds)
    await redis.expire(f"user:{call.receiver_id}:calls", ttl_seconds)
    return InitiateCallResponse(id=call_id, status="initiated", started_at=now)

@router.post("/{call_id}/answer", response_model=SimpleMessageResponse)
async def answer_call(
    call_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    await rate_limit(redis, str(current_user.id), "calls:answer", limit=30, window_seconds=60)
    try:
        call_uuid = uuid.UUID(call_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid call_id")
    result = await db.execute(select(Call).where(Call.id == call_uuid))
    call: Optional[Call] = result.scalar_one_or_none()
    if not call:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Call not found")
    if call.receiver_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the receiver can answer the call")
    if call.status == "ended":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Call already ended")
    call.status = "answered"
    call.answered_at = datetime.now(timezone.utc)
    await db.commit()
    state = await _read_call_state(redis, call_id) or {}
    state.update({"status": "answered", "answered_at": call.answered_at.isoformat() if call.answered_at else None})
    await _write_call_state(redis, call_id, state, ttl=1800)
    return SimpleMessageResponse(message="Call answered")

@router.post("/{call_id}/end", response_model=SimpleMessageResponse)
async def end_call(
    call_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    await rate_limit(redis, str(current_user.id), "calls:end", limit=30, window_seconds=60)
    try:
        call_uuid = uuid.UUID(call_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid call_id")
    result = await db.execute(select(Call).where(Call.id == call_uuid))
    call: Optional[Call] = result.scalar_one_or_none()
    if not call:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Call not found")
    if current_user.id not in (call.caller_id, call.receiver_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to end this call")
    if call.status != "ended":
        call.status = "ended"
        call.ended_at = datetime.now(timezone.utc)
        if call.answered_at:
            call.duration = int((call.ended_at - call.answered_at).total_seconds())
        await db.commit()
    state = await _read_call_state(redis, call_id) or {}
    state.update({"status": "ended", "ended_at": call.ended_at.isoformat() if call.ended_at else None, "duration": call.duration})
    await _write_call_state(redis, call_id, state, ttl=300)
    return SimpleMessageResponse(message="Call ended", duration=call.duration)

@router.get("/{call_id}", response_model=CallStatusResponse)
async def get_call_status(
    call_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
) -> CallStatusResponse:
    await rate_limit(redis, str(current_user.id), "calls:status", limit=60, window_seconds=60)
    state = await _read_call_state(redis, call_id)
    if not state:
        try:
            call_uuid = uuid.UUID(call_id)
        except Exception:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid call_id")
        result = await db.execute(select(Call).where(Call.id == call_uuid))
        call: Optional[Call] = result.scalar_one_or_none()
        if not call:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Call not found")
        state = {
            "call_id": str(call.id),
            "status": call.status,
            "caller_id": str(call.caller_id),
            "receiver_id": str(call.receiver_id),
            "call_type": call.call_type,
            "started_at": (call.started_at or datetime.now(timezone.utc)).isoformat(),
            "answered_at": call.answered_at.isoformat() if call.answered_at else None,
            "ended_at": call.ended_at.isoformat() if call.ended_at else None,
            "duration": call.duration,
        }
    uid = str(current_user.id)
    if uid not in (state["caller_id"], state["receiver_id"]):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to view this call")
    return CallStatusResponse(
        id=state["call_id"],
        type=state.get("call_type", "voice"),
        status=state["status"],
        duration=state.get("duration"),
        started_at=state["started_at"],
        answered_at=state.get("answered_at"),
        ended_at=state.get("ended_at"),
        caller_id=state["caller_id"],
        receiver_id=state["receiver_id"],
    )

@router.get("/history")
async def get_call_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Call)
        .where(or_(Call.caller_id == current_user.id, Call.receiver_id == current_user.id))
        .order_by(Call.started_at.desc())
        .limit(50)
    )
    calls = result.scalars().all()
    return [
        {
            "id": str(call.id),
            "type": call.call_type,
            "status": call.status,
            "duration": call.duration,
            "started_at": (call.started_at or datetime.now(timezone.utc)).isoformat(),
        }
        for call in calls
    ]
