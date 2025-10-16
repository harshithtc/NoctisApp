from __future__ import annotations

import asyncio
import contextlib
import json
import logging
import uuid
from typing import Dict, Set, Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, status
from redis.asyncio import Redis

from app.config import settings

# Prefer using the same JWT utilities/keys as the HTTP stack
# AuthService should validate signature, expiry, token type, and return payload with `sub` and `jti`
from app.services.auth import AuthService  # keep compatibility with existing code

logger = logging.getLogger("app.routes.websockets")

router = APIRouter()

# Redis singleton for pub/sub and rate-limits
_redis_client: Optional[Redis] = None


async def get_redis() -> Redis:
    global _redis_client
    if _redis_client is None:
        if not getattr(settings, "REDIS_URL", None):
            # For WS, close with Policy Violation if infra missing
            raise RuntimeError("Redis not configured")
        _redis_client = Redis.from_url(settings.REDIS_URL, encoding="utf-8", decode_responses=True)
        try:
            await _redis_client.ping()
        except Exception as exc:
            logger.exception("Redis ping failed: %s", exc)
            raise RuntimeError("Redis not available")
    return _redis_client


class ConnectionManager:
    """
    Manages multiple concurrent connections per user across devices.
    """

    def __init__(self):
        # user_id -> set of WebSocket
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self.active_connections.setdefault(user_id, set()).add(websocket)
        logger.info("WS connected: user=%s total=%d", user_id, len(self.active_connections[user_id]))

    def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        conns = self.active_connections.get(user_id)
        if not conns:
            return
        if websocket in conns:
            conns.remove(websocket)
        if not conns:
            self.active_connections.pop(user_id, None)
        logger.info("WS disconnected: user=%s remaining=%d", user_id, len(self.active_connections.get(user_id, [])))

    async def send_to_user(self, user_id: str, message: dict) -> None:
        """
        Sends to all active connections for the user.
        """
        conns = self.active_connections.get(user_id, set()).copy()
        if not conns:
            return
        data = json.dumps(message, separators=(",", ":"))
        for ws in list(conns):
            try:
                await ws.send_text(data)
            except Exception as e:
                logger.error("WS send error to %s: %s", user_id, e)
                self.disconnect(user_id, ws)

    async def broadcast_typing(self, sender_id: str, receiver_id: str, is_typing: bool) -> None:
        await self.send_to_user(
            receiver_id,
            {
                "type": "typing",
                "sender_id": sender_id,
                "is_typing": bool(is_typing),
            },
        )

    async def echo(self, user_id: str, payload: dict) -> None:
        await self.send_to_user(user_id, {"type": "echo", "payload": payload})


manager = ConnectionManager()


async def rate_limit(redis: Redis, user_id: str, action_key: str, limit: int, window_seconds: int) -> None:
    """
    Simple sliding-window limiter: limit events per window_seconds.
    """
    key = f"rl:{user_id}:{action_key}"
    try:
        current = await redis.incr(key)
        if current == 1:
            await redis.expire(key, window_seconds)
        if current > limit:
            ttl = await redis.ttl(key)
            raise RuntimeError(f"rate_limited:{ttl if ttl > 0 else window_seconds}")
    except RuntimeError:
        raise
    except Exception as exc:
        logger.warning("WS rate limiter error for %s: %s", key, exc)


async def _subscribe_user_channels(redis: Redis, user_id: str):
    """
    Subscribe to Redis pubsub patterns for this user:
      - ws:messages:{user_id}
      - ws:messages:react:{user_id}
      - ws:messages:read:{user_id}
      - ws:notify:{user_id}
      - ws:call:*:{user_id} (optional patterns if used)
    Uses PSUBSCRIBE to catch all relevant topics without creating many subscriptions.
    """
    pubsub = redis.pubsub()
    # Patterns focused on this user's events
    patterns = [
        f"ws:messages:{user_id}",
        f"ws:messages:react:{user_id}",
        f"ws:messages:read:{user_id}",
        f"ws:notify:{user_id}",
        f"ws:*:{user_id}",  # generic catch-all for future channels
    ]
    await pubsub.psubscribe(*patterns)
    return pubsub


async def _pubsub_forwarder(user_id: str, websocket: WebSocket, redis: Redis, pubsub) -> None:
    """
    Forwards messages from Redis pubsub to the user's WebSocket connections.
    """
    try:
        async for msg in pubsub.listen():
            if msg is None:
                continue
            if msg.get("type") not in ("pmessage", "message"):
                continue
            raw = msg.get("data")
            # raw may be str (from publish) or dict (unlikely); normalize to text
            try:
                payload = json.loads(raw) if isinstance(raw, str) else raw
            except Exception:
                payload = {"type": "event", "data": raw}
            await manager.send_to_user(user_id, payload)
    except asyncio.CancelledError:
        # Expected on disconnect
        pass
    except Exception as exc:
        logger.debug("PubSub forwarder stopped for %s: %s", user_id, exc)
    finally:
        with contextlib.suppress(Exception):
            await pubsub.close()


async def _validate_token_and_blacklist(token: str, redis: Redis) -> dict:
    """
    Validates JWT and checks Redis blacklist (if jti available).
    Returns payload dict on success, raises on failure.
    """
    payload = AuthService.verify_token(token, "access")
    if not payload:
        raise RuntimeError("invalid_token")

    jti = payload.get("jti")
    if jti:
        try:
            blacklisted = await redis.sismember("jwt:blacklist", jti)
            if blacklisted:
                raise RuntimeError("token_blacklisted")
        except Exception as exc:
            # Fail-closed for blacklist to be safe; can relax if required
            logger.warning("JWT blacklist check failed: %s", exc)
            raise RuntimeError("blacklist_check_failed")
    return payload


