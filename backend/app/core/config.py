from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "Secure Chat"
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./sql_app.db"

    # Application Settings
    PROJECT_NAME: str = "Secure Chat"
    API_V1_STR: str = "/api/v1"
    DEVELOPMENT_MODE: bool = True


settings = Settings()
