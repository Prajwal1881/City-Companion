import os
import shutil
from fastapi import APIRouter, Depends, HTTPException, Query, File, UploadFile
from sqlalchemy.orm import Session
from typing import List, Optional
from app.db.database import get_db
from app.core.geo import bounding_box, haversine_km
from app.schemas.schemas import DeviceTokenIn, UserOut, UserUpdate, UserNearby
from app.models.user import User
from app.core.security import get_current_user
from app.core.push_notifications import register_device_token, unregister_device_token

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
_UPLOADS_DIR = os.path.join(_BASE_DIR, "uploads")
_PROFILE_DIR = os.path.join(_UPLOADS_DIR, "profile_images")
_ALLOWED_EXT = {"jpg", "jpeg", "png"}
_MAX_MB = 5

router = APIRouter()


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.put("/me", response_model=UserOut)
def update_me(data: UserUpdate, db: Session = Depends(get_db),
              current_user: User = Depends(get_current_user)):
    for field, value in data.dict(exclude_unset=True).items():
        setattr(current_user, field, value)
    current_user.is_profile_complete = True
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/me/photo")
async def upload_photo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ext = (file.filename or "").rsplit(".", 1)[-1].lower()
    if ext not in _ALLOWED_EXT:
        raise HTTPException(status_code=400, detail="Only JPG/JPEG/PNG allowed")
    content = await file.read()
    if len(content) > _MAX_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"Max file size is {_MAX_MB}MB")
    os.makedirs(_PROFILE_DIR, exist_ok=True)
    filename = f"user_{current_user.id}.{ext}"
    with open(os.path.join(_PROFILE_DIR, filename), "wb") as f:
        f.write(content)
    current_user.profile_photo = f"/uploads/profile_images/{filename}"
    db.commit()
    return {"profile_photo": current_user.profile_photo}

@router.delete("/me/photo")
def delete_photo(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.profile_photo:
        raise HTTPException(status_code=400, detail="No profile photo set")
    filepath = os.path.join(_UPLOADS_DIR, current_user.profile_photo.lstrip("/uploads/"))
    if os.path.exists(filepath):
        os.remove(filepath)
    current_user.profile_photo = None
    db.commit()
    return {"message": "Profile photo deleted"}

@router.post("/me/device-token")
def save_device_token(
    data: DeviceTokenIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    token = data.token.strip()
    if not token:
        raise HTTPException(status_code=400, detail="Device token is required")
    register_device_token(db, current_user.id, token)
    db.commit()
    return {"message": "Device token saved"}


@router.delete("/me/device-token")
def remove_device_token(
    data: DeviceTokenIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    token = data.token.strip()
    if not token:
        raise HTTPException(status_code=400, detail="Device token is required")
    unregister_device_token(db, current_user.id, token)
    db.commit()
    return {"message": "Device token removed"}

@router.get("/nearby", response_model=List[UserNearby])
def get_nearby_users(
    lat: float = Query(..., description="Your latitude"),
    lng: float = Query(..., description="Your longitude"),
    radius_km: float = Query(10, description="Search radius in km", le=30),
    limit: int = Query(50, ge=1, le=100),
    interest: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lat_min, lat_max, lng_min, lng_max = bounding_box(lat, lng, radius_km)

    users = db.query(User).filter(
        User.id != current_user.id,
        User.latitude.isnot(None),
        User.longitude.isnot(None),
        User.latitude.between(lat_min, lat_max),
        User.longitude.between(lng_min, lng_max),
    ).all()

    nearby = []
    for u in users:
        dist = haversine_km(lat, lng, u.latitude, u.longitude)
        if dist <= radius_km:
            nearby.append({**u.__dict__, "distance_km": round(dist, 1), "online": False, "interests": []})

    nearby.sort(key=lambda x: x["distance_km"])
    return nearby[:limit]

@router.get("/{user_id}", response_model=UserOut)
def get_user(user_id: str, db: Session = Depends(get_db),
             _: User = Depends(get_current_user)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.post("/{user_id}/connect")
def connect(user_id: str, db: Session = Depends(get_db),
            current_user: User = Depends(get_current_user)):
    target = db.query(User).filter(User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    # TODO: create connection request record
    return {"message": f"Connection request sent to {target.name}"}
