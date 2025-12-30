from typing import Dict
from fastapi import (
    APIRouter,
    WebSocket,
    WebSocketDisconnect,
    Depends,
    Query,
    HTTPException,
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import Message, Device
from app.core.security import verify_token
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
            await self.active_connections[(user_id, device_id)].send_text(message)

    async def fan_out_message(self, message: str, recipient_id: int):
        # Send message to all devices of the recipient
        for (u_id, d_id), ds in self.active_connections.items():
            if u_id == recipient_id:
                await ds.send_text(message)


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
    try:
        while True:
            data = await websocket.receive_text()

            # Security: Size limit for incoming JSON (e.g. 1MB)
            if len(data) > 1024 * 1024:
                await websocket.close(code=1009)
                break

            message_data = json.loads(data)

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
                    # Save to database (one for each device)
                    db_message = Message(
                        sender_id=user_id,
                        recipient_id=recipient_id,
                        recipient_device_id=d_id,
                        ciphertext=ciphertext,
                        message_type=message_type,
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
                    }

                    if (recipient_id, d_id) in manager.active_connections:
                        await manager.send_personal_message(
                            json.dumps(relay_data), recipient_id, d_id
                        )
                        db_message.status = "delivered"
                        db.add(db_message)
                        await db.commit()

                # Send acknowledgment back to sender's CURRENT device
                ack_data = {
                    "type": "ack",
                    "status": "sent_to_relay",
                }
                await manager.send_personal_message(
                    json.dumps(ack_data), user_id, device_id
                )
    except WebSocketDisconnect:
        manager.disconnect(user_id, device_id)
