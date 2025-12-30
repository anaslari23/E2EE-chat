from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from pydantic import BaseModel
from sqlalchemy import func, desc, or_, case
from app.db.session import get_session
from app.models.models import ChatSettings, Message, User, Group, GroupMember

router = APIRouter()


class MuteRequest(BaseModel):
    duration_minutes: Optional[int] = None


class ContactSyncRequest(BaseModel):
    phone_hashes: List[str]


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

    case_stmt = case([(msg_sender, Message.recipient_id)], else_=Message.sender_id)

    subquery = (
        select(func.max(Message.id).label("max_id"))
        .where(or_(msg_sender, msg_recipient))
        .where(Message.group_id.is_(None))
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
                "id": f"u{target_id}",
                "type": "personal",
                "contact_id": target_id,
                "contact_name": (contact.username if contact else f"U{target_id}"),
                "last_message": msg.ciphertext,
                "timestamp": msg.timestamp.isoformat(),
                "unread_count": 0,
            }
        )

    # Add Group Conversations
    group_member_res = await db.execute(
        select(Group).join(GroupMember).where(GroupMember.user_id == user_id)
    )
    groups = group_member_res.scalars().all()

    for g in groups:
        # Get last message for group
        last_msg_res = await db.execute(
            select(Message)
            .where(Message.group_id == g.id)
            .order_by(desc(Message.timestamp))
            .limit(1)
        )
        last_msg = last_msg_res.scalar_one_or_none()

        conversations.append(
            {
                "id": f"g{g.id}",
                "type": "group",
                "group_id": g.id,
                "contact_name": g.name,
                "last_message": (last_msg.ciphertext if last_msg else "Room created"),
                "timestamp": (
                    last_msg.timestamp.isoformat()
                    if last_msg
                    else g.created_at.isoformat()
                ),
                "unread_count": 0,
            }
        )

    # Final sort
    conversations.sort(key=lambda x: x["timestamp"], reverse=True)

    return conversations


@router.post("/sync-contacts")
async def sync_contacts(
    sync_in: ContactSyncRequest, db: AsyncSession = Depends(get_session)
):
    # Find users whose phone_hash is in the uploaded list
    result = await db.execute(
        select(User).where(User.phone_hash.in_(sync_in.phone_hashes))
    )
    users = result.scalars().all()

    return [
        {"id": u.id, "username": u.username, "phone": u.phone_number} for u in users
    ]


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
