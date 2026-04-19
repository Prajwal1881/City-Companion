from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    APP_NAME: str = "City Companion"
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    DATABASE_URL: str = "postgresql://postgres:password@localhost:5432/city_companion"
    REDIS_URL: str = "redis://localhost:6379"

    FIREBASE_CREDENTIALS_PATH: Optional[str] = None

    CLOUDINARY_CLOUD_NAME: Optional[str] = None
    CLOUDINARY_API_KEY: Optional[str] = None
    CLOUDINARY_API_SECRET: Optional[str] = None
    GOOGLE_PLACES_API_KEY: Optional[str] = None

    class Config:
        env_file = ".env"

settings = Settings()
