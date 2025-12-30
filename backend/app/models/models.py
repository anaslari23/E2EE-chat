from datetime import datetime
from typing import Optional, List
from sqlmodel import Field, SQLModel, Relationship


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    phone_number: str = Field(index=True, unique=True)
    username: Optional[str] = Field(default=None, index=True)
    hashed_password: Optional[str] = Field(default=None)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class OTP(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    phone_number: str = Field(index=True)
    code: str
    expires_at: datetime
    created_at: datetime = Field(default_factory=datetime.utcnow)

    devices: list["Device"] = Relationship(back_populates="user")
    sent_messages: list["Message"] = Relationship(
        back_populates="sender",
        sa_relationship_kwargs={"foreign_keys": "[Message.sender_id]"},
    )
    received_messages: list["Message"] = Relationship(
        back_populates="recipient",
        sa_relationship_kwargs={"foreign_keys": "[Message.recipient_id]"},
    )


class Device(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    device_id: int  # Signal registration ID or persistent device ID
    device_name: str = Field(default="Primary Device")
    prekey_bundle: Optional[str] = Field(default=None)
    created_at: datetime = Field(default_factory=datetime.utcnow)

    user: User = Relationship(back_populates="devices")


class Message(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    sender_id: int = Field(foreign_key="user.id")
    recipient_id: int = Field(foreign_key="user.id")
    recipient_device_id: int  # Targeted device ID
    ciphertext: str  # Base64 encoded encrypted blob
    message_type: str = Field(default="message")  # e.g., "cipher", "prekey"
    status: str = Field(default="pending")  # pending, delivered, read
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    # Phase 12 Additions
    parent_id: Optional[int] = Field(default=None, foreign_key="message.id")
    is_edited: bool = Field(default=False)
    is_deleted: bool = Field(default=False)
    deleted_for_all: bool = Field(default=False)

    sender: User = Relationship(
        back_populates="sent_messages",
        sa_relationship_kwargs={"foreign_keys": "[Message.sender_id]"},
    )
    recipient: User = Relationship(
        back_populates="received_messages",
        sa_relationship_kwargs={"foreign_keys": "[Message.recipient_id]"},
    )

    reactions: List["Reaction"] = Relationship(back_populates="message")
    attachments: List["Attachment"] = Relationship(back_populates="message")


class Attachment(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    message_id: int = Field(foreign_key="message.id")
    file_path: str
    file_type: str  # image, video, voice, document
    file_size: int
    is_view_once: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)

    message: Message = Relationship(back_populates="attachments")


class Reaction(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    message_id: int = Field(foreign_key="message.id")
    user_id: int = Field(foreign_key="user.id")
    emoji: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

    message: Message = Relationship(back_populates="reactions")


class StarredMessage(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    message_id: int = Field(foreign_key="message.id")
    created_at: datetime = Field(default_factory=datetime.utcnow)


class ChatSettings(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    chat_id: str  # Can be user_id for 1:1 or group_id
    is_pinned: bool = Field(default=False)
    is_archived: bool = Field(default=False)
    mute_until: Optional[datetime] = Field(default=None)
    category: str = Field(default="personal")  # personal, unread, etc.
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class OneTimePreKey(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    device_id: int = Field(foreign_key="device.id")
    key_id: int  # Client-side 24-bit integer
    public_key: str  # Base64 encoded Curve25519 public key
    created_at: datetime = Field(default_factory=datetime.utcnow)
