"""
Media Model for NoctisApp - UUID Architecture
"""

from sqlalchemy import Column, String, DateTime, Enum as SQLEnum, Boolean, Integer
from sqlalchemy.dialects.postgresql import UUID, JSONB
from datetime import datetime
import uuid
import enum
from app.database import Base


class MediaType(str, enum.Enum):
    """Enum for supported media types"""
    IMAGE = "image"
    VIDEO = "video"
    AUDIO = "audio"
    VOICE = "voice"
    DOCUMENT = "document"
    FILE = "file"


class MediaStatus(str, enum.Enum):
    """Enum for media processing status"""
    UPLOADING = "uploading"
    PROCESSING = "processing"
    READY = "ready"
    FAILED = "failed"


class Media(Base):
    """
    Media model for storing file metadata
    Actual files are stored in Cloudinary
    """
    __tablename__ = "media"

    # UUID primary key (matching Message model)
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # UUID foreign keys (matching Message.id and User.id)
    message_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    
    # Media information
    media_type = Column(SQLEnum(MediaType), nullable=False, index=True)
    status = Column(SQLEnum(MediaStatus), nullable=False, default=MediaStatus.UPLOADING)
    
    # File details
    filename = Column(String(255), nullable=False)
    original_filename = Column(String(255))
    file_size = Column(Integer)
    mime_type = Column(String(100))
    
    # Cloudinary URLs
    cloudinary_public_id = Column(String(255), unique=True, index=True)
    media_url = Column(String(500), nullable=False)
    thumbnail_url = Column(String(500))
    
    # Metadata using JSONB (RENAMED FROM metadata TO media_metadata)
    media_metadata = Column(JSONB, default=dict)
    
    # Processing metadata
    is_compressed = Column(Boolean, default=False)
    compression_quality = Column(Integer)
    
    # Timestamps (matching Message timestamp pattern)
    uploaded_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    processed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<Media(id={self.id}, type={self.media_type}, filename={self.filename})>"
    
    def to_dict(self):
        """Convert media object to dictionary"""
        return {
            "id": str(self.id),
            "message_id": str(self.message_id),
            "user_id": str(self.user_id),
            "media_type": self.media_type.value,
            "status": self.status.value,
            "filename": self.filename,
            "original_filename": self.original_filename,
            "file_size": self.file_size,
            "mime_type": self.mime_type,
            "media_url": self.media_url,
            "thumbnail_url": self.thumbnail_url,
            "media_metadata": self.media_metadata,
            "is_compressed": self.is_compressed,
            "compression_quality": self.compression_quality,
            "uploaded_at": self.uploaded_at.isoformat() if self.uploaded_at else None,
            "processed_at": self.processed_at.isoformat() if self.processed_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
