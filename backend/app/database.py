from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy import text
import logging
from typing import AsyncIterator

from .config import settings

logger = logging.getLogger(__name__)

# Production async SQLAlchemy engine (with pool and connect options)
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_size=getattr(settings, "DATABASE_POOL_SIZE", 5),
    max_overflow=getattr(settings, "DATABASE_MAX_OVERFLOW", 10),
    pool_timeout=30,            # seconds to wait for connection from pool
    pool_recycle=3600,          # recycle connections after 1 hour
    pool_pre_ping=True,         # test connections before using them
    connect_args={
        "server_settings": {"application_name": settings.APP_NAME}
    } if "postgresql" in settings.DATABASE_URL else {}
)

# Async session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

# DB Model base
Base = declarative_base()

# Dependency for async database session
async def get_db() -> AsyncIterator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception as e:
            await session.rollback()
            logger.error(f"Database session error: {e}")
            raise
        finally:
            await session.close()

# Database initialization (for startup and testing - use cautiously in prod)
async def init_db():
    """Initialize database tables"""
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Database tables created successfully")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        raise

# Health check utility for database
async def check_db_health() -> bool:
    """Check if database connection is healthy"""
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        logger.info("Database health check passed")
        return True
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        return False
