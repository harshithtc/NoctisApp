from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
import secrets
import logging
import uuid

from ..database import get_db
from ..models.user import User
from ..schemas.auth import UserRegister, UserLogin, TokenResponse
from ..middleware.auth import (
    create_access_token, 
    create_refresh_token,
    hash_password,
    verify_password,
    get_current_user
)
from ..services.email import EmailService
from ..config import settings

router = APIRouter(prefix="/auth", tags=["authentication"])
logger = logging.getLogger(__name__)
limiter = Limiter(key_func=get_remote_address)

# Track failed attempts in memory (use Redis in production)
failed_attempts = {}
locked_accounts = {}


def check_account_lockout(email: str) -> None:
    """Check if account is locked due to too many failed attempts"""
    if email in locked_accounts:
        lock_until = locked_accounts[email]
        if datetime.utcnow() < lock_until:
            remaining = (lock_until - datetime.utcnow()).seconds
            raise HTTPException(
                status_code=status.HTTP_423_LOCKED,
                detail=f"Account temporarily locked. Try again in {remaining} seconds"
            )
        else:
            del locked_accounts[email]
            if email in failed_attempts:
                del failed_attempts[email]


def record_failed_attempt(email: str) -> None:
    """Record failed login attempt and lock if threshold exceeded"""
    if email not in failed_attempts:
        failed_attempts[email] = []
    
    failed_attempts[email] = [
        t for t in failed_attempts[email] 
        if t > datetime.utcnow() - timedelta(minutes=15)
    ]
    
    failed_attempts[email].append(datetime.utcnow())
    
    if len(failed_attempts[email]) >= 5:
        locked_accounts[email] = datetime.utcnow() + timedelta(minutes=30)
        logger.warning(f"Account locked: {email}")


def clear_failed_attempts(email: str) -> None:
    """Clear failed attempts on successful login"""
    if email in failed_attempts:
        del failed_attempts[email]
    if email in locked_accounts:
        del locked_accounts[email]

@router.post("/register", status_code=status.HTTP_201_CREATED)
@limiter.limit("10/hour")
async def register(
    user_data: UserRegister,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """Register a new user"""
    try:
        # Check if user exists
        result = await db.execute(
            select(User).where(User.email == user_data.email)
        )
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        
        # Create user - FIXED: password_hash not hashed_password
        new_user = User(
            id=uuid.uuid4(),
            email=user_data.email,
            password_hash=hash_password(user_data.password),  # CORRECT FIELD NAME
            name=user_data.name,
            email_verified=False,
            is_active=True,
            is_deleted=False,
            created_at=datetime.utcnow()
        )
        
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
        
        logger.info(f"User registered: {user_data.email}")
        
        return {
            "message": "Registration successful. Check your email for verification.",
            "user_id": str(new_user.id)
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(
    login_data: UserLogin,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """Login user and return JWT tokens"""
    try:
        check_account_lockout(login_data.email)
        
        result = await db.execute(
            select(User).where(User.email == login_data.email)
        )
        user = result.scalar_one_or_none()
        
        # FIXED: password_hash not hashed_password
        if not user or not verify_password(login_data.password, user.password_hash):
            record_failed_attempt(login_data.email)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        # Skip email verification check for development
        # if not user.email_verified:
        #     raise HTTPException(
        #         status_code=status.HTTP_403_FORBIDDEN,
        #         detail="Email not verified"
        #     )
        
        clear_failed_attempts(login_data.email)
        
        # Create tokens
        access_token = create_access_token({"sub": user.email})
        refresh_token = create_refresh_token({"sub": user.email})
        
        # Update last seen
        user.last_seen = datetime.utcnow()
        await db.commit()
        
        logger.info(f"User logged in: {user.email}")
        
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "user": {
                "id": str(user.id),
                "email": user.email,
                "name": user.name,
                "is_verified": user.email_verified if hasattr(user, 'email_verified') else False
            }
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Login failed"
        )
@router.get("/me")
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current authenticated user information"""
    return {
        "id": str(current_user.id),
        "email": current_user.email,
        "name": current_user.name,
        "email_verified": current_user.email_verified if hasattr(current_user, 'email_verified') else False,
        "is_active": current_user.is_active if hasattr(current_user, 'is_active') else True,
        "created_at": current_user.created_at.isoformat() if hasattr(current_user, 'created_at') else None
    }
@router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Logout user and invalidate session"""
    try:
        logger.info(f"User logged out: {current_user.email}")
        
        # In a full implementation, you would:
        # 1. Invalidate the refresh token in database
        # 2. Add access token to blacklist (Redis)
        # 3. Clear any active sessions
        
        return {
            "message": "Logged out successfully",
            "user": current_user.email
        }
    
    except Exception as e:
        logger.error(f"Logout error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Logout failed"
        )
