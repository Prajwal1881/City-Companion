from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload, subqueryload
from typing import List, Optional
from app.db.database import get_db
from app.core.geo import bounding_box, haversine_km
from app.schemas.schemas import (
    LocationAutocompleteSuggestion,
    PlanCreate,
    PlanNearbyOut,
    PlanOut,
)
from app.models.plan import Plan, plan_members
from app.models.notification import Notification
from app.models.other import Conversation, ConversationMember
from app.models.user import User
from app.core.security import get_current_user
from app.core.google_places import GooglePlacesServiceError, autocomplete_locations
from app.core.push_notifications import send_plan_cancelled_notification
from datetime import datetime

router = APIRouter()


def _get_plan_conversation(db: Session, plan_id):
    return (
        db.query(Conversation)
        .filter(Conversation.type == "plan", Conversation.reference_id == plan_id)
        .first()
    )


def _ensure_plan_conversation(
    db: Session,
    plan: Plan,
    host_id,
):
    conv = _get_plan_conversation(db, plan.id)
    if conv:
        if not conv.name and plan.title:
            conv.name = plan.title
        return conv

    conv = Conversation(type="plan", reference_id=plan.id, name=plan.title)
    db.add(conv)
    db.flush()
    db.add(ConversationMember(conversation_id=conv.id, user_id=host_id))
    return conv


@router.get("/location/autocomplete", response_model=List[LocationAutocompleteSuggestion])
async def location_autocomplete(
    query: str = Query(..., description="Location search query"),
    _: User = Depends(get_current_user),
):
    sanitized_query = query.strip()
    if not sanitized_query:
        raise HTTPException(status_code=400, detail="Query must not be empty")

    try:
        return await autocomplete_locations(sanitized_query)
    except GooglePlacesServiceError:
        raise HTTPException(
            status_code=503,
            detail="Location autocomplete is temporarily unavailable",
        )

