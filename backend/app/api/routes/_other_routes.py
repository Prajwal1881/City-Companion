from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from typing import List, Optional
from app.db.database import get_db
from app.schemas.schemas import RoomCreate, RoomOut, CommunityCreate, CommunityOut, MessageCreate, MessageOut, ConversationOut
from app.models.other import Room, Community, CommunityMember, Conversation, ConversationMember, Message
from app.models.plan import Plan
from app.models.user import User
from app.core.security import get_current_user, verify_token
import json

# ── ROOMS ──────────────────────────────────────────────────────────────────

router_rooms = APIRouter()

@router_rooms.get("/", response_model=List[RoomOut])
def list_rooms(
    city: Optional[str] = Query(None),
    max_rent: Optional[int] = Query(None),
    gender_pref: Optional[str] = Query(None),
    room_type: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Room).filter(Room.is_active == True)
    if city:        q = q.filter(Room.city.ilike(f"%{city}%"))
    if max_rent:    q = q.filter(Room.rent_inr <= max_rent)
    if gender_pref: q = q.filter(Room.gender_pref == gender_pref)
    if room_type:   q = q.filter(Room.room_type == room_type)
    rooms = q.order_by(Room.created_at.desc()).all()
    result = []
    for r in rooms:
        owner = db.query(User).filter(User.id == r.owner_id).first()
        result.append({**r.__dict__, "owner_name": owner.name if owner else "Unknown"})
    return result

@router_rooms.post("/", response_model=RoomOut)
def create_room(data: RoomCreate, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    room = Room(**data.dict(), owner_id=current_user.id)
    db.add(room)
    db.commit()
    db.refresh(room)
    return {**room.__dict__, "owner_name": current_user.name}

@router_rooms.get("/{room_id}", response_model=RoomOut)
def get_room(room_id: str, db: Session = Depends(get_db),
             _: User = Depends(get_current_user)):
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    owner = db.query(User).filter(User.id == room.owner_id).first()
    return {**room.__dict__, "owner_name": owner.name if owner else "Unknown"}

@router_rooms.delete("/{room_id}")
def delete_room(room_id: str, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    room = db.query(Room).filter(Room.id == room_id, Room.owner_id == current_user.id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Not found or unauthorized")
    room.is_active = False
    db.commit()
    return {"message": "Listing deactivated"}


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
    c.member_count += 1
    db.commit()
    return {"message": f"Joined {c.name}"}

@router_communities.delete("/{community_id}/leave")
def leave_community(community_id: str, db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    member = db.query(CommunityMember).filter_by(community_id=community_id, user_id=current_user.id).first()
    if member:
        db.delete(member)
        c = db.query(Community).filter(Community.id == community_id).first()
        if c and c.member_count > 0:
            c.member_count -= 1
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

# In-memory connection manager (use Redis pub/sub for multi-server production)
class ConnectionManager:
    def __init__(self):
        self.active: dict[str, list[WebSocket]] = {}

    async def connect(self, conversation_id: str, ws: WebSocket):
        await ws.accept()
        self.active.setdefault(conversation_id, []).append(ws)

    def disconnect(self, conversation_id: str, ws: WebSocket):
        self.active.get(conversation_id, []).remove(ws)

    async def broadcast(self, conversation_id: str, message: dict):
        for ws in self.active.get(conversation_id, []):
            await ws.send_text(json.dumps(message))

manager = ConnectionManager()

@router_chat.get("/conversations", response_model=List[ConversationOut])
def get_conversations(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    memberships = db.query(ConversationMember).filter_by(user_id=current_user.id).all()
    result = []
    for m in memberships:
        conv = db.query(Conversation).filter(Conversation.id == m.conversation_id).first()
        if conv:
            conv_name = conv.name
            can_delete = False
            if (not conv_name) and conv.type == "plan" and conv.reference_id:
                plan = db.query(Plan).filter(Plan.id == conv.reference_id).first()
                if plan and plan.title:
                    conv_name = plan.title
            if conv.type == "plan" and conv.reference_id:
                plan = db.query(Plan).filter(Plan.id == conv.reference_id).first()
                can_delete = bool(plan and plan.host_id == current_user.id)
            last_msg = db.query(Message).filter_by(conversation_id=conv.id).order_by(Message.sent_at.desc()).first()
            result.append({
                **conv.__dict__,
                "name": conv_name or "Plan Chat",
                "last_message": last_msg.content if last_msg else None,
                "unread_count": 0,
                "can_delete": can_delete,
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
def get_messages(conv_id: str, db: Session = Depends(get_db),
                 _: User = Depends(get_current_user)):
    msgs = db.query(Message).filter_by(conversation_id=conv_id).order_by(Message.sent_at).all()
    result = []
    for m in msgs:
        sender = db.query(User).filter(User.id == m.sender_id).first()
        result.append({**m.__dict__, "sender_name": sender.name if sender else "Unknown"})
    return result

@router_chat.websocket("/ws")
async def websocket_endpoint(ws: WebSocket, token: str, conv_id: str, db: Session = Depends(get_db)):
    user_id = verify_token(token)
    if not user_id:
        await ws.close(code=4001)
        return
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        await ws.close(code=4001)
        return

    await manager.connect(conv_id, ws)
    try:
        while True:
            data = await ws.receive_text()
            payload = json.loads(data)
            content = payload.get("content", "")
            msg = Message(conversation_id=conv_id, sender_id=user_id, content=content)
            db.add(msg)
            db.commit()
            db.refresh(msg)
            await manager.broadcast(conv_id, {
                "id": str(msg.id),
                "sender_id": str(user_id),
                "sender_name": user.name,
                "content": content,
                "sent_at": msg.sent_at.isoformat(),
            })
    except WebSocketDisconnect:
        manager.disconnect(conv_id, ws)
