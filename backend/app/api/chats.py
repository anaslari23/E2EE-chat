from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import ChatSettings
from datetime import datetime, timedelta
from typing import Optional
from pydantic import BaseModel

router = APIRouter()


class MuteIn(BaseModel):
    duration_minutes: Optional[int] = None  # None means unmute


@router.post("/{chat_id}/pin")
async def toggle_pin_chat(
    chat_id: str,
    user_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(ChatSettings).where(
            ChatSettings.chat_id == chat_id, ChatSettings.user_id == user_id
        )
    )
    settings = result.scalar_one_or_none()

    if not settings:
        settings = ChatSettings(chat_id=chat_id, user_id=user_id, is_pinned=True)
        db.add(settings)
    else:
        settings.is_pinned = not settings.is_pinned
        settings.updated_at = datetime.utcnow()
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
            ChatSettings.chat_id == chat_id, ChatSettings.user_id == user_id
        )
    )
    settings = result.scalar_one_or_none()

    if not settings:
        settings = ChatSettings(chat_id=chat_id, user_id=user_id, is_archived=True)
        db.add(settings)
    else:
        settings.is_archived = not settings.is_archived
        settings.updated_at = datetime.utcnow()
        db.add(settings)

    await db.commit()
    return {"status": "archived" if settings.is_archived else "unarchived"}


@router.post("/{chat_id}/mute")
async def mute_chat(
    chat_id: str,
    mute_in: MuteIn,
    user_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(ChatSettings).where(
            ChatSettings.chat_id == chat_id, ChatSettings.user_id == user_id
        )
    )
    settings = result.scalar_one_or_none()

    mute_until = None
    if mute_in.duration_minutes is not None:
        mute_until = datetime.utcnow() + timedelta(minutes=mute_in.duration_minutes)

    if not settings:
        settings = ChatSettings(chat_id=chat_id, user_id=user_id, mute_until=mute_until)
        db.add(settings)
    else:
        settings.mute_until = mute_until
        settings.updated_at = datetime.utcnow()
        db.add(settings)

    await db.commit()
    return {
        "status": "muted" if mute_until else "unmuted",
        "until": mute_until.isoformat() if mute_until else None,
    }


@router.get("/settings/{user_id}")
async def get_all_chat_settings(user_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(ChatSettings).where(ChatSettings.user_id == user_id)
    )
    settings = result.scalars().all()
    return settings
