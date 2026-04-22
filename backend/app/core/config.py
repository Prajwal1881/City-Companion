from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    APP_NAME: str = "City Companion"
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    DATABASE_URL: str = "postgresql://postgres:password@localhost:5432/city_companion"
    REDIS_URL: Optional[str] = None  # Not required — Redis removed for now

    # Firebase — provide the entire credentials JSON as a single env var string
    FIREBASE_TYPE: Optional[str] = None
    FIREBASE_PROJECT_ID: Optional[str] = None
    FIREBASE_PRIVATE_KEY_ID: Optional[str] = None
    FIREBASE_PRIVATE_KEY: Optional[str] = None          # include \n chars as-is
    FIREBASE_CLIENT_EMAIL: Optional[str] = None
    FIREBASE_CLIENT_ID: Optional[str] = None
    FIREBASE_AUTH_URI: Optional[str] = None
    FIREBASE_TOKEN_URI: Optional[str] = None
    FIREBASE_AUTH_PROVIDER_X509_CERT_URL: Optional[str] = None
    FIREBASE_CLIENT_X509_CERT_URL: Optional[str] = None
    FIREBASE_UNIVERSE_DOMAIN: Optional[str] = "googleapis.com"

    CLOUDINARY_CLOUD_NAME: Optional[str] = None
    CLOUDINARY_API_KEY: Optional[str] = None
    CLOUDINARY_API_SECRET: Optional[str] = None
    GOOGLE_PLACES_API_KEY: Optional[str] = None

    class Config:
        env_file = ".env"

settings = Settings()


def get_firebase_credentials_dict() -> dict | None:
    """Build Firebase credentials dict from individual env vars.
    Returns None if Firebase is not configured.
    """
    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_PRIVATE_KEY:
        return None

    return {
        "type": settings.FIREBASE_TYPE or "service_account",
        "project_id": settings.FIREBASE_PROJECT_ID,
        "private_key_id": settings.FIREBASE_PRIVATE_KEY_ID,
        # Render escapes \n as literal \n in env vars — replace back
        "private_key": settings.FIREBASE_PRIVATE_KEY.replace("\\n", "\n"),
        "client_email": settings.FIREBASE_CLIENT_EMAIL,
        "client_id": settings.FIREBASE_CLIENT_ID,
        "auth_uri": settings.FIREBASE_AUTH_URI or "https://accounts.google.com/o/oauth2/auth",
        "token_uri": settings.FIREBASE_TOKEN_URI or "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": settings.FIREBASE_AUTH_PROVIDER_X509_CERT_URL or "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": settings.FIREBASE_CLIENT_X509_CERT_URL,
        "universe_domain": settings.FIREBASE_UNIVERSE_DOMAIN or "googleapis.com",
    }
