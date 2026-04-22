from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.schemas.schemas import OTPRequest, OTPVerify, TokenResponse
from app.models.user import User
from app.core.security import create_access_token

router = APIRouter()

# Hardcoded OTP for testing purposes (no paid SMS gateway available)
HARDCODED_OTP = "555555"

# In-memory OTP store (replaces Redis for now)
_otp_store: dict = {}

@router.post("/send-otp")
def send_otp(req: OTPRequest, db: Session = Depends(get_db)):
    """Send OTP to phone number. OTP is hardcoded for testing (no SMS gateway)."""
    _otp_store[req.phone] = HARDCODED_OTP  # TODO: replace with Redis + SMS gateway in production
    return {"message": "OTP sent", "dev_otp": HARDCODED_OTP}

@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(req: OTPVerify, db: Session = Depends(get_db)):
    """Verify OTP and return JWT token. Creates user if first time."""
    stored = _otp_store.get(req.phone)
    if not stored or stored != req.otp:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")

    del _otp_store[req.phone]

    user = db.query(User).filter(User.phone == req.phone).first()
    if not user:
        user = User(phone=req.phone, name="New User", is_phone_verified=True)
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token({"sub": str(user.id)})
    return {"access_token": token, "token_type": "bearer"}

@router.post("/refresh", response_model=TokenResponse)
def refresh_token():
    """Refresh access token"""
    token = create_access_token({"sub": "user_id"})
    return {"access_token": token}
