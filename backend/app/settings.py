from pydantic_settings import BaseSettings
from pydantic import PostgresDsn, RedisDsn, EmailStr, Field
from typing import List, Optional

class Settings(BaseSettings):
    # Application
    APP_NAME: str = "NoctisApp"
    VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Database
    DATABASE_URL: PostgresDsn
    DATABASE_POOL_SIZE: int = 5
    DATABASE_MAX_OVERFLOW: int = 10

    # JWT
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Encryption
    ENCRYPTION_KEY: str

    # CORS
    CORS_ORIGINS: List[str] = Field(default_factory=list)

    # Trusted hosts
    TRUSTED_HOSTS: List[str] = Field(default_factory=lambda: [
        "noctisapp.com", "*.noctisapp.com", "api.noctisapp.com"
    ])

    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60

    # Email
    SENDGRID_API_KEY: str
    FROM_EMAIL: EmailStr

    # Cloudinary
    CLOUDINARY_CLOUD_NAME: str
    CLOUDINARY_API_KEY: str
    CLOUDINARY_API_SECRET: str

    # Redis (Optional)
    REDIS_URL: Optional[RedisDsn] = None

    # WebRTC TURN Server (Optional)
    TURN_SERVER_URL: Optional[str] = None
    TURN_USERNAME: Optional[str] = None
    TURN_PASSWORD: Optional[str] = None

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
