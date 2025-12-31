from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import Message, Reaction, StarredMessage
from typing import List
from pydantic import BaseModel

router = APIRouter()


class MessageEdit(BaseModel):
    ciphertext: str


class ReactionIn(BaseModel):
    emoji: str


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
        reactions_data = [
            {"user_id": r.user_id, "emoji": r.emoji} for r in msg.reactions
        ]
        response.append(
            {
                "message_id": msg.id,
                "sender_id": msg.sender_id,
                "ciphertext": msg.ciphertext,
                "message_type": msg.message_type,
                "timestamp": msg.timestamp.isoformat(),
                "parent_id": msg.parent_id,
                "is_edited": msg.is_edited,
                "is_deleted": msg.is_deleted,
                "deleted_for_all": msg.deleted_for_all,
                "reactions": reactions_data,
            }
        )
        # Mark as delivered
        msg.status = "delivered"
        db.add(msg)

    await db.commit()
    return response


@router.get("/history")
async def get_message_history(
    user_id: int = Query(...),
    contact_id: int = Query(...),
    limit: int = Query(50),
    db: AsyncSession = Depends(get_session),
):
    """Get message history between two users."""
    from sqlalchemy import or_, and_

    from sqlalchemy.orm import selectinload

    result = await db.execute(
        select(Message)
        .where(
            or_(
                and_(Message.sender_id == user_id, Message.recipient_id == contact_id),
                and_(Message.sender_id == contact_id, Message.recipient_id == user_id),
            ),
            Message.group_id.is_(None),
        )
        .options(selectinload(Message.reactions))
        .order_by(Message.timestamp.desc())
        .limit(limit)
    )
    messages = result.scalars().all()

    response = []
    for msg in messages:
        reactions_data = [
            {"user_id": r.user_id, "emoji": r.emoji} for r in msg.reactions
        ]
        response.append(
            {
                "message_id": msg.id,
                "sender_id": msg.sender_id,
                "recipient_id": msg.recipient_id,
                "ciphertext": msg.ciphertext,
                "message_type": msg.message_type,
                "timestamp": msg.timestamp.isoformat(),
                "status": msg.status,
                "parent_id": msg.parent_id,
                "is_edited": msg.is_edited,
                "is_deleted": msg.is_deleted,
                "deleted_for_all": msg.deleted_for_all,
                "reactions": reactions_data,
            }
        )

    # Return in chronological order (oldest first)
    return list(reversed(response))


@router.post("/{message_id}/edit")
async def edit_message(
    message_id: int, edit_in: MessageEdit, db: AsyncSession = Depends(get_session)
):
    result = await db.execute(select(Message).where(Message.id == message_id))
    msg = result.scalar_one_or_none()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")

    msg.ciphertext = edit_in.ciphertext
    msg.is_edited = True
    msg.status = "pending"  # Needs redelivery
    db.add(msg)
    await db.commit()
    return {"message": "Message edited successfully"}


@router.post("/{message_id}/delete")
async def delete_message(
    message_id: int, for_everyone: bool = False, db: AsyncSession = Depends(get_session)
):
    result = await db.execute(select(Message).where(Message.id == message_id))
    msg = result.scalar_one_or_none()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")

    if for_everyone:
        msg.is_deleted = True
        msg.deleted_for_all = True
        msg.ciphertext = ""  # Wipe content
        msg.status = "pending"  # Notify others
    else:
        msg.is_deleted = True

    db.add(msg)
    await db.commit()
    return {"message": "Message deleted successfully"}


@router.post("/{message_id}/react")
async def add_reaction(
    message_id: int,
    reaction_in: ReactionIn,
    user_id: int,  # Should come from auth dependency normally
    db: AsyncSession = Depends(get_session),
):
    # Check if reaction exists
    result = await db.execute(
        select(Reaction).where(
            Reaction.message_id == message_id, Reaction.user_id == user_id
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        existing.emoji = reaction_in.emoji
        db.add(existing)
    else:
        new_reaction = Reaction(
            message_id=message_id, user_id=user_id, emoji=reaction_in.emoji
        )
        db.add(new_reaction)
    await db.commit()
    return {"message": "Reaction updated"}


@router.post("/{message_id}/star")
async def toggle_star_message(
    message_id: int, user_id: int = Query(...), db: AsyncSession = Depends(get_session)
):
    result = await db.execute(
        select(StarredMessage).where(
            StarredMessage.message_id == message_id, StarredMessage.user_id == user_id
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        await db.delete(existing)
        await db.commit()
        return {"status": "unstarred"}

    star = StarredMessage(message_id=message_id, user_id=user_id)
    db.add(star)
    await db.commit()
    return {"status": "starred"}


@router.get("/starred/{user_id}")
async def get_starred_messages(user_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(Message).join(StarredMessage).where(StarredMessage.user_id == user_id)
    )
    messages = result.scalars().all()

    response = []
    for msg in messages:
        reactions_data = [
            {"user_id": r.user_id, "emoji": r.emoji} for r in msg.reactions
        ]
        response.append(
            {
                "message_id": msg.id,
                "sender_id": msg.sender_id,
                "ciphertext": msg.ciphertext,
                "message_type": msg.message_type,
                "timestamp": msg.timestamp.isoformat(),
                "parent_id": msg.parent_id,
                "is_edited": msg.is_edited,
                "is_deleted": msg.is_deleted,
                "deleted_for_all": msg.deleted_for_all,
                "reactions": reactions_data,
            }
        )
    return response
