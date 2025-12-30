from fastapi import FastAPI
from app.api import auth, websocket
from app.db.session import init_db
from app.core.config import settings

app = FastAPI(title=settings.PROJECT_NAME)


@app.on_event("startup")
async def on_startup():
    await init_db()


app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(websocket.router, tags=["websocket"])


@app.get("/")
async def root():
    return {"message": "Welcome to the Secure Chat API"}
