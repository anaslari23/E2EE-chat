import random
import logging
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from pydantic import BaseModel
from app.db.session import get_session
from app.models.models import User, OTP
from app.core.security import create_access_token
from app.core.limiter import limiter

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


@router.post("/request-otp")
@limiter.limit("5/minute")
async def request_otp(
    request: Request, otp_in: OTPRequest, db: AsyncSession = Depends(get_session)
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
    request: Request, otp_in: OTPVerify, db: AsyncSession = Depends(get_session)
):
    # Check if OTP exists and is valid
    result = await db.execute(
        select(OTP)
        .where(
            OTP.phone_number == otp_in.phone_number,
            OTP.code == otp_in.code,
            OTP.expires_at > datetime.utcnow(),
        )
        .order_by(OTP.created_at.desc())
    )
    otp_record = result.scalars().first()

    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP"
        )

    # Check if user exists, if not create them (Auto-registration)
    result = await db.execute(
        select(User).where(User.phone_number == otp_in.phone_number)
    )
    user = result.scalar_one_or_none()

    if not user:
        user = User(
            phone_number=otp_in.phone_number,
            username=f"User_{otp_in.phone_number[-4:]}",
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    # Delete the OTP after successful verification
    await db.delete(otp_record)
    await db.commit()

    access_token = create_access_token(subject=user.id)

    return {
        "id": user.id,
        "username": user.username,
        "phone_number": user.phone_number,
        "access_token": access_token,
        "token_type": "bearer",
    }
