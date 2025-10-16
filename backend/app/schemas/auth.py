from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional
from uuid import UUID
from datetime import datetime

class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    name: str = Field(..., min_length=2, max_length=100)
    website: Optional[str] = None  # Honeypot field for bot detection
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        if not any(c in '!@#$%^&*(),.?":{}|<>' for c in v):
            raise ValueError('Password must contain at least one special character')
        return v

    @validator('website')
    def check_honeypot(cls, v):
        if v:
            raise ValueError('Invalid registration')
        return v

class UserLogin(BaseModel):
    email: EmailStr
    password: str
    device_info: Optional[str] = None

class EmailVerifyRequest(BaseModel):
    user_id: UUID
    code: str = Field(..., min_length=6, max_length=6)

class OTPRequest(BaseModel):
    email: EmailStr

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: dict

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class PasswordResetRequest(BaseModel):
    token: str
    new_password: str = Field(..., min_length=8)
    
    @validator('new_password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        if not any(c in '!@#$%^&*(),.?":{}|<>' for c in v):
            raise ValueError('Password must contain at least one special character')
        return v

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)
    
    @validator('new_password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        if not any(c in '!@#$%^&*(),.?":{}|<>' for c in v):
            raise ValueError('Password must contain at least one special character')
        return v

class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    name: str
    is_verified: bool
    created_at: datetime
    last_login: Optional[datetime] = None
    class Config:
        from_attributes = True  # For SQLAlchemy 2.0 models

class SessionResponse(BaseModel):
    id: UUID
    user_id: UUID
    device_info: str
    ip_address: str
    created_at: datetime
    last_active: datetime
    is_active: bool
    class Config:
        from_attributes = True