async def _handle_client_event(user_id: str, data: dict, redis: Redis) -> None:
    """
    Handle inbound client events.
    Only metadata/notifications are routed here; message creation happens over REST.
    """
    kind = data.get("type")
    # Lightweight, per-event type throttles
    if kind == "ping":
        await rate_limit(redis, user_id, "ws:ping", limit=30, window_seconds=30)
        await manager.send_to_user(user_id, {"type": "pong"})
        return

    if kind == "typing":
        await rate_limit(redis, user_id, "ws:typing", limit=120, window_seconds=60)
        receiver_id = str(data.get("receiver_id") or "")
        if not receiver_id:
            return
        await manager.broadcast_typing(user_id, receiver_id, bool(data.get("is_typing", False)))
        return

    if kind == "read_receipt":
        await rate_limit(redis, user_id, "ws:read", limit=240, window_seconds=60)
        receiver_id = str(data.get("receiver_id") or "")
        message_ids = data.get("message_ids") or []
        event = {
            "type": "messages_read",
            "from": user_id,
            "message_ids": message_ids,
            "read_at": data.get("read_at"),
        }
        # Fan out to receiver via direct WS and pubsub channel for offline clients
        await manager.send_to_user(receiver_id, event)
        try:
            await redis.publish(f"ws:messages:read:{receiver_id}", json.dumps(event, separators=(",", ":")))
        except Exception:
            pass
        return

    if kind == "signal":
        # Call/WebRTC signaling pass-through: offer/answer/candidate
        await rate_limit(redis, user_id, "ws:signal", limit=240, window_seconds=60)
        to = str(data.get("to") or "")
        if not to:
            return
        signal = {
            "type": "signal",
            "from": user_id,
            "call_id": data.get("call_id"),
            "signal_type": data.get("signal_type"),  # "offer" | "answer" | "candidate"
            "payload": data.get("payload"),
        }
        await manager.send_to_user(to, signal)
        # Also publish for other connected devices of the recipient
        try:
            await redis.publish(f"ws:call:{to}", json.dumps(signal, separators=(",", ":")))
        except Exception:
            pass
        return

    if kind == "party":
        # Optional party sync relay; REST/WS dedicated endpoints to be added if needed
        await rate_limit(redis, user_id, "ws:party", limit=240, window_seconds=60)
        room_id = str(data.get("room_id") or "")
        action = data.get("action")  # "play" | "pause" | "seek" | "state"
        event = {
            "type": "party",
            "from": user_id,
            "room_id": room_id,
            "action": action,
            "timestamp": data.get("timestamp"),
            "position": data.get("position"),
            "provider": data.get("provider"),  # "spotify" | "youtube"
            "track_id": data.get("track_id"),
        }
        # Broadcast by room topic; clients should subscribe by mapping room_id -> user_ids
        try:
            await redis.publish(f"ws:party:{room_id}", json.dumps(event, separators=(",", ":")))
        except Exception:
            pass
        return

    if kind == "message":
        # For clients that send provisional "message" over WS, just notify receiver.
        await rate_limit(redis, user_id, "ws:message_meta", limit=240, window_seconds=60)
        receiver_id = str(data.get("receiver_id") or "")
        notify = {
            "type": "new_message",
            "from": user_id,
            "message_id": data.get("message_id"),
            "client_id": data.get("client_id"),
            "delivered_at": data.get("delivered_at"),
        }
        await manager.send_to_user(receiver_id, notify)
        try:
            await redis.publish(f"ws:messages:{receiver_id}", json.dumps(notify, separators=(",", ":")))
        except Exception:
            pass
        return

    # Unknown event: echo for debugging
    await manager.echo(user_id, {"unknown": data})


@router.websocket("/ws/chat")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(..., description="JWT access token")):
    """
    WebSocket endpoint for real-time events:
      - Push delivery of new messages, reactions, read receipts
      - Typing indicators
      - Call/WebRTC signaling
      - Optional party sync relay
    Auth:
      - token must be a valid access token; blacklist is enforced via Redis set jwt:blacklist containing jti values.
    """
    # Verify token and blacklist
    try:
        redis = await get_redis()
        payload = await _validate_token_and_blacklist(token, redis)
    except Exception as exc:
        # Policy Violation close code
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        logger.warning("WS auth failed: %s", exc)
        return

    user_id = str(payload.get("sub") or "")
    if not user_id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Connect and spin up pubsub forwarder for this user
    await manager.connect(user_id, websocket)

    # Subscribe to user-specific channels
    try:
        pubsub = await _subscribe_user_channels(redis, user_id)
    except Exception as exc:
        logger.error("WS subscribe failed for %s: %s", user_id, exc)
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
        manager.disconnect(user_id, websocket)
        return

    forwarder_task = asyncio.create_task(_pubsub_forwarder(user_id, websocket, redis, pubsub))

    try:
        while True:
            # Small receive rate-limit
            await rate_limit(redis, user_id, "ws:recv", limit=300, window_seconds=60)

            # Receive text/json; normalize to dict
            incoming = await websocket.receive_text()
            try:
                data = json.loads(incoming)
            except Exception:
                data = {"type": "unknown", "raw": incoming}

            await _handle_client_event(user_id, data, redis)

    except WebSocketDisconnect:
        pass
    except asyncio.CancelledError:
        pass
    except Exception as e:
        logger.error("WebSocket error for user %s: %s", user_id, e)
    finally:
        forwarder_task.cancel()
        with contextlib.suppress(Exception):
            await forwarder_task
        manager.disconnect(user_id, websocket)
