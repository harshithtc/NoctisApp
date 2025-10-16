from sqlalchemy import Column, String, Boolean, DateTime, Text, Index, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from datetime import datetime
import uuid
from app.database import Base

# User model with rich profile/security fields and proper indexing
class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    email_verified = Column(Boolean, default=False)
    password_hash = Column(String(255), nullable=False)

    # Profile
    name = Column(String(100), nullable=False)
    avatar_url = Column(String(500))
    bio = Column(Text)
    phone_number = Column(String(20), unique=True, nullable=True)
    phone_verified = Column(Boolean, default=False)

    # Security (2FA & E2EE public key)
    two_factor_enabled = Column(Boolean, default=False)
    two_factor_secret = Column(String(32))      # store TOTP secret if enabled (encrypted at rest)
    encryption_public_key = Column(Text)        # client-generated public key for E2EE

    # Pairing/Partner for special modes
    partner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    # Timestamps (using func.now() for timezone awareness)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    last_seen = Column(DateTime(timezone=True), server_default=func.now())

    # Account status
    is_active = Column(Boolean, default=True)
    is_deleted = Column(Boolean, default=False)

    __table_args__ = (
        Index('idx_email_active', 'email', 'is_active'),
        Index('idx_partner_lookup', 'partner_id'),
    )

# Per-device/session refresh token handling
class UserSession(Base):
    __tablename__ = "user_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    refresh_token = Column(String(500), unique=True, nullable=False, index=True)
    device_info = Column(Text)                  # JSON string of device metadata
    ip_address = Column(String(45))             # IPv4/IPv6 notation
    user_agent = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
    last_used = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index('idx_user_active_sessions', 'user_id', 'is_active'),
        Index('idx_session_expiry', 'expires_at'),
    )

# Email OTP/verification flow
class EmailVerification(Base):
    __tablename__ = "email_verifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    email = Column(String(255), nullable=False)
    code = Column(String(6), nullable=False)          # 6-digit code
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
    verified = Column(Boolean, default=False)

    __table_args__ = (
        Index('idx_verification_lookup', 'user_id', 'email', 'verified'),
        Index('idx_verification_expiry', 'expires_at'),
    )
