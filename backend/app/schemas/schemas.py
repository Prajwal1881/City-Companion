from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from uuid import UUID

# ── AUTH ──────────────────────────────────────────────────────────────────

class OTPRequest(BaseModel):
    phone: str

class OTPVerify(BaseModel):
    phone: str
    otp: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

# ── USER ──────────────────────────────────────────────────────────────────

class UserBase(BaseModel):
    name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    bio: Optional[str] = None
    profession: Optional[str] = None
    current_city: Optional[str] = None
    hometown: Optional[str] = None
    interests: Optional[List[str]] = []
    languages: Optional[List[str]] = []

class UserCreate(UserBase):
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    firebase_uid: Optional[str] = None

class UserUpdate(UserBase):
    pass


class DeviceTokenIn(BaseModel):
    token: str

class UserOut(UserBase):
    id: UUID
    profile_photo: Optional[str]
    trust_score: float
    is_phone_verified: bool
    is_id_verified: bool
    is_profile_complete: bool
    created_at: datetime
    class Config:
        from_attributes = True

class UserNearby(BaseModel):
    id: UUID
    name: str
    profession: Optional[str]
    current_city: Optional[str]
    hometown: Optional[str]
    interests: List[str] = []
    profile_photo: Optional[str]
    trust_score: float
    is_phone_verified: bool
    is_profile_complete: bool
    distance_km: Optional[float]
    online: bool = False
    class Config:
        from_attributes = True

# ── PLAN ──────────────────────────────────────────────────────────────────

class PlanCreate(BaseModel):
    category: str
    title: str
    description: Optional[str] = None
    location: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    plan_date: datetime
    max_members: int = 10

class PlanMemberOut(BaseModel):
    id: UUID
    name: str
    profile_photo: Optional[str] = None
    profession: Optional[str] = None
    class Config:
        from_attributes = True

class PlanOut(BaseModel):
    id: UUID
    host_id: UUID
    host_name: str
    category: str
    title: str
    description: Optional[str]
    location: Optional[str]
    plan_date: datetime
    max_members: int
    joined_count: int
    is_active: bool
    created_at: datetime
    has_joined: bool = False
    is_host: bool = False
    conversation_id: Optional[UUID] = None
    members: List[PlanMemberOut] = []
    class Config:
        from_attributes = True

class LocationAutocompleteSuggestion(BaseModel):
    place_id: str
    description: str
    lat: float
    lng: float

# ── ROOM ──────────────────────────────────────────────────────────────────

class RoomCreate(BaseModel):
    title: str
    description: Optional[str] = None
    area: str
    city: str
    rent_inr: int
    room_type: str = "shared"
    gender_pref: str = "any"
    is_furnished: bool = False
    smoking_allowed: bool = False
    available_from: Optional[datetime] = None

class RoomOut(RoomCreate):
    id: UUID
    owner_id: UUID
    owner_name: str
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True

# ── COMMUNITY ─────────────────────────────────────────────────────────────

class CommunityCreate(BaseModel):
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    city: Optional[str] = None
    emoji: Optional[str] = None

class CommunityOut(CommunityCreate):
    id: UUID
    creator_id: UUID
    member_count: int
    created_at: datetime
    class Config:
        from_attributes = True

# ── MESSAGE ───────────────────────────────────────────────────────────────

class MessageCreate(BaseModel):
    content: str
    msg_type: str = "text"

class MessageOut(BaseModel):
    id: UUID
    conversation_id: UUID
    sender_id: UUID
    sender_name: str
    content: str
    msg_type: str
    sent_at: datetime
    class Config:
        from_attributes = True

class ConversationOut(BaseModel):
    id: UUID
    type: str
    name: Optional[str]
    last_message: Optional[str]
    unread_count: int = 0
    can_delete: bool = False
    class Config:
        from_attributes = True


# ── NOTIFICATIONS ───────────────────────────────────────────────────────────

class NotificationOut(BaseModel):
    id: UUID
    title: str
    body: str
    type: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True
