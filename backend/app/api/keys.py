from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import User
from pydantic import BaseModel
import json

router = APIRouter()


class BundleUpload(BaseModel):
    user_id: int
    bundle: dict


@router.post("/upload")
async def upload_bundle(data: BundleUpload, db: AsyncSession = Depends(get_session)):
    result = await db.execute(select(User).where(User.id == data.user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.prekey_bundle = json.dumps(data.bundle)
    db.add(user)
    await db.commit()
    return {"message": "Bundle uploaded successfully"}


@router.get("/{user_id}")
async def get_bundle(user_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.prekey_bundle:
        raise HTTPException(status_code=404, detail="Bundle not found")

    return json.loads(user.prekey_bundle)
