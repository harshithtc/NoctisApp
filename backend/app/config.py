from pydantic_settings import BaseSettings
from pydantic import validator, EmailStr
from typing import Optional, List
import json
import logging
import base64

logger = logging.getLogger(__name__)

class Settings(BaseSettings):
    # App Info
    APP_NAME: str = "NoctisApp"
    VERSION: str = "1.0.0"
    DEBUG: bool = True

    # Database
    DATABASE_URL: str
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 10

    # JWT & Auth
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Encryption
    ENCRYPTION_KEY: str

    # CORS
    CORS_ORIGINS: str = '["http://localhost:3000","http://localhost:8080"]'

    # Rate Limiting & Redis
    RATE_LIMIT_PER_MINUTE: int = 60
    REDIS_URL: Optional[str] = "redis://localhost:6379/0"

    # Email (SendGrid)
    SENDGRID_API_KEY: str
    FROM_EMAIL: EmailStr

    # Cloudinary Integration
    CLOUDINARY_CLOUD_NAME: str
    CLOUDINARY_API_KEY: str
    CLOUDINARY_API_SECRET: str

    # WebRTC TURN Server
    TURN_SERVER_URL: Optional[str] = None
    TURN_USERNAME: Optional[str] = None
    TURN_PASSWORD: Optional[str] = None

    # Validators
    @validator('JWT_SECRET_KEY')
    def validate_jwt_secret(cls, v):
        if len(v) < 32:
            raise ValueError("JWT_SECRET_KEY must be at least 32 characters.")
        return v

    @validator('ENCRYPTION_KEY')
    def validate_encryption_key(cls, v):
        try:
            decoded = base64.b64decode(v)
            if len(decoded) != 32:
                raise ValueError("Encryption key must be 32 bytes when decoded.")
        except Exception:
            raise ValueError("ENCRYPTION_KEY must be valid base64-encoded 32 byte key.")
        return v

    @validator('DATABASE_URL')
    def validate_database_url(cls, v):
        if not v.startswith('postgresql'):
            raise ValueError("DATABASE_URL must be PostgreSQL.")
        if 'asyncpg' not in v:
            logger.warning("Prefer asyncpg for async support.")
        return v

    @validator('CORS_ORIGINS')
    def validate_cors_origins(cls, v, values):
        try:
            origins = json.loads(v)
            if not isinstance(origins, list):
                raise ValueError("CORS_ORIGINS must be JSON array.")
            debug = values.get('DEBUG', True)
            if not debug and "*" in origins:
                raise ValueError("Wildcard CORS origins (*) are not allowed in production.")
            return v
        except json.JSONDecodeError:
            raise ValueError("CORS_ORIGINS must be valid JSON array")

    @validator('DATABASE_POOL_SIZE')
    def validate_pool_size(cls, v):
        if v < 5 or v > 100:
            raise ValueError("DATABASE_POOL_SIZE must be 5-100.")
        return v

    @validator('DATABASE_MAX_OVERFLOW')
    def validate_max_overflow(cls, v):
        if v < 0 or v > 50:
            raise ValueError("DATABASE_MAX_OVERFLOW must be 0-50.")
        return v

    # Utility methods
    def get_cors_origins(self) -> List[str]:
        try:
            origins = json.loads(self.CORS_ORIGINS)
            logger.info(f"CORS Origins: {origins}")
            return origins
        except Exception as e:
            logger.error(f"Failed to parse CORS_ORIGINS: {e}")
            return ["http://localhost:3000"]

    @property
    def cors_origins_list(self) -> List[str]:
        return self.get_cors_origins()

    class Config:
        env_file = ".env"
        case_sensitive = True

try:
    settings = Settings()
    logger.info(f"Settings loaded for {settings.APP_NAME} v{settings.VERSION}")
    logger.info(f"Debug mode: {settings.DEBUG}")
    logger.info(f"Database pool: {settings.DATABASE_POOL_SIZE}+{settings.DATABASE_MAX_OVERFLOW}")
except Exception as e:
    logger.error(f"Failed to load settings: {e}")
    raise
