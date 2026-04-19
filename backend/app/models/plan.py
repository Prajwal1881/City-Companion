import uuid
from sqlalchemy import Column, String, Integer, Boolean, Float, Text, DateTime, ForeignKey, Table
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
from app.db.database import Base

plan_members = Table("plan_members", Base.metadata,
    Column("plan_id", UUID(as_uuid=True), ForeignKey("plans.id"), primary_key=True),
    Column("user_id", UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True),
    Column("joined_at", DateTime, default=datetime.utcnow),
)

class Plan(Base):
    __tablename__ = "plans"

    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    host_id      = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    category     = Column(String(50), nullable=False)   # food, play, gym, ride, hangout, trek
    title        = Column(String(200), nullable=False)
    description  = Column(Text, nullable=True)
    location     = Column(String(200), nullable=True)
    latitude     = Column(Float, nullable=True)
    longitude    = Column(Float, nullable=True)
    plan_date    = Column(DateTime, nullable=False)
    max_members  = Column(Integer, default=10)
    is_active    = Column(Boolean, default=True)
    created_at   = Column(DateTime, default=datetime.utcnow)
    updated_at   = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    host         = relationship("User", back_populates="plans")
    members      = relationship("User", secondary=plan_members)
