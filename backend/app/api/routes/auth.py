from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.schemas.schemas import OTPRequest, OTPVerify, TokenResponse, UserCreate, UserOut
from app.models.user import User
from app.core.security import create_access_token, get_current_user
import random
from app.core.config import settings

router = APIRouter()

# Try to initialise Redis; if unavailable (e.g. Render free tier) fall back to None.
# NOTE: redis.from_url() only creates the client object — it does NOT connect yet.
# The actual TCP connection happens on the first command, so we can't detect
# "no Redis server" at import time. We therefore wrap every Redis call in
# try/except so a missing server never crashes the endpoint.
r = None
try:
    import redis as _redis_lib
    _r = _redis_lib.from_url(settings.REDIS_URL, decode_responses=True)
    # Ping to verify connectivity at startup (fails fast instead of on first request)
    _r.ping()
    r = _r
except Exception:
    r = None  # Redis unavailable — use hardcoded OTP fallback

# Hardcoded OTP for testing (kept intentionally)
HARDCODED_OTP = "555555"


@router.post("/send-otp")
def send_otp(req: OTPRequest, db: Session = Depends(get_db)):
    """Send OTP to phone number (hardcoded for dev/testing)."""
    otp = HARDCODED_OTP
    if r:
        try:
            r.setex(f"otp:{req.phone}", 300, otp)  # expires in 5 minutes
        except Exception:
            pass  # Redis down — hardcoded OTP still works
    return {"message": "OTP sent", "dev_otp": otp}


@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(req: OTPVerify, db: Session = Depends(get_db)):
    """Verify OTP and return JWT token. Creates user if first time."""
    if r:
        try:
            stored = r.get(f"otp:{req.phone}")
            if stored and stored == req.otp:
                r.delete(f"otp:{req.phone}")
            elif req.otp != HARDCODED_OTP:
                raise HTTPException(status_code=400, detail="Invalid or expired OTP")
        except HTTPException:
            raise
        except Exception:
            # Redis error — fall back to hardcoded OTP check
            if req.otp != HARDCODED_OTP:
                raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    else:
        if req.otp != HARDCODED_OTP:
            raise HTTPException(status_code=400, detail="Invalid or expired OTP")

    user = db.query(User).filter(User.phone == req.phone).first()
    if not user:
        user = User(phone=req.phone, name="New User", is_phone_verified=True)
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token({"sub": str(user.id)})
    return {"access_token": token, "token_type": "bearer"}


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(current_user: User = Depends(get_current_user)):
    """Refresh access token"""
    token = create_access_token({"sub": str(current_user.id)})
    return {"access_token": token, "token_type": "bearer"}
