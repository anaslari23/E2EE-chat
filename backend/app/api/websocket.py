from typing import Dict
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_session
from app.models.models import Message
import json

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, WebSocket] = {}

    async shadow_connect(self, user_id: int, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[user_id] = websocket

    def disconnect(self, user_id: int):
        if user_id in self.active_connections:
            del self.active_connections[user_id]

    async send_personal_message(self, message: str, user_id: int):
        if user_id in self.active_connections:
            await self.active_connections[user_id].send_text(message)

manager = ConnectionManager()

@router.websocket("/ws/{user_id}")
async def websocket_endpoint(
    websocket: WebSocket, 
    user_id: int,
    db: AsyncSession = Depends(get_session)
):
    await manager.shadow_connect(user_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            recipient_id = message_data.get("recipient_id")
            content = message_data.get("content")
            
            if recipient_id and content:
                # Save to database
                db_message = Message(
                    sender_id=user_id,
                    recipient_id=recipient_id,
                    content=content
                )
                db.add(db_message)
                await db.commit()
                
                # Relay message
                relay_data = {
                    "sender_id": user_id,
                    "content": content,
                    "timestamp": db_message.timestamp.isoformat()
                }
                await manager.send_personal_message(
                    json.dumps(relay_data), 
                    recipient_id
                )
    except WebSocketDisconnect:
        manager.disconnect(user_id)
