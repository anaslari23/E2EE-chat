from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import Message
from typing import List

router = APIRouter()


@router.get("/pending/{device_id}", response_model=List[dict])
async def get_pending_messages(device_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(Message).where(
            Message.recipient_device_id == device_id, Message.status == "pending"
        )
    )
    messages = result.scalars().all()

    response = []
    for msg in messages:
        response.append(
            {
                "message_id": msg.id,
                "sender_id": msg.sender_id,
                "ciphertext": msg.ciphertext,
                "message_type": msg.message_type,
                "timestamp": msg.timestamp.isoformat(),
            }
        )
        # Mark as delivered
        msg.status = "delivered"
        db.add(msg)

    await db.commit()
    return response
