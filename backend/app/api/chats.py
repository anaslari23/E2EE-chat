from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from pydantic import BaseModel
from sqlalchemy import func, desc, or_
from app.db.session import get_session
from app.models.models import ChatSettings, Message, User

router = APIRouter()


class MuteRequest(BaseModel):
    duration_minutes: Optional[int] = None


@router.post("/{chat_id}/pin")
async def toggle_pin_chat(
    chat_id: str,
    user_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(ChatSettings).where(
            ChatSettings.user_id == user_id, ChatSettings.chat_id == chat_id
        )
    )
    settings = result.scalar_one_or_none()

    if not settings:
        settings = ChatSettings(user_id=user_id, chat_id=chat_id, is_pinned=True)
        db.add(settings)
    else:
        settings.is_pinned = not settings.is_pinned
        db.add(settings)

    await db.commit()
    return {"status": "pinned" if settings.is_pinned else "unpinned"}


@router.post("/{chat_id}/archive")
async def toggle_archive_chat(
    chat_id: str,
    user_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(ChatSettings).where(
            ChatSettings.user_id == user_id, ChatSettings.chat_id == chat_id
        )
    )
    settings = result.scalar_one_or_none()

    if not settings:
        settings = ChatSettings(user_id=user_id, chat_id=chat_id, is_archived=True)
        db.add(settings)
    else:
        settings.is_archived = not settings.is_archived
        db.add(settings)

    await db.commit()
    return {"status": "archived" if settings.is_archived else "unarchived"}


@router.post("/{chat_id}/mute")
async def mute_chat(
    chat_id: str,
    mute_in: MuteRequest,
    user_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(ChatSettings).where(
            ChatSettings.user_id == user_id, ChatSettings.chat_id == chat_id
        )
    )
    settings = result.scalar_one_or_none()

    mute_until = None
    if mute_in.duration_minutes:
        now = datetime.utcnow()
        mute_until = now + timedelta(minutes=mute_in.duration_minutes)

    if not settings:
        settings = ChatSettings(user_id=user_id, chat_id=chat_id, mute_until=mute_until)
        db.add(settings)
    else:
        settings.mute_until = mute_until
        db.add(settings)

    await db.commit()
    return {
        "status": "muted" if mute_until else "unmuted",
        "until": mute_until.isoformat() if mute_until else None,
    }


@router.get("/conversations")
async def get_conversations(
    user_id: int = Query(...), db: AsyncSession = Depends(get_session)
):
    # Get last message for each unique contact
    msg_sender = Message.sender_id == user_id
    msg_recipient = Message.recipient_id == user_id

    case_stmt = func.case((msg_sender, Message.recipient_id), else_=Message.sender_id)

    subquery = (
        select(func.max(Message.id).label("max_id"))
        .where(or_(msg_sender, msg_recipient))
        .group_by(case_stmt)
    )

    result = await db.execute(
        select(Message)
        .where(Message.id.in_(subquery))
        .order_by(desc(Message.timestamp))
    )
    messages = result.scalars().all()

    conversations = []
    for msg in messages:
        target_id = msg.recipient_id if msg.sender_id == user_id else msg.sender_id

        contact_res = await db.execute(select(User).where(User.id == target_id))
        contact = contact_res.scalar_one_or_none()

        conversations.append(
            {
                "contact_id": target_id,
                "contact_name": contact.username if contact else f"U{target_id}",
                "last_message": msg.ciphertext,
                "timestamp": msg.timestamp.isoformat(),
                "unread_count": 0,
            }
        )

    return conversations


@router.get("/users")
async def get_users(db: AsyncSession = Depends(get_session)):
    result = await db.execute(select(User))
    users = result.scalars().all()
    return [
        {"id": u.id, "username": u.username, "phone": u.phone_number} for u in users
    ]


@router.get("/settings/{user_id}")
async def get_all_chat_settings(user_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(ChatSettings).where(ChatSettings.user_id == user_id)
    )
    settings = result.scalars().all()
    return settings
