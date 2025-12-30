import random
import logging
import hashlib
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from pydantic import BaseModel
from app.db.session import get_session
from app.models.models import User, OTP
from app.core.security import create_access_token
from app.core.limiter import limiter

from app.core.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


class OTPRequest(BaseModel):
    phone_number: str


class OTPVerify(BaseModel):
    phone_number: str
    code: str


class UserResponse(BaseModel):
    id: int
    username: Optional[str] = None
    phone_number: str
    access_token: str
    token_type: str
    needs_setup: bool


@router.post("/request-otp")
# @limiter.limit("5/minute")
async def request_otp(
    request: Request,
    otp_in: OTPRequest,
    db: AsyncSession = Depends(get_session),
):
    # Generate a random 6-digit OTP
    code = f"{random.randint(100000, 999999)}"
    expires_at = datetime.utcnow() + timedelta(minutes=5)

    # In a real app, send this via SMS (Twilio etc.)
    # For now, we log it to simulate delivery
    logger.info(f"--- [OTP for {otp_in.phone_number}]: {code} ---")
    print(f"\n\n--- [OTP for {otp_in.phone_number}]: {code} ---\n\n")

    db_otp = OTP(phone_number=otp_in.phone_number, code=code, expires_at=expires_at)
    db.add(db_otp)
    await db.commit()

    return {"message": "OTP sent successfully"}


@router.post("/verify-otp", response_model=UserResponse)
@limiter.limit("10/minute")
async def verify_otp(
    request: Request,
    otp_in: OTPVerify,
    db: AsyncSession = Depends(get_session),
):
    # Check if OTP exists and is valid
    # Development Mode: Accept '000000' as a magic code
    is_magic_code = settings.DEVELOPMENT_MODE and otp_in.code == "000000"

    result = await db.execute(
        select(OTP)
        .where(
            OTP.phone_number == otp_in.phone_number,
            OTP.code == otp_in.code if not is_magic_code else True,
            OTP.expires_at > datetime.utcnow(),
        )
        .order_by(OTP.created_at.desc())
    )
    otp_record = result.scalars().first()

    if not otp_record and not is_magic_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP",
        )

    # Check if user exists, if not create them (Auto-registration)
    result = await db.execute(
        select(User).where(User.phone_number == otp_in.phone_number)
    )
    user = result.scalar_one_or_none()

    if not user:
        # Generate phone hash for discovery
        phone_hash = hashlib.sha256(otp_in.phone_number.encode()).hexdigest()
        user = User(
            phone_number=otp_in.phone_number,
            phone_hash=phone_hash,
            username=f"User_{otp_in.phone_number[-4:]}",
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    elif not user.phone_hash:
        user.phone_hash = hashlib.sha256(user.phone_number.encode()).hexdigest()
        db.add(user)
        await db.commit()

    # Delete the OTP after successful verification
    if otp_record:
        await db.delete(otp_record)
        await db.commit()

    access_token = create_access_token(subject=user.id)

    return {
        "id": user.id,
        "username": user.username,
        "phone_number": user.phone_number,
        "access_token": access_token,
        "token_type": "bearer",
        "needs_setup": not user.is_profile_complete,
    }


class ProfileUpdate(BaseModel):
    username: str


@router.post("/update-profile")
async def update_profile(
    profile_in: ProfileUpdate,
    user_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    # Check if username already exists
    exists_res = await db.execute(
        select(User).where(User.username == profile_in.username, User.id != user_id)
    )
    if exists_res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )

    user.username = profile_in.username
    user.is_profile_complete = True
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return {
        "id": user.id,
        "username": user.username,
        "is_profile_complete": user.is_profile_complete,
    }
