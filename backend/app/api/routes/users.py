from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from math import radians, cos, sin, asin, sqrt
from app.db.database import get_db, get_redis
from app.schemas.schemas import DeviceTokenIn, UserOut, UserUpdate, UserNearby
from app.models.user import User
from app.core.security import get_current_user
from app.core.push_notifications import register_device_token, unregister_device_token

router = APIRouter()

def haversine(lat1, lon1, lat2, lon2):
    R = 6371
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1)*cos(lat2)*sin(dlon/2)**2
    return 2 * R * asin(sqrt(a))

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

@router.post("/me/test-push")
def test_push_notification(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from app.core.push_notifications import send_test_notification
    result = send_test_notification(db, current_user.id)
    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("error", "Unknown error"))
    return result

@router.get("/{user_id}", response_model=UserOut)
def get_user(user_id: str, db: Session = Depends(get_db),
             _: User = Depends(get_current_user)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.get("/nearby", response_model=List[UserNearby])
def get_nearby_users(
    lat: float = Query(..., description="Your latitude"),
    lng: float = Query(..., description="Your longitude"),
    radius_km: float = Query(10, description="Search radius in km"),
    interest: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    users = db.query(User).filter(
        User.id != current_user.id,
        User.latitude.isnot(None),
        User.longitude.isnot(None),
    ).all()

    nearby = []
    for u in users:
        dist = haversine(lat, lng, u.latitude, u.longitude)
        if dist <= radius_km:
            nearby.append({**u.__dict__, "distance_km": round(dist, 1), "online": False, "interests": []})

    nearby.sort(key=lambda x: x["distance_km"])
    return nearby[:50]

@router.post("/{user_id}/connect")
def connect(user_id: str, db: Session = Depends(get_db),
            current_user: User = Depends(get_current_user)):
    target = db.query(User).filter(User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    # TODO: create connection request record
    return {"message": f"Connection request sent to {target.name}"}

PRESENCE_TTL = 60  # 60 seconds

@router.post("/me/heartbeat")
async def send_heartbeat(current_user: User = Depends(get_current_user), redis=Depends(get_redis)):
    """
    Called by the client every 30 seconds.
    Sets a Redis key that auto-expires after 60 seconds if not refreshed.
    """
    key = f"user:{current_user.id}:online"
    # Set key to "1" and set expiration (TTL)
    await redis.setex(key, PRESENCE_TTL, "1")
    
    # Optionally update last_seen_at in DB for long-term historical presence (do this async or less frequently to save DB load)
    return {"status": "active"}

@router.post("/batch-online")
async def get_batch_online_status(user_ids: list[str], redis=Depends(get_redis)):
    """
    Returns the online status for a list of users (useful for ChatListScreen and DiscoverScreen).
    """
    keys = [f"user:{uid}:online" for uid in user_ids]
    # Fetch all keys in a single Redis call for high performance
    values = await redis.mget(keys)
    
    status_map = {}
    for uid, val in zip(user_ids, values):
        status_map[uid] = val == b"1" or val == "1"
        
    return status_map