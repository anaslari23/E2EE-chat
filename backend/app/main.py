from fastapi import FastAPI
from app.api import auth, websocket, keys, messages
from app.db.session import init_db
from app.core.config import settings

from app.core.limiter import limiter
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.logging import setup_logging

app = FastAPI(title=settings.PROJECT_NAME)
setup_logging()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.on_event("startup")
async def startup_event():
    await init_db()


app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(keys.router, prefix=f"{settings.API_V1_STR}/keys", tags=["keys"])
app.include_router(
    messages.router, prefix=f"{settings.API_V1_STR}/messages", tags=["messages"]
)
app.include_router(websocket.router, tags=["websocket"])


@app.get("/")
async def root():
    return {"message": "Welcome to the Secure Chat API"}
