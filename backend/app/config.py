from pydantic_settings import BaseSettings
from pydantic import validator, EmailStr, Field
from typing import Optional, List
import logging
import base64

logger = logging.getLogger(__name__)

class Settings(BaseSettings):
    # App info
    APP_NAME: str = "NoctisApp"
    VERSION: str = "1.0.0"
    DEBUG: bool = False  # Production-safe default

    # Database connection
    DATABASE_URL: str
    DATABASE_POOL_SIZE: int = Field(20, ge=5, le=100)
    DATABASE_MAX_OVERFLOW: int = Field(10, ge=0, le=50)

    # JWT Authentication
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Encryption key (base64-encoded)
    ENCRYPTION_KEY: str

    # CORS origins as a list of URLs
    CORS_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8080"]

    # Rate limiting & Redis config
    RATE_LIMIT_PER_MINUTE: int = 60
    REDIS_URL: Optional[str] = "redis://localhost:6379/0"

    # Email via SendGrid
    SENDGRID_API_KEY: str
    FROM_EMAIL: EmailStr

    # Cloudinary config for media uploads
    CLOUDINARY_CLOUD_NAME: str
    CLOUDINARY_API_KEY: str
    CLOUDINARY_API_SECRET: str

    # WebRTC TURN server config (optional)
    TURN_SERVER_URL: Optional[str] = None
    TURN_USERNAME: Optional[str] = None
    TURN_PASSWORD: Optional[str] = None

    # Validators
    @validator("JWT_SECRET_KEY")
    def check_jwt_secret_length(cls, v):
        if len(v) < 32:
            raise ValueError("JWT_SECRET_KEY must be at least 32 characters.")
        return v

    @validator("ENCRYPTION_KEY")
    def check_encryption_key(cls, v):
        try:
            decoded = base64.b64decode(v)
            if len(decoded) != 32:
                raise ValueError("Encryption key must be 32 bytes when decoded.")
        except Exception:
            raise ValueError("ENCRYPTION_KEY must be valid base64-encoded 32 byte key.")
        return v

    @validator("DATABASE_URL")
    def check_database_url(cls, v):
        if not v.startswith("postgresql"):
            raise ValueError("DATABASE_URL must be PostgreSQL.")
        if "asyncpg" not in v:
            logger.warning("Prefer asyncpg for async support.")
        return v

    @validator("REDIS_URL", pre=True, always=True)
    def check_redis_url(cls, v):
        if v and not v.startswith(("redis://", "rediss://")):
            raise ValueError("REDIS_URL must start with redis:// or rediss://")
        return v

    @validator("CORS_ORIGINS")
    def validate_cors_origins(cls, v, values):
        debug = values.get("DEBUG", False)
        if not debug and "*" in v:
            raise ValueError("Wildcard CORS origins (*) are not allowed in production.")
        return v

    class Config:
        env_file = ".env"
        case_sensitive = True

try:
    settings = Settings()
    logger.info(f"Loaded settings for {settings.APP_NAME} v{settings.VERSION}")
except Exception as e:
    logger.error(f"Failed to load settings: {e}")
    raise
