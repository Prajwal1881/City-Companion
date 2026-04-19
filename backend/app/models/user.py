import uuid
from sqlalchemy import Column, String, Integer, Boolean, Float, Text, DateTime, ForeignKey, Table
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
from app.db.database import Base

user_interests = Table("user_interests", Base.metadata,
    Column("user_id", UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True),
    Column("interest", String(100), primary_key=True),
)

user_languages = Table("user_languages", Base.metadata,
    Column("user_id", UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True),
    Column("language", String(100), primary_key=True),
)

class User(Base):
    __tablename__ = "users"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone            = Column(String(15), unique=True, nullable=True)
    email            = Column(String(255), unique=True, nullable=True)
    name             = Column(String(100), nullable=False)
    age              = Column(Integer, nullable=True)
    gender           = Column(String(20), nullable=True)
    bio              = Column(Text, nullable=True)
    profile_photo    = Column(Text, nullable=True)
    profession       = Column(String(100), nullable=True)
    current_city     = Column(String(100), nullable=True)
    hometown         = Column(String(100), nullable=True)
    latitude         = Column(Float, nullable=True)
    longitude        = Column(Float, nullable=True)
    trust_score      = Column(Float, default=0.0)
    is_phone_verified = Column(Boolean, default=False)
    is_id_verified   = Column(Boolean, default=False)
    is_profile_complete = Column(Boolean, default=False)
    firebase_uid     = Column(String(128), unique=True, nullable=True)
    created_at       = Column(DateTime, default=datetime.utcnow)
    updated_at       = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    plans            = relationship("Plan", back_populates="host")
    rooms            = relationship("Room", back_populates="owner")
    communities      = relationship("CommunityMember", back_populates="user")
