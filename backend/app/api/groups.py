from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from pydantic import BaseModel
from app.db.session import get_session
from app.models.models import Group, GroupMember, User

router = APIRouter()


class GroupCreate(BaseModel):
    name: str
    description: Optional[str] = None
    avatar_url: Optional[str] = None
    members: List[int]  # List of user IDs to invite initially


class GroupResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    avatar_url: Optional[str]
    creator_id: int


@router.post("/", response_model=GroupResponse)
async def create_group(
    group_in: GroupCreate,
    creator_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    # 1. Create the group
    group = Group(
        name=group_in.name,
        description=group_in.description,
        avatar_url=group_in.avatar_url,
        creator_id=creator_id,
    )
    db.add(group)
    await db.commit()
    await db.refresh(group)

    # 2. Add creator as Admin
    creator_member = GroupMember(group_id=group.id, user_id=creator_id, role="admin")
    db.add(creator_member)

    # 3. Add initial members
    for user_id in group_in.members:
        if user_id == creator_id:
            continue
        member = GroupMember(group_id=group.id, user_id=user_id, role="member")
        db.add(member)

    await db.commit()
    return group


@router.get("/", response_model=List[GroupResponse])
async def list_user_groups(
    user_id: int = Query(...), db: AsyncSession = Depends(get_session)
):
    result = await db.execute(
        select(Group).join(GroupMember).where(GroupMember.user_id == user_id)
    )
    return result.scalars().all()


@router.post("/{group_id}/members")
async def add_group_member(
    group_id: int,
    user_id: int,
    admin_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    # Check if admin is actually an admin
    admin_check = await db.execute(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == admin_id,
            GroupMember.role == "admin",
        )
    )
    if not admin_check.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can add members",
        )

    # Check if already a member
    existing = await db.execute(
        select(GroupMember).where(
            GroupMember.group_id == group_id, GroupMember.user_id == user_id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already a member",
        )

    member = GroupMember(group_id=group_id, user_id=user_id, role="member")
    db.add(member)
    await db.commit()
    return {"message": "Member added successfully"}


@router.delete("/{group_id}/members/{user_id}")
async def remove_group_member(
    group_id: int,
    user_id: int,
    admin_id: int = Query(...),
    db: AsyncSession = Depends(get_session),
):
    # Check if admin is admin OR if user is leaving themselves
    if admin_id != user_id:
        admin_check = await db.execute(
            select(GroupMember).where(
                GroupMember.group_id == group_id,
                GroupMember.user_id == admin_id,
                GroupMember.role == "admin",
            )
        )
        if not admin_check.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admins can remove members",
            )

    result = await db.execute(
        select(GroupMember).where(
            GroupMember.group_id == group_id, GroupMember.user_id == user_id
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Member not found"
        )

    await db.delete(member)
    await db.commit()
    return {"message": "Member removed successfully"}


@router.get("/{group_id}/members")
async def list_group_members(group_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(User, GroupMember.role)
        .join(GroupMember, User.id == GroupMember.user_id)
        .where(GroupMember.group_id == group_id)
    )
    members = []
    for user, role in result:
        members.append(
            {
                "id": user.id,
                "username": user.username,
                "phone": user.phone_number,
                "role": role,
            }
        )
    return members
