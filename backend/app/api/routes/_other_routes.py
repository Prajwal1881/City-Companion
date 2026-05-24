import asyncio
import json
import os
import time
import uuid as _uuid
from uuid import UUID as PyUUID

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, File, UploadFile
from sqlalchemy import func as sa_func
from sqlalchemy.orm import Session, joinedload, selectinload
from typing import List, Optional

from app.db.database import get_db, SessionLocal
from app.schemas.schemas import RoomCreate, RoomOut, CommunityCreate, CommunityOut, MessageCreate, MessageOut, ConversationOut
from app.models.other import Room, RoomImage, Community, CommunityMember, Conversation, ConversationMember, Message
from app.models.plan import Plan
from app.models.user import User
from app.core.security import get_current_user, verify_token
from app.core.config import settings

_BASE_DIR    = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
_UPLOADS_DIR = os.path.join(_BASE_DIR, "uploads")
_ROOM_IMG_DIR = os.path.join(_UPLOADS_DIR, "room_images")
_ALLOWED_EXT  = {"jpg", "jpeg", "png"}
_MAX_PHOTOS   = 6


def _photos(db, room_id):
    imgs = db.query(RoomImage).filter(RoomImage.room_id == room_id).all()
    return [{"id": str(i.id), "url": i.image_path} for i in imgs]

# ── ROOMS ──────────────────────────────────────────────────────────────────

router_rooms = APIRouter()

