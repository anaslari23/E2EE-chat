from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import Device, OneTimePreKey
from pydantic import BaseModel
from typing import List, Optional
import json

router = APIRouter()


class OTPKIn(BaseModel):
    key_id: int
    public_key: str


class BundleUpload(BaseModel):
    user_id: int
    device_id: int
    bundle: dict  # IdentityKey, SignedPreKey, Signature
    otpk_pool: Optional[List[OTPKIn]] = None


@router.post("/upload")
async def upload_bundle(data: BundleUpload, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(Device).where(
            Device.user_id == data.user_id, Device.device_id == data.device_id
        )
    )
    device = result.scalar_one_or_none()

    if not device:
        device = Device(
            user_id=data.user_id,
            device_id=data.device_id,
            prekey_bundle=json.dumps(data.bundle),
        )
        db.add(device)
    else:
        device.prekey_bundle = json.dumps(data.bundle)
        db.add(device)

    # Flush to get device.id if new
    await db.flush()

    if data.otpk_pool:
        for otpk in data.otpk_pool:
            db_otpk = OneTimePreKey(
                device_id=device.id, key_id=otpk.key_id, public_key=otpk.public_key
            )
            db.add(db_otpk)

    await db.commit()
    return {"message": "Bundle and OTPKs uploaded successfully"}


@router.get("/{user_id}")
async def get_bundles(user_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(select(Device).where(Device.user_id == user_id))
    devices = result.scalars().all()
    if not devices:
        raise HTTPException(status_code=404, detail="No bundles found for user")

    bundle_list = []
    for d in devices:
        if not d.prekey_bundle:
            continue

        # Try to get ONE one-time prekey
        otpk_result = await db.execute(
            select(OneTimePreKey).where(OneTimePreKey.device_id == d.id).limit(1)
        )
        otpk = otpk_result.scalar_one_or_none()

        otpk_data = None
        if otpk:
            otpk_data = {"key_id": otpk.key_id, "public_key": otpk.public_key}
            # DELETE the key as it is being served (One-Time)
            await db.delete(otpk)

        bundle_list.append(
            {
                "device_id": d.device_id,
                "bundle": json.loads(d.prekey_bundle),
                "one_time_prekey": otpk_data,
            }
        )

    await db.commit()
    return bundle_list


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
