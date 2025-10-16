from __future__ import annotations

import logging
import uuid
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
# FIX: use Uvicorn's proxy headers middleware (Starlette path is deprecated/removed)
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from .config import settings
from .database import engine, init_db
from .routes import auth, messages, media, calls, websockets

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=logging.DEBUG if getattr(settings, "DEBUG", False) else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("app.main")

# -----------------------------------------------------------------------------
# Lifespan
# -----------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("%s v%s starting...", settings.APP_NAME, settings.VERSION)
    logger.info("Debug mode: %s", settings.DEBUG)

    # Initialize database (migrations should be handled outside the app)
    try:
        await init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error("Database initialization failed: %s", e, exc_info=True)
        raise

    yield

    # Graceful shutdown
    logger.info("Application shutting down...")
    try:
        await engine.dispose()
        logger.info("Database connections closed")
    except Exception as e:
        logger.error("Error during shutdown: %s", e)
    logger.info("Application shut down successfully")

# -----------------------------------------------------------------------------
# App
# -----------------------------------------------------------------------------
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan,
)

# Ensure proxy headers (scheme/IP) are respected behind load balancers/reverse proxies.
# Keep this before middlewares that rely on client IP or scheme.
# In production, prefer specific IPs/ranges instead of "*".
app.add_middleware(
    ProxyHeadersMiddleware,
    trusted_hosts=getattr(settings, "TRUSTED_HOSTS", ["*"]),
)

# -----------------------------------------------------------------------------
# Rate limiting (proxy-aware IP)
# -----------------------------------------------------------------------------
def real_ip_key_func(request: Request) -> str:
    xff = request.headers.get("x-forwarded-for")
    if xff:
        return xff.split(",")[0].strip()
    return request.client.host if request.client else "unknown"

limiter = Limiter(
    key_func=real_ip_key_func,
    default_limits=[f"{getattr(settings, 'RATE_LIMIT_PER_MINUTE', 60)}/minute"],
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# -----------------------------------------------------------------------------
# Trusted hosts / HTTPS enforcement (prod)
# -----------------------------------------------------------------------------
trusted_hosts = getattr(settings, "TRUSTED_HOSTS", None)
if not settings.DEBUG and trusted_hosts:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=trusted_hosts)

# If TLS terminates at an edge proxy, consider doing the redirect there to avoid loops.
if not settings.DEBUG:
    app.add_middleware(HTTPSRedirectMiddleware)

# -----------------------------------------------------------------------------
# CORS (use exact production origins only; keep localhost in dev envs)
# -----------------------------------------------------------------------------
cors_origins = getattr(settings, "CORS_ORIGINS", [])
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Requested-With", "X-CSRF-Token"],
    expose_headers=["X-Request-ID", "X-Process-Time"],
)

# -----------------------------------------------------------------------------
# Security headers
# -----------------------------------------------------------------------------
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    resp = await call_next(request)
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Referrer-Policy"] = "no-referrer"
    resp.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    if not settings.DEBUG:
        resp.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    # Minimal CSP for APIs (optional). Alternatively, omit CSP entirely on APIs.
    resp.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'; base-uri 'none'"
    return resp

# -----------------------------------------------------------------------------
# Request ID + access logging (avoid logging sensitive headers/bodies)
# -----------------------------------------------------------------------------
@app.middleware("http")
async def add_request_id(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    client_ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip() or (
        request.client.host if request.client else "unknown"
    )
    logger.info("Request %s %s [ID:%s] [IP:%s]", request.method, request.url.path, request_id, client_ip)

    start = datetime.utcnow()
    resp = await call_next(request)
    elapsed = (datetime.utcnow() - start).total_seconds()
    resp.headers["X-Request-ID"] = request_id
    resp.headers["X-Process-Time"] = f"{elapsed:.3f}"
    logger.info("Response %s [ID:%s] [%.3fs]", resp.status_code, request_id, elapsed)
    return resp

# -----------------------------------------------------------------------------
# Simple body-size guard (header-based; adjust limits to your needs)
# -----------------------------------------------------------------------------
MAX_JSON_BYTES = 2 * 1024 * 1024      # 2 MiB
MAX_UPLOAD_BYTES = 50 * 1024 * 1024   # 50 MiB

@app.middleware("http")
async def body_size_limit(request: Request, call_next):
    cl_header: Optional[str] = request.headers.get("content-length")
    try:
        size = int(cl_header) if cl_header else 0
    except ValueError:
        size = 0

    ctype = (request.headers.get("content-type") or "").lower()
    if "multipart/form-data" in ctype:
        if size and size > MAX_UPLOAD_BYTES:
            return JSONResponse(status_code=413, content={"detail": "Payload too large"})
    else:
        if size and size > MAX_JSON_BYTES:
            return JSONResponse(status_code=413, content={"detail": "Payload too large"})
    return await call_next(request)

# -----------------------------------------------------------------------------
# Exception handlers (consistent error shape)
# -----------------------------------------------------------------------------
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "detail": "Validation error",
            "errors": exc.errors(),
            "request_id": getattr(request.state, "request_id", "unknown"),
        },
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", "unknown")
    logger.error("Unhandled exception [ID:%s]: %s", request_id, str(exc), exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Internal server error" if not settings.DEBUG else str(exc),
            "request_id": request_id,
        },
    )

# -----------------------------------------------------------------------------
# Routers
# -----------------------------------------------------------------------------
app.include_router(auth.router, tags=["Authentication"])
app.include_router(messages.router, tags=["Messages"])
app.include_router(media.router, tags=["Media"])
app.include_router(calls.router, tags=["Calls"])
app.include_router(websockets.router, tags=["WebSocket"])

# -----------------------------------------------------------------------------
# Health/Root
# -----------------------------------------------------------------------------
@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "version": settings.VERSION,
        "app": settings.APP_NAME,
        "timestamp": datetime.utcnow().isoformat(),
    }

@app.get("/", tags=["Root"])
async def root():
    return {
        "app": settings.APP_NAME,
        "version": settings.VERSION,
        "status": "running",
        "docs": "/docs" if settings.DEBUG else "Disabled in production",
    }

# -----------------------------------------------------------------------------
# Local run
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=getattr(settings, "DEBUG", False),
        log_level="info",
        # If running behind a proxy locally and you removed the middleware, enable:
        # proxy_headers=True, forwarded_allow_ips="*",
    )
