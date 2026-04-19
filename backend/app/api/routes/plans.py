from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from app.db.database import get_db
from app.schemas.schemas import PlanCreate, PlanOut
from app.models.plan import Plan, plan_members
from app.models.user import User
from app.core.security import get_current_user
from datetime import datetime

router = APIRouter()

@router.get("/", response_model=List[PlanOut])
def list_plans(
    category: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    lat: Optional[float] = Query(None),
    lng: Optional[float] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Plan).filter(Plan.is_active == True, Plan.plan_date >= datetime.utcnow())
    if category:
        q = q.filter(Plan.category == category)
    plans = q.order_by(Plan.plan_date).all()

    result = []
    for p in plans:
        host = db.query(User).filter(User.id == p.host_id).first()
        result.append({
            **p.__dict__,
            "host_name": host.name if host else "Unknown",
            "joined_count": len(p.members),
            "has_joined": any(m.id == _.id for m in p.members),
            "is_host": p.host_id == _.id,
            "members": p.members
        })
    return result

@router.post("/", response_model=PlanOut)
def create_plan(data: PlanCreate, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    plan = Plan(**data.dict(), host_id=current_user.id)
    plan.members.append(current_user)
    db.add(plan)
    db.commit()
    db.refresh(plan)
    return {
        **plan.__dict__, 
        "host_name": current_user.name, 
        "joined_count": 1,
        "has_joined": True,
        "is_host": True,
        "members": plan.members
    }

@router.get("/{plan_id}", response_model=PlanOut)
def get_plan(plan_id: str, db: Session = Depends(get_db),
             _: User = Depends(get_current_user)):
    plan = db.query(Plan).filter(Plan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    host = db.query(User).filter(User.id == plan.host_id).first()
    return {
        **plan.__dict__, 
        "host_name": host.name if host else "Unknown", 
        "joined_count": len(plan.members),
        "has_joined": any(m.id == _.id for m in plan.members),
        "is_host": plan.host_id == _.id,
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
    db.commit()
    return {"message": "Joined successfully!", "joined_count": len(plan.members)}

@router.delete("/{plan_id}/leave")
def leave_plan(plan_id: str, db: Session = Depends(get_db),
               current_user: User = Depends(get_current_user)):
    plan = db.query(Plan).filter(Plan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    if current_user in plan.members:
        plan.members.remove(current_user)
        db.commit()
    return {"message": "Left plan"}

@router.delete("/{plan_id}")
def delete_plan(plan_id: str, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    plan = db.query(Plan).filter(Plan.id == plan_id, Plan.host_id == current_user.id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found or unauthorized")
    plan.is_active = False
    db.commit()
    return {"message": "Plan deactivated"}