@router_rooms.get("/", response_model=List[RoomOut])
def list_rooms(
    city: Optional[str] = Query(None),
    max_rent: Optional[int] = Query(None),
    gender_pref: Optional[str] = Query(None),
    room_type: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = (
        db.query(Room)
        .options(joinedload(Room.owner), selectinload(Room.images))
        .filter(Room.is_active == True)
    )
    if city:        q = q.filter(Room.city.ilike(f"%{city}%"))
    if max_rent:    q = q.filter(Room.rent_inr <= max_rent)
    if gender_pref: q = q.filter(Room.gender_pref == gender_pref)
    if room_type:   q = q.filter(Room.room_type == room_type)
    rooms = q.order_by(Room.created_at.desc()).limit(limit).offset(offset).all()
    result = []
    for r in rooms:
        result.append({
            **r.__dict__,
            "owner_name": r.owner.name if r.owner else "Unknown",
            "photos": [{"id": str(i.id), "url": i.image_path} for i in r.images],
        })
    return result

@router_rooms.post("/", response_model=RoomOut)
def create_room(data: RoomCreate, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    room = Room(**data.dict(), owner_id=current_user.id)
    db.add(room)
    db.commit()
    db.refresh(room)
    return {**room.__dict__, "owner_name": current_user.name, "photos": []}

@router_rooms.get("/{room_id}", response_model=RoomOut)
def get_room(room_id: str, db: Session = Depends(get_db),
             _: User = Depends(get_current_user)):
    room = (
        db.query(Room)
        .options(joinedload(Room.owner), selectinload(Room.images))
        .filter(Room.id == room_id)
        .first()
    )
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    return {
        **room.__dict__,
        "owner_name": room.owner.name if room.owner else "Unknown",
        "photos": [{"id": str(i.id), "url": i.image_path} for i in room.images],
    }

@router_rooms.put("/{room_id}", response_model=RoomOut)
def update_room(room_id: str, data: RoomCreate, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    room = db.query(Room).filter(Room.id == room_id, Room.owner_id == current_user.id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Not found or unauthorized")
    for field, value in data.dict().items():
        setattr(room, field, value)
    db.commit()
    db.refresh(room)
    return {**room.__dict__, "owner_name": current_user.name,
            "photos": _photos(db, room.id)}

@router_rooms.delete("/{room_id}")
def delete_room(room_id: str, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    room = db.query(Room).filter(Room.id == room_id, Room.owner_id == current_user.id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Not found or unauthorized")
    room.is_active = False
    db.commit()
    return {"message": "Listing deactivated"}


@router_rooms.post("/{room_id}/photos")
async def upload_room_photo(
    room_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = db.query(Room).filter(Room.id == room_id, Room.owner_id == current_user.id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found or unauthorized")

    count = db.query(RoomImage).filter(RoomImage.room_id == room_id).count()
    if count >= _MAX_PHOTOS:
        raise HTTPException(status_code=400, detail=f"Maximum {_MAX_PHOTOS} photos per room")

    ext = (file.filename or "").rsplit(".", 1)[-1].lower()
    if ext not in _ALLOWED_EXT:
        raise HTTPException(status_code=400, detail="Only JPG/JPEG/PNG allowed")

    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Max file size is 5MB")

    os.makedirs(_ROOM_IMG_DIR, exist_ok=True)
    filename = f"room_{room_id}_{_uuid.uuid4().hex[:8]}.{ext}"
    with open(os.path.join(_ROOM_IMG_DIR, filename), "wb") as f:
        f.write(content)

    img = RoomImage(room_id=room_id, image_path=f"/uploads/room_images/{filename}")
    db.add(img)
    db.commit()
    db.refresh(img)
    return {"id": str(img.id), "url": img.image_path}


@router_rooms.delete("/{room_id}/photos/{photo_id}")
def delete_room_photo(
    room_id: str,
    photo_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = db.query(Room).filter(Room.id == room_id, Room.owner_id == current_user.id).first()
    if not room:
        raise HTTPException(status_code=403, detail="Not authorized")

    img = db.query(RoomImage).filter(RoomImage.id == photo_id, RoomImage.room_id == room_id).first()
    if not img:
        raise HTTPException(status_code=404, detail="Photo not found")

    filepath = os.path.join(_UPLOADS_DIR, img.image_path.lstrip("/uploads/"))
    if os.path.exists(filepath):
        os.remove(filepath)

    db.delete(img)
    db.commit()
    return {"message": "Photo deleted"}


# ── COMMUNITIES ────────────────────────────────────────────────────────────

router_communities = APIRouter()

@router_communities.get("/", response_model=List[CommunityOut])
def list_communities(
    city: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Community)
    if city:     q = q.filter(Community.city.ilike(f"%{city}%"))
    if category: q = q.filter(Community.category == category)
    return q.order_by(Community.member_count.desc()).all()

@router_communities.post("/", response_model=CommunityOut)
def create_community(data: CommunityCreate, db: Session = Depends(get_db),
                     current_user: User = Depends(get_current_user)):
    community = Community(**data.dict(), creator_id=current_user.id)
    db.add(community)
    db.flush()
    member = CommunityMember(community_id=community.id, user_id=current_user.id, role="admin")
    db.add(member)
    db.commit()
    db.refresh(community)
    return community

@router_communities.post("/{community_id}/join")
def join_community(community_id: str, db: Session = Depends(get_db),
                   current_user: User = Depends(get_current_user)):
    c = db.query(Community).filter(Community.id == community_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="Community not found")
    existing = db.query(CommunityMember).filter_by(community_id=community_id, user_id=current_user.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Already a member")
    db.add(CommunityMember(community_id=community_id, user_id=current_user.id))
    db.query(Community).filter(Community.id == community_id).update(
        {Community.member_count: Community.member_count + 1},
        synchronize_session="fetch",
    )
    db.commit()
    return {"message": f"Joined {c.name}"}

@router_communities.delete("/{community_id}/leave")
def leave_community(community_id: str, db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    member = db.query(CommunityMember).filter_by(community_id=community_id, user_id=current_user.id).first()
    if member:
        db.delete(member)
        db.query(Community).filter(
            Community.id == community_id,
            Community.member_count > 0,
        ).update(
            {Community.member_count: Community.member_count - 1},
            synchronize_session="fetch",
        )
        db.commit()
    return {"message": "Left community"}


# ── EVENTS (stub) ──────────────────────────────────────────────────────────

router_events = APIRouter()

@router_events.get("/")
def list_events(_: User = Depends(get_current_user)):
    return {"message": "Events endpoint — extend like Plans"}

@router_events.post("/")
def create_event(_: User = Depends(get_current_user)):
    return {"message": "Create event — same pattern as Plan creation"}


# ── CHAT ───────────────────────────────────────────────────────────────────

router_chat = APIRouter()

try:
    import redis.asyncio as aioredis
    _AIOREDIS_AVAILABLE = True
except ImportError:
    _AIOREDIS_AVAILABLE = False


class RedisConnectionManager:
    def __init__(self, redis_url: str | None):
        self.redis_url = redis_url
        self.local_connections: dict[str, list[WebSocket]] = {}
        self._pubsub_tasks: dict[str, asyncio.Task] = {}
        self._redis = None

    async def _get_redis(self):
        if self._redis is None and _AIOREDIS_AVAILABLE and self.redis_url:
            try:
                self._redis = aioredis.from_url(self.redis_url, decode_responses=True)
                await self._redis.ping()
            except Exception:
                self._redis = None
        return self._redis

    async def connect(self, conversation_id: str, ws: WebSocket):
        await ws.accept()
        self.local_connections.setdefault(conversation_id, []).append(ws)
        if conversation_id not in self._pubsub_tasks:
            self._pubsub_tasks[conversation_id] = asyncio.create_task(
                self._subscribe(conversation_id)
            )

    def disconnect(self, conversation_id: str, ws: WebSocket):
        sockets = self.local_connections.get(conversation_id, [])
        if ws in sockets:
            sockets.remove(ws)
        if not sockets:
            self.local_connections.pop(conversation_id, None)
            task = self._pubsub_tasks.pop(conversation_id, None)
            if task:
                task.cancel()

    async def broadcast(self, conversation_id: str, message: dict):
        r = await self._get_redis()
        if r:
            await r.publish(f"chat:{conversation_id}", json.dumps(message))
        else:
            await self._local_broadcast(conversation_id, message)

    async def _subscribe(self, conversation_id: str):
        r = await self._get_redis()
        if not r:
            return
        pubsub = r.pubsub()
        await pubsub.subscribe(f"chat:{conversation_id}")
        try:
            async for raw_message in pubsub.listen():
                if raw_message["type"] == "message":
                    await self._local_broadcast(
                        conversation_id, json.loads(raw_message["data"])
                    )
        except asyncio.CancelledError:
            await pubsub.unsubscribe(f"chat:{conversation_id}")
            await pubsub.aclose()

    async def _local_broadcast(self, conversation_id: str, message: dict):
        dead = []
        for ws in self.local_connections.get(conversation_id, []):
            try:
                await ws.send_text(json.dumps(message))
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(conversation_id, ws)


manager = RedisConnectionManager(settings.REDIS_URL)

@router_chat.post("/dm/{user_id}")
def get_or_create_dm(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get existing DM conversation with a user, or create one."""
    other = db.query(User).filter(User.id == user_id).first()
    if not other:
        raise HTTPException(status_code=404, detail="User not found")

    # Find an existing DM shared by both users
    my_ids = {r.conversation_id for r in db.query(ConversationMember).filter_by(user_id=current_user.id).all()}
    their_ids = {r.conversation_id for r in db.query(ConversationMember).filter_by(user_id=user_id).all()}
    shared = my_ids & their_ids
    for cid in shared:
        conv = db.query(Conversation).filter(Conversation.id == cid, Conversation.type == "dm").first()
        if conv:
            return {"conversation_id": str(conv.id)}

    # Create new DM
    conv = Conversation(type="dm", name=None)
    db.add(conv)
    db.flush()
    db.add(ConversationMember(conversation_id=conv.id, user_id=current_user.id))
    db.add(ConversationMember(conversation_id=conv.id, user_id=user_id))
    db.commit()
    return {"conversation_id": str(conv.id)}


@router_chat.get("/conversations", response_model=List[ConversationOut])
def get_conversations(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversations = (
        db.query(Conversation)
        .join(ConversationMember, ConversationMember.conversation_id == Conversation.id)
        .filter(ConversationMember.user_id == current_user.id)
        .limit(limit).offset(offset)
        .all()
    )
    if not conversations:
        return []

    conv_ids = [c.id for c in conversations]

    plan_ref_ids = [c.reference_id for c in conversations if c.type == "plan" and c.reference_id]
    plans_map = {}
    if plan_ref_ids:
        plans = db.query(Plan).filter(Plan.id.in_(plan_ref_ids)).all()
        plans_map = {p.id: p for p in plans}

    last_msg_subq = (
        db.query(
            Message.conversation_id,
            sa_func.max(Message.sent_at).label("max_sent_at"),
        )
        .filter(Message.conversation_id.in_(conv_ids))
        .group_by(Message.conversation_id)
        .subquery()
    )
    last_msgs = (
        db.query(Message)
        .join(
            last_msg_subq,
            (Message.conversation_id == last_msg_subq.c.conversation_id)
            & (Message.sent_at == last_msg_subq.c.max_sent_at),
        )
        .all()
    )
    msg_map = {m.conversation_id: m for m in last_msgs}

    result = []
    for conv in conversations:
        conv_name = conv.name
        can_delete = False
        plan = plans_map.get(conv.reference_id) if conv.type == "plan" and conv.reference_id else None
        if plan:
            if not conv_name and plan.title:
                conv_name = plan.title
            can_delete = (plan.host_id == current_user.id)

        last_msg = msg_map.get(conv.id)
        stable_time = last_msg.sent_at if last_msg else conv.created_at

        result.append({
            "id": str(conv.id),
            "type": conv.type,
            "name": conv_name or "Plan Chat",
            "last_message": last_msg.content if last_msg else None,
            "last_message_at": stable_time,
            "unread_count": 0,
            "can_delete": can_delete,
            "is_online": False,
            "updated_at": conv.created_at,
        })
    return result


@router_chat.delete("/conversations/{conv_id}")
def delete_conversation(
    conv_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conv = db.query(Conversation).filter(Conversation.id == conv_id).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    if conv.type != "plan" or not conv.reference_id:
        raise HTTPException(status_code=403, detail="Only hosted plan threads can be deleted")

    plan = db.query(Plan).filter(Plan.id == conv.reference_id).first()
    if not plan or plan.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only host can delete this plan thread")

    db.query(Message).filter(Message.conversation_id == conv.id).delete(synchronize_session=False)
    db.query(ConversationMember).filter(ConversationMember.conversation_id == conv.id).delete(synchronize_session=False)
    db.delete(conv)
    db.commit()
    return {"message": "Plan chat thread deleted"}

@router_chat.get("/conversations/{conv_id}/messages", response_model=List[MessageOut])
def get_messages(
    conv_id: str,
    limit: int = Query(50, ge=1, le=200),
    before: Optional[int] = Query(None, description="Cursor: fetch messages before this sent_at timestamp"),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Message).filter_by(conversation_id=conv_id)
    if before is not None:
        q = q.filter(Message.sent_at < before)
    msgs = q.order_by(Message.sent_at.desc()).limit(limit).all()
    msgs.reverse()

    if not msgs:
        return []

    sender_ids = list({m.sender_id for m in msgs})
    senders = db.query(User).filter(User.id.in_(sender_ids)).all()
    sender_map = {s.id: s for s in senders}

    result = []
    for m in msgs:
        sender = sender_map.get(m.sender_id)
        result.append({**m.__dict__, "sender_name": sender.name if sender else "Unknown"})
    return result

@router_chat.websocket("/ws")
async def websocket_endpoint(ws: WebSocket, token: str, conv_id: str):
    user_id = verify_token(token)
    if not user_id:
        await ws.close(code=4001)
        return

    try:
        conv_uuid = PyUUID(conv_id)
        user_uuid = PyUUID(str(user_id))
    except ValueError:
        await ws.close(code=4003)
        return

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_uuid).first()
    finally:
        db.close()

    if not user:
        await ws.close(code=4001)
        return

    user_name = user.name

    await manager.connect(conv_id, ws)
    try:
        while True:
            data = await ws.receive_text()
            payload = json.loads(data)
            content = payload.get("content", "")

            db = SessionLocal()
            try:
                msg = Message(conversation_id=conv_uuid, sender_id=user_uuid, content=content)
                db.add(msg)
                conv = db.query(Conversation).filter(Conversation.id == conv_uuid).first()
                if conv:
                    conv.updated_at = int(time.time() * 1000)
                db.commit()
                db.refresh(msg)
                msg_id = str(msg.id)
                msg_sent_at = msg.sent_at
            finally:
                db.close()

            await manager.broadcast(conv_id, {
                "id": msg_id,
                "sender_id": str(user_uuid),
                "sender_name": user_name,
                "content": content,
                "sent_at": msg_sent_at,
            })
    except WebSocketDisconnect:
        manager.disconnect(conv_id, ws)
