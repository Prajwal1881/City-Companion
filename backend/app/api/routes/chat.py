from app.api.routes._other_routes import router_chat
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.other import Conversation, ConversationMember
from uuid import UUID

router = APIRouter()
router.include_router(router_chat)

@router.post("/dm/{target_user_id}")
def get_or_create_dm(target_user_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Finds an existing DM between two users or creates a new one."""

    try:
        target_user_uuid = UUID(target_user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid target user id.")

    if current_user.id == target_user_uuid:
        raise HTTPException(status_code=400, detail="Cannot create a DM with yourself.")

    target_user = db.query(User).filter(User.id == target_user_uuid).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found.")

    # 1. Check if DM already exists
    # This requires a query that finds a conversation of type 'dm' 
    # where both current_user and target_user are members.
    existing_dm = db.query(Conversation).join(ConversationMember).filter(
        Conversation.type == "dm",
        ConversationMember.user_id.in_([current_user.id, target_user_uuid])
    ).group_by(Conversation.id).having(func.count(ConversationMember.user_id) == 2).first()

    if existing_dm:
        return {"conversation_id": str(existing_dm.id)}

    # 2. Create new DM if none exists
    new_conv = Conversation(type="dm")
    db.add(new_conv)
    db.commit()
    db.refresh(new_conv)

    # Add members
    member1 = ConversationMember(conversation_id=new_conv.id, user_id=current_user.id)
    member2 = ConversationMember(conversation_id=new_conv.id, user_id=target_user_uuid)
    db.add_all([member1, member2])
    db.commit()

    return {"conversation_id": str(new_conv.id)}
