import asyncio
import hashlib
from datetime import datetime
from sqlmodel import select, SQLModel
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import engine
from app.models.models import User, Device, Group, GroupMember


async def reset_db():
    print("🗑️  Resetting Database...")
    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.drop_all)
        await conn.run_sync(SQLModel.metadata.create_all)
    print("✨ Database Reset Complete.")


async def seed():
    await reset_db()

    print("🌱 Seeding Mock Data...")

    # Static list of mock users
    mock_users = [
        {"phone": "1111111111", "name": "Alice (Mock)", "device_id": 1},
        {"phone": "2222222222", "name": "Bob (Mock)", "device_id": 1},
        {"phone": "3333333333", "name": "Charlie (Mock)", "device_id": 1},
        {"phone": "4444444444", "name": "Dave (Mock)", "device_id": 1},
    ]

    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        for data in mock_users:
            print(f"Checking user: {data['name']}")
            # Check if user exists
            stmt = select(User).where(User.phone_number == data["phone"])
            result = await session.execute(stmt)
            existing = result.scalars().first()

            if not existing:
                print(f"Creating user: {data['name']}")
                user = User(
                    phone_number=data["phone"],
                    username=data["name"],
                    phone_hash=hashlib.sha256(data["phone"].encode()).hexdigest(),
                    is_profile_complete=True,
                    is_online=True,
                    last_seen=datetime.utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)

                # Create Device
                device = Device(
                    user_id=user.id,
                    device_id=data["device_id"],
                    device_name="Mock Device",
                )
                session.add(device)
                await session.commit()
            else:
                print(f"User already exists: {data['name']}")

        # Create a Mock Group
        group_name = "Mock Community"
        stmt = select(Group).where(Group.name == group_name)
        result = await session.execute(stmt)
        existing_group = result.scalars().first()

        if not existing_group:
            print(f"Creating Group: {group_name}")
            # Get Alice as creator
            result = await session.execute(
                select(User).where(User.phone_number == "1111111111")
            )
            alice = result.scalars().first()

            if alice:
                group = Group(
                    name=group_name,
                    description="A place for mock testing",
                    creator_id=alice.id,
                )
                session.add(group)
                await session.commit()
                await session.refresh(group)

                # Add all users
                result = await session.execute(select(User))
                users = result.scalars().all()
                for user in users:
                    member = GroupMember(
                        group_id=group.id,
                        user_id=user.id,
                        role="admin" if user.id == alice.id else "member",
                    )
                    session.add(member)
                await session.commit()

    print("✅ Seeding Complete!")


if __name__ == "__main__":
    asyncio.run(seed())
