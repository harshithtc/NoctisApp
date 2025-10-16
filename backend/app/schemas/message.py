from pydantic import BaseModel, Field
from typing import Optional, Dict, List
from datetime import datetime
from app.models.message import MessageType, MessageStatus

class MessageCreate(BaseModel):
    """Schema for sending a new message"""
    client_id: str
    receiver_id: str
    message_type: MessageType = MessageType.TEXT
    encrypted_content: str
    encryption_iv: str
    media_url: Optional[str] = None
    media_thumbnail_url: Optional[str] = None
    media_metadata: Optional[Dict] = None
    reply_to_id: Optional[str] = None
    is_view_once: bool = False
    self_destruct_timer: Optional[int] = None

class MessageResponse(BaseModel):
    """Schema for reading a message"""
    id: str
    client_id: str
    sender_id: str
    receiver_id: str
    message_type: MessageType
    encrypted_content: str
    encryption_iv: str
    media_url: Optional[str]
    media_thumbnail_url: Optional[str]
    media_metadata: Optional[Dict]
    reply_to_id: Optional[str]
    reactions: Dict
    status: MessageStatus
    delivered_at: Optional[datetime]
    read_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True  # For SQLAlchemy/ORM/FastAPI integration

class MessageReaction(BaseModel):
    """Schema for reacting to a message"""
    message_id: str
    emoji: str

class MessageDelete(BaseModel):
    """Schema for deleting a message"""
    message_id: str
    delete_for_everyone: bool = False

