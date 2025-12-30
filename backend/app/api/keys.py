from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import Device
from pydantic import BaseModel
import json

router = APIRouter()


class BundleUpload(BaseModel):
    user_id: int
    device_id: int
    bundle: dict


@router.post("/upload")
async def upload_bundle(data: BundleUpload, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(Device).where(
            Device.user_id == data.user_id, Device.device_id == data.device_id
        )
    )
    device = result.scalar_one_or_none()

    if not device:
        # Create new device entry if not exists
        device = Device(
            user_id=data.user_id,
            device_id=data.device_id,
            prekey_bundle=json.dumps(data.bundle),
        )
        db.add(device)
    else:
        device.prekey_bundle = json.dumps(data.bundle)
        db.add(device)

    await db.commit()
    return {"message": "Bundle uploaded successfully"}


@router.get("/{user_id}")
async def get_bundles(user_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(select(Device).where(Device.user_id == user_id))
    devices = result.scalars().all()
    if not devices:
        raise HTTPException(status_code=404, detail="No bundles found for user")

    return [
        {"device_id": d.device_id, "bundle": json.loads(d.prekey_bundle)}
        for d in devices
        if d.prekey_bundle
    ]


@router.delete("/{user_id}/{device_id}")
async def revoke_device(
    user_id: int, device_id: int, db: AsyncSession = Depends(get_session)
):
    result = await db.execute(
        select(Device).where(Device.user_id == user_id, Device.device_id == device_id)
    )
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    await db.delete(device)
    await db.commit()
    return {"message": "Device revoked successfully"}