@router.get("/", response_model=List[PlanOut])
def list_plans(
    category: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    lat: Optional[float] = Query(None),
    lng: Optional[float] = Query(None),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = (
        db.query(Plan)
        .options(joinedload(Plan.host), subqueryload(Plan.members))
        .filter(Plan.is_active == True, Plan.plan_date >= datetime.utcnow())
    )
    if category:
        q = q.filter(Plan.category == category)
    plans = q.order_by(Plan.plan_date).limit(limit).offset(offset).all()

    plan_ids = [p.id for p in plans]
    conv_map = {}
    if plan_ids:
        convs = db.query(Conversation).filter(
            Conversation.type == "plan",
            Conversation.reference_id.in_(plan_ids),
        ).all()
        conv_map = {c.reference_id: c for c in convs}

    result = []
    for p in plans:
        conv = conv_map.get(p.id)
        result.append({
            **p.__dict__,
            "host_name": p.host.name if p.host else "Unknown",
            "joined_count": len(p.members),
            "has_joined": any(m.id == _.id for m in p.members),
            "is_host": p.host_id == _.id,
            "conversation_id": conv.id if conv else None,
            "members": p.members
        })
    return result

@router.post("/", response_model=PlanOut)
def create_plan(data: PlanCreate, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    plan = Plan(**data.dict(), host_id=current_user.id)
    plan.members.append(current_user)
    db.add(plan)
    db.flush()
    conv = _ensure_plan_conversation(db, plan, current_user.id)
    db.commit()
    db.refresh(plan)
    return {
        **plan.__dict__, 
        "host_name": current_user.name, 
        "joined_count": 1,
        "has_joined": True,
        "is_host": True,
        "conversation_id": conv.id if conv else None,
        "members": plan.members
    }

@router.get("/nearby", response_model=List[PlanNearbyOut])
def nearby_plans(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(10.0, le=30.0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lat_min, lat_max, lng_min, lng_max = bounding_box(lat, lng, radius_km)

    plans = (
        db.query(Plan)
        .options(joinedload(Plan.host), subqueryload(Plan.members))
        .filter(
            Plan.is_active == True,
            Plan.plan_date >= datetime.utcnow(),
            Plan.latitude.isnot(None),
            Plan.longitude.isnot(None),
            Plan.latitude.between(lat_min, lat_max),
            Plan.longitude.between(lng_min, lng_max),
        )
        .order_by(Plan.plan_date)
        .all()
    )

    plan_ids = [p.id for p in plans]
    conv_map = {}
    if plan_ids:
        convs = db.query(Conversation).filter(
            Conversation.type == "plan",
            Conversation.reference_id.in_(plan_ids),
        ).all()
        conv_map = {c.reference_id: c for c in convs}

    result = []
    for p in plans:
        dist = haversine_km(lat, lng, p.latitude, p.longitude)
        if dist <= radius_km:
            conv = conv_map.get(p.id)
            result.append({
                **p.__dict__,
                "host_name": p.host.name if p.host else "Unknown",
                "joined_count": len(p.members),
                "has_joined": any(m.id == current_user.id for m in p.members),
                "is_host": p.host_id == current_user.id,
                "conversation_id": conv.id if conv else None,
                "members": p.members,
                "distance_km": round(dist, 2),
            })

    result.sort(key=lambda x: x["distance_km"])
    return result[:limit]


@router.get("/{plan_id}", response_model=PlanOut)
def get_plan(plan_id: str, db: Session = Depends(get_db),
             _: User = Depends(get_current_user)):
    plan = (
        db.query(Plan)
        .options(joinedload(Plan.host), subqueryload(Plan.members))
        .filter(Plan.id == plan_id)
        .first()
    )
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    conv = _get_plan_conversation(db, plan.id)
    return {
        **plan.__dict__,
        "host_name": plan.host.name if plan.host else "Unknown",
        "joined_count": len(plan.members),
        "has_joined": any(m.id == _.id for m in plan.members),
        "is_host": plan.host_id == _.id,
        "conversation_id": conv.id if conv else None,
        "members": plan.members
    }

@router.post("/{plan_id}/join")
def join_plan(plan_id: str, db: Session = Depends(get_db),
              current_user: User = Depends(get_current_user)):
    plan = db.query(Plan).filter(Plan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    if len(plan.members) >= plan.max_members:
        raise HTTPException(status_code=400, detail="Plan is full")
    if current_user in plan.members:
        raise HTTPException(status_code=400, detail="Already joined")
    plan.members.append(current_user)
    conv = _ensure_plan_conversation(db, plan, plan.host_id)
    membership = (
        db.query(ConversationMember)
        .filter(
            ConversationMember.conversation_id == conv.id,
            ConversationMember.user_id == current_user.id,
        )
        .first()
    )
    if not membership:
        db.add(ConversationMember(conversation_id=conv.id, user_id=current_user.id))
    db.commit()
    return {
        "message": "Joined successfully!",
        "joined_count": len(plan.members),
        "conversation_id": conv.id if conv else None,
    }

@router.delete("/{plan_id}/leave")
def leave_plan(plan_id: str, db: Session = Depends(get_db),
               current_user: User = Depends(get_current_user)):
    plan = db.query(Plan).filter(Plan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    if current_user in plan.members:
        plan.members.remove(current_user)
        conv = _get_plan_conversation(db, plan.id)
        if conv:
            membership = (
                db.query(ConversationMember)
                .filter(
                    ConversationMember.conversation_id == conv.id,
                    ConversationMember.user_id == current_user.id,
                )
                .first()
            )
            if membership:
                db.delete(membership)
        db.commit()
    return {"message": "Left plan"}

@router.delete("/{plan_id}")
def delete_plan(plan_id: str, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    plan = db.query(Plan).filter(Plan.id == plan_id, Plan.host_id == current_user.id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found or unauthorized")

    recipient_ids = [str(member.id) for member in plan.members if member.id != current_user.id]
    recipient_member_ids = [member.id for member in plan.members if member.id != current_user.id]
    host_name = current_user.name or "Host"
    plan_title = plan.title or "your plan"

    plan.is_active = False

    # Delete associated conversation, members, and messages
    from app.models.other import Message, ConversationMember, Conversation
    conv = _get_plan_conversation(db, plan.id)
    if conv:
        db.query(Message).filter(Message.conversation_id == conv.id).delete()
        db.query(ConversationMember).filter(ConversationMember.conversation_id == conv.id).delete()
        db.delete(conv)

    for member_id in recipient_member_ids:
        db.add(
            Notification(
                user_id=member_id,
                title="Plan Cancelled",
                body=f"{host_name} cancelled '{plan_title}'",
                type="plan_cancelled",
            )
        )

    db.commit()

    try:
        send_plan_cancelled_notification(
            db=db,
            recipient_user_ids=recipient_ids,
            host_name=host_name,
            plan_title=plan_title,
        )
    except Exception:
        # Push notification failures must not block plan cancellation.
        pass

    return {"message": "Plan deactivated"}
