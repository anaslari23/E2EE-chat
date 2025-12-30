from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import DeviceLinking, User
from pydantic import BaseModel
from typing import Optional
import secrets
import string

router = APIRouter()


class LinkingRequest(BaseModel):
    ephemeral_public_key: str


class ApprovalData(BaseModel):
    provisioning_data: str


@router.post("/linking/request")
async def create_linking_request(
    req: LinkingRequest, db: AsyncSession = Depends(get_session)
):
    code = "".join(
        secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8)
    )
    new_link = DeviceLinking(
        linking_code=code,
        ephemeral_public_key=req.ephemeral_public_key,
        status="pending",
    )
    db.add(new_link)
    await db.commit()
    return {"linking_code": code}


@router.get("/linking/{code}")
async def get_linking_status(code: str, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(DeviceLinking).where(DeviceLinking.linking_code == code)
    )
    link = result.scalar_one_or_none()
    if not link:
        raise HTTPException(status_code=404, detail="Linking session not found")

    return {
        "status": link.status,
        "provisioning_data": link.provisioning_data,
        "ephemeral_public_key": link.ephemeral_public_key,
    }


from app.core.security import verify_token
from fastapi import Query


@router.post("/linking/{code}/approve")
async def approve_linking_request(
    code: str,
    data: ApprovalData,
    token: str = Query(...),
    db: AsyncSession = Depends(get_session),
):
    user_id = verify_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    result = await db.execute(
        select(DeviceLinking).where(DeviceLinking.linking_code == code)
    )
    link = result.scalar_one_or_none()
    if not link:
        raise HTTPException(status_code=404, detail="Linking session not found")

    link.user_id = user_id
    link.provisioning_data = data.provisioning_data
    link.status = "approved"
    db.add(link)
    await db.commit()
    return {"message": "Linking approved"}
