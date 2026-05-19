import uuid
import time
from sqlalchemy import Column, String, Integer, Boolean, Float, Text, DateTime, ForeignKey, Table, BigInteger
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from datetime import datetime
from app.db.database import Base

# ── ROOMS ──────────────────────────────────────────────────────────────────

class Room(Base):
    __tablename__ = "rooms"

    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id       = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    title          = Column(String(200), nullable=False)
    description    = Column(Text, nullable=True)
    area           = Column(String(100), nullable=False)
    city           = Column(String(100), nullable=False)
    rent_inr       = Column(Integer, nullable=False)
    room_type      = Column(String(20), default="shared")   # private / shared / full_flat
    gender_pref    = Column(String(20), default="any")      # male / female / any
    is_furnished   = Column(Boolean, default=False)
    smoking_allowed = Column(Boolean, default=False)
    available_from = Column(DateTime, nullable=True)
    latitude       = Column(Float, nullable=True)
    longitude      = Column(Float, nullable=True)
    is_active      = Column(Boolean, default=True)
    created_at     = Column(DateTime, default=datetime.utcnow)
    updated_at     = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owner          = relationship("User", back_populates="rooms")
    images         = relationship("RoomImage", back_populates="room", cascade="all, delete-orphan")


# ── ROOM IMAGES ────────────────────────────────────────────────────────────

class RoomImage(Base):
    __tablename__ = "room_images"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    room_id    = Column(UUID(as_uuid=True), ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False, index=True)
    image_path = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    room = relationship("Room", back_populates="images")


# ── COMMUNITIES ────────────────────────────────────────────────────────────

class Community(Base):
    __tablename__ = "communities"

    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    creator_id     = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name           = Column(String(200), nullable=False)
    description    = Column(Text, nullable=True)
    category       = Column(String(50), nullable=True)   # regional / sports / professional
    city           = Column(String(100), nullable=True)
    emoji          = Column(String(10), nullable=True)
    member_count   = Column(Integer, default=1)
    is_public      = Column(Boolean, default=True)
    created_at     = Column(DateTime, default=datetime.utcnow)

    members        = relationship("CommunityMember", back_populates="community")


class CommunityMember(Base):
    __tablename__ = "community_members"

    community_id   = Column(UUID(as_uuid=True), ForeignKey("communities.id"), primary_key=True)
    user_id        = Column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True)
    role           = Column(String(20), default="member")   # admin / moderator / member
    joined_at      = Column(DateTime, default=datetime.utcnow)

    community      = relationship("Community", back_populates="members")
    user           = relationship("User", back_populates="communities")


# ── MESSAGES ───────────────────────────────────────────────────────────────

class Conversation(Base):
    __tablename__ = "conversations"

    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    type           = Column(String(20), default="dm")   # dm / group / plan
    reference_id   = Column(UUID(as_uuid=True), nullable=True)
    name           = Column(String(200), nullable=True)
    created_at     = Column(BigInteger, default=lambda: int(time.time() * 1000))
    updated_at     = Column(BigInteger, default=lambda: int(time.time() * 1000), onupdate=lambda: int(time.time() * 1000))

    messages       = relationship("Message", back_populates="conversation")
    members        = relationship("ConversationMember", back_populates="conversation")


class ConversationMember(Base):
    __tablename__ = "conversation_members"

    conversation_id = Column(UUID(as_uuid=True), ForeignKey("conversations.id"), primary_key=True)
    user_id         = Column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True)
    last_read_at    = Column(DateTime, nullable=True)

    conversation    = relationship("Conversation", back_populates="members")


class Message(Base):
    __tablename__ = "messages"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    conversation_id = Column(UUID(as_uuid=True), ForeignKey("conversations.id"), nullable=False)
    sender_id       = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    content         = Column(Text, nullable=False)
    msg_type        = Column(String(20), default="text")   # text / image
    sent_at         = Column(BigInteger, default=lambda: int(time.time() * 1000))

    conversation    = relationship("Conversation", back_populates="messages")
