from typing import Dict
from fastapi import (
    APIRouter,
    WebSocket,
    WebSocketDisconnect,
    Depends,
    Query,
)
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_session
from sqlmodel import select
from app.models.models import Message, GroupMember, Device
from app.core.security import verify_token
from app.services.notification_service import notification_service
from datetime import datetime, timedelta
import json

router = APIRouter()


class ConnectionManager:
    def __init__(self):
        # (user_id, device_id) -> WebSocket
        self.active_connections: Dict[tuple[int, int], WebSocket] = {}

    async def shadow_connect(self, user_id: int, device_id: int, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[(user_id, device_id)] = websocket

    def disconnect(self, user_id: int, device_id: int):
        if (user_id, device_id) in self.active_connections:
            del self.active_connections[(user_id, device_id)]

    async def send_personal_message(self, message: str, user_id: int, device_id: int):
        if (user_id, device_id) in self.active_connections:
            ws = self.active_connections[(user_id, device_id)]
            await ws.send_text(message)

    async def fan_out_message(self, message: str, recipient_id: int):
        # Send message to all devices of the recipient
        for (u_id, d_id), ds in self.active_connections.items():
            if u_id == recipient_id:
                try:
                    await ds.send_text(message)
                except Exception:
                    pass

    async def broadcast_to_contacts(
        self, user_id: int, message: str, contact_ids: list[int]
    ):
        for (u_id, d_id), ds in self.active_connections.items():
            if u_id in contact_ids:
                try:
                    await ds.send_text(message)
                except Exception:
                    pass

    async def trigger_notification(
        self,
        db: AsyncSession,
        recipient_id: int,
        device_id: int,
        sender_id: int,
        group_id: int = None,
    ):
        # Only notify if the specific device is OFFLINE
        if (recipient_id, device_id) not in self.active_connections:
            # Fetch push token for this device
            result = await db.execute(
                select(Device.push_token).where(
                    Device.user_id == recipient_id,
                    Device.device_id == device_id,
                )
            )
            push_token = result.scalar_one_or_none()
            if push_token:
                await notification_service.send_new_message_notification(
                    push_token, sender_id, group_id
                )


manager = ConnectionManager()


@router.websocket("/ws/{user_id}/{device_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    user_id: int,
    device_id: int,
    token: str = Query(...),
    db: AsyncSession = Depends(get_session),
):
    # Security: Authenticate the connection
    authed_user_id = verify_token(token)
    if not authed_user_id or authed_user_id != user_id:
        await websocket.accept()
        await websocket.close(code=4003)  # Forbidden
        return

    await manager.shadow_connect(user_id, device_id, websocket)

    # Update presence: Online
    from app.models.models import User

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user:
        user.is_online = True
        db.add(user)
        await db.commit()
        # In a real app, broadcast online status to contacts

    try:
        while True:
            data = await websocket.receive_text()

            # Security: Size limit for incoming JSON (e.g. 1MB)
            if len(data) > 1024 * 1024:
                await websocket.close(code=1009)
                break

            message_data = json.loads(data)
            m_type = message_data.get("type")

            # Presence / Typing / Status Signals
            if m_type in ["typing", "presence", "message_status"]:
                recipient_id = message_data.get("recipient_id")
                recipient_group_id = message_data.get("recipient_group_id")

                relay_signal = {
                    "type": m_type,
                    "sender_id": user_id,
                    "data": message_data.get("data"),
                }
                if recipient_group_id:
                    relay_signal["group_id"] = recipient_group_id
                    # Get all members of the group
                    res = await db.execute(
                        select(GroupMember.user_id).where(
                            GroupMember.group_id == recipient_group_id
                        )
                    )
                    member_ids = [r[0] for r in res if r[0] != user_id]
                    for mid in member_ids:
                        await manager.fan_out_message(json.dumps(relay_signal), mid)
                elif recipient_id:
                    await manager.fan_out_message(
                        json.dumps(relay_signal), recipient_id
                    )

                # If it's a message_status update (Read/Delivered), persist it
                if m_type == "message_status":
                    status_data = message_data.get("data", {})
                    msg_id = status_data.get("message_id")
                    new_status = status_data.get("status")
                    if msg_id and new_status:
                        res = await db.execute(
                            select(Message).where(Message.id == msg_id)
                        )
                        msg = res.scalar_one_or_none()
                        if msg and msg.recipient_id == user_id:
                            msg.status = new_status
                            db.add(msg)
                            await db.commit()
                continue

            # Handle Signaling (WebRTC)
            if message_data.get("type") == "signaling":
                recipient_id = message_data.get("recipient_id")
                recipient_device_id = message_data.get("recipient_device_id")
                sig_data = message_data.get("data")

                if recipient_id and recipient_device_id and sig_data:
                    relay_sig = {
                        "type": "signaling",
                        "sender_id": user_id,
                        "sender_device_id": device_id,
                        "data": sig_data,
                    }
                    if (
                        recipient_id,
                        recipient_device_id,
                    ) in manager.active_connections:
                        await manager.send_personal_message(
                            json.dumps(relay_sig),
                            recipient_id,
                            recipient_device_id,
                        )
                continue

            recipient_id = message_data.get("recipient_id")
            # Map of device_id -> ciphertext
            ciphers = message_data.get("ciphers")
            message_type = message_data.get("message_type", "message")

            if recipient_id and ciphers:
                for d_id_str, ciphertext in ciphers.items():
                    # Security: Size limit per ciphertext (e.g. 512KB)
                    if len(ciphertext) > 512 * 1024:
                        continue

                    d_id = int(d_id_str)
                    expires_at = None
                    exp_duration = message_data.get("expiration_duration")
                    if exp_duration:
                        expires_at = datetime.utcnow() + timedelta(seconds=exp_duration)

                    # Save to database (one for each device)
                    db_message = Message(
                        sender_id=user_id,
                        recipient_id=recipient_id,
                        recipient_device_id=d_id,
                        ciphertext=ciphertext,
                        message_type=message_type,
                        expires_at=expires_at,
                    )
                    db.add(db_message)
                    await db.commit()

                    # Relay message to specific device
                    relay_data = {
                        "message_id": db_message.id,
                        "sender_id": user_id,
                        "ciphertext": ciphertext,
                        "message_type": message_type,
                        "timestamp": db_message.timestamp.isoformat(),
                        "expires_at": expires_at.isoformat() if expires_at else None,
                    }

                    if (recipient_id, d_id) in manager.active_connections:
                        await manager.send_personal_message(
                            json.dumps(relay_data), recipient_id, d_id
                        )
                        db_message.status = "delivered"
                        db.add(db_message)
                        await db.commit()
                    else:
                        # Device is offline, trigger push notification
                        await manager.trigger_notification(
                            db, recipient_id, d_id, user_id
                        )

                # Send acknowledgment back to sender's CURRENT device
                ack_data = {
                    "type": "ack",
                    "status": "sent_to_relay",
                }
                await manager.send_personal_message(
                    json.dumps(ack_data), user_id, device_id
                )
                continue

            recipient_group_id = message_data.get("recipient_group_id")
            if recipient_group_id:
                ciphertext = message_data.get("ciphertext")
                msg_type = message_data.get("message_type", "group_message")

                # Get all members of the group
                res = await db.execute(
                    select(GroupMember.user_id).where(
                        GroupMember.group_id == recipient_group_id
                    )
                )
                member_ids = [r[0] for r in res]

                for m_id in member_ids:
                    expires_at = None
                    exp_duration = message_data.get("expiration_duration")
                    if exp_duration:
                        expires_at = datetime.utcnow() + timedelta(seconds=exp_duration)

                    # Save for each member's primary logic
                    # In a real app, you'd handle per-device fanout here too
                    db_message = Message(
                        sender_id=user_id,
                        recipient_id=m_id,
                        recipient_device_id=0,  # Group wide/fanout
                        ciphertext=ciphertext,
                        message_type=msg_type,
                        group_id=recipient_group_id,
                        expires_at=expires_at,
                    )
                    db.add(db_message)
                    await db.commit()

                    relay_data = {
                        "message_id": db_message.id,
                        "sender_id": user_id,
                        "group_id": recipient_group_id,
                        "ciphertext": ciphertext,
                        "message_type": msg_type,
                        "timestamp": db_message.timestamp.isoformat(),
                        "expires_at": expires_at.isoformat() if expires_at else None,
                    }
                    if (m_id, 0) in manager.active_connections or any(
                        uid == m_id for (uid, _) in manager.active_connections
                    ):
                        await manager.fan_out_message(json.dumps(relay_data), m_id)
                    else:
                        # Notify offline member (using device ID 0)
                        await manager.trigger_notification(
                            db, m_id, 0, user_id, recipient_group_id
                        )

                # Ack
                await manager.send_personal_message(
                    json.dumps({"type": "ack", "status": "group_sent"}),
                    user_id,
                    device_id,
                )
    except WebSocketDisconnect:
        manager.disconnect(user_id, device_id)
        # Update presence: Offline
        # Only set offline if NO other devices are connected
        still_connected = any(
            uid == user_id for (uid, did) in manager.active_connections
        )
        if not still_connected:
            from app.models.models import User

            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            if user:
                user.is_online = False
                user.last_seen = datetime.utcnow()
                db.add(user)
                await db.commit()
                # Broadcast offline status to contacts
