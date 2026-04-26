from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.schemas.schemas import OTPRequest, OTPVerify, TokenResponse, UserCreate, UserOut
from app.models.user import User
from app.core.security import create_access_token
import random
from app.core.config import settings

router = APIRouter()

# Try to connect to Redis, fallback to dummy if not configured (though config.py has it)
try:
    import redis
    r = redis.from_url(settings.REDIS_URL, decode_responses=True)
except ImportError:
    r = None
except Exception:
    r = None

# Hardcoded OTP for testing
HARDCODED_OTP = "555555"

@router.post("/send-otp")
def send_otp(req: OTPRequest, db: Session = Depends(get_db)):
    """Send OTP to phone number (in production, use Firebase or SMS gateway)"""
    otp = HARDCODED_OTP
    if r:
        r.setex(f"otp:{req.phone}", 300, otp)   # expires in 5 minutes
    # For development: return OTP directly
    return {"message": "OTP sent", "dev_otp": otp}

@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(req: OTPVerify, db: Session = Depends(get_db)):
    """Verify OTP and return JWT token. Creates user if first time."""
    if r:
        stored = r.get(f"otp:{req.phone}")
        if not stored or stored != req.otp:
            # Fallback to check if it's the hardcoded one if redis missed it
            if req.otp != HARDCODED_OTP:
                raise HTTPException(status_code=400, detail="Invalid or expired OTP")
        r.delete(f"otp:{req.phone}")
    else:
        # Fallback if no redis
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
def refresh_token(current_user: User = Depends(lambda: None)):
    """Refresh access token"""
    token = create_access_token({"sub": "user_id"})
    return {"access_token": token}
