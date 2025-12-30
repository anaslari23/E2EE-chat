from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from app.db.session import get_session
from app.models.models import Attachment
import os
import uuid
import shutil

router = APIRouter()

# Local storage configuration
STORAGE_PATH = "data/media"
os.makedirs(STORAGE_PATH, exist_ok=True)


@router.post("/upload")
async def upload_media(
    message_id: int,
    file_type: str,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_session),
):
    # Generate unique filename
    file_extension = os.path.splitext(file.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    save_path = os.path.join(STORAGE_PATH, unique_filename)

    # Save encrypted blob
    try:
        with open(save_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")

    # Save metadata
    attachment = Attachment(
        message_id=message_id,
        file_path=save_path,
        file_type=file_type,
        file_size=os.path.getsize(save_path),
    )
    db.add(attachment)
    await db.commit()
    await db.refresh(attachment)

    return {
        "attachment_id": attachment.id,
        "file_name": file.filename,
        "size": attachment.file_size,
    }


@router.get("/download/{attachment_id}")
async def download_media(attachment_id: int, db: AsyncSession = Depends(get_session)):
    result = await db.execute(select(Attachment).where(Attachment.id == attachment_id))
    attachment = result.scalar_one_or_none()

    if not attachment:
        raise HTTPException(status_code=404, detail="Attachment not found")

    if not os.path.exists(attachment.file_path):
        raise HTTPException(status_code=404, detail="File missing on server")

    return FileResponse(
        path=attachment.file_path,
        media_type="application/octet-stream",
        filename=os.path.basename(attachment.file_path),
    )
