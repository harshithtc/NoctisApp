from sqlalchemy import (
    Column, String, Boolean, DateTime, Text, Integer,
    Enum as SQLEnum, Index
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from datetime import datetime
import uuid
import enum
from app.database import Base

# Message Types
class MessageType(str, enum.Enum):
    TEXT = "text"
    IMAGE = "image"
    VIDEO = "video"
    AUDIO = "audio"
    FILE = "file"
    VOICE = "voice"

# Message Statuses
class MessageStatus(str, enum.Enum):
    QUEUED = "queued"
    SENDING = "sending"
    SENT = "sent"
    DELIVERED = "delivered"
    READ = "read"
    FAILED = "failed"

class Message(Base):
    __tablename__ = "messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    client_id = Column(String(100), unique=True, nullable=False, index=True)
    sender_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    receiver_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    message_type = Column(SQLEnum(MessageType), default=MessageType.TEXT)
    # Content + Encryption
    encrypted_content = Column(Text, nullable=False)
    encryption_iv = Column(String(100))
    # Media
    media_url = Column(String(500))
    media_thumbnail_url = Column(String(500))
    media_metadata = Column(JSONB)
    # Features
    reply_to_id = Column(UUID(as_uuid=True), nullable=True)
    reactions = Column(JSONB, default=dict)
    # Self-destruct / View-once
    is_view_once = Column(Boolean, default=False)
    self_destruct_timer = Column(Integer, nullable=True)
    viewed_at = Column(DateTime, nullable=True)
    # Status
    status = Column(SQLEnum(MessageStatus), default=MessageStatus.SENT)
    delivered_at = Column(DateTime, nullable=True)
    read_at = Column(DateTime, nullable=True)
    # Deletion features
    deleted_by_sender = Column(Boolean, default=False)
    deleted_by_receiver = Column(Boolean, default=False)
    deleted_for_everyone = Column(Boolean, default=False)
    deleted_for_everyone_at = Column(DateTime, nullable=True)
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Call(Base):
    __tablename__ = "calls"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    caller_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    receiver_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    call_type = Column(String(20), default="voice")  # voice/video
    status = Column(String(20), default="initiated") # initiated, ringing, active, ended
    webrtc_session_id = Column(String(100))
    started_at = Column(DateTime, default=datetime.utcnow)
    answered_at = Column(DateTime, nullable=True)
    ended_at = Column(DateTime, nullable=True)
    duration = Column(Integer, default=0)
    __table_args__ = (
        Index('idx_user_calls', 'caller_id', 'receiver_id'),
    )

class SyncSession(Base):
    __tablename__ = "sync_sessions"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_type = Column(String(20))  # "spotify", "youtube", etc
    initiator_id = Column(UUID(as_uuid=True), nullable=False)
    participant_id = Column(UUID(as_uuid=True), nullable=False)
    content_id = Column(String(255))
    content_url = Column(String(500))
    content_metadata = Column(JSONB)
    status = Column(String(20), default="pending")
    current_timestamp = Column(Integer, default=0)
    is_playing = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    ended_at = Column(DateTime, nullable=True)
