from fastapi import APIRouter
from .auth import router as auth_router
from .messages import router as messages_router
from .media import router as media_router
from .calls import router as calls_router
from .websockets import router as websockets_router

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth_router, tags=["Authentication"])
api_router.include_router(messages_router, tags=["Messages"])
api_router.include_router(media_router, tags=["Media"])
api_router.include_router(calls_router, tags=["Calls"])
api_router.include_router(websockets_router, tags=["WebSocket"])
