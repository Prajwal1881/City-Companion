from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List
from app.db.database import get_db
from app.models.user import User, Friendship
from app.models.notification import Notification
from app.core.security import get_current_user
from app.schemas.schemas import FriendOut, FriendRequestOut

router = APIRouter()


def _get_friendship(db, user_a_id, user_b_id):
    return db.query(Friendship).filter(
        ((Friendship.requester_id == str(user_a_id)) & (Friendship.addressee_id == str(user_b_id))) |
        ((Friendship.requester_id == str(user_b_id)) & (Friendship.addressee_id == str(user_a_id)))
    ).first()


# ── List my friends ───────────────────────────────────────────────────────────

@router.get("/", response_model=List[FriendOut])
def list_friends(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    friendships = db.query(Friendship).filter(
        ((Friendship.requester_id == current_user.id) | (Friendship.addressee_id == current_user.id)),
        Friendship.status == "accepted"
    ).limit(limit).offset(offset).all()

    friend_ids = []
    for f in friendships:
        fid = f.addressee_id if str(f.requester_id) == str(current_user.id) else f.requester_id
        friend_ids.append(fid)

    if not friend_ids:
        return []

    friends = db.query(User).filter(User.id.in_(friend_ids)).all()
    friend_map = {f.id: f for f in friends}

    result = []
    for f in friendships:
        fid = f.addressee_id if str(f.requester_id) == str(current_user.id) else f.requester_id
        friend = friend_map.get(fid)
        if friend:
            result.append({
                "id": str(friend.id),
                "name": friend.name,
                "profession": friend.profession,
                "current_city": friend.current_city,
                "profile_photo": friend.profile_photo,
                "trust_score": friend.trust_score or 0.0,
            })
    return result


# ── Pending requests RECEIVED ─────────────────────────────────────────────────

@router.get("/requests", response_model=List[FriendRequestOut])
def get_requests(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    reqs = db.query(Friendship).filter(
        Friendship.addressee_id == current_user.id,
        Friendship.status == "pending"
    ).order_by(Friendship.created_at.desc()).limit(limit).offset(offset).all()

    if not reqs:
        return []

    requester_ids = [r.requester_id for r in reqs]
    requesters = db.query(User).filter(User.id.in_(requester_ids)).all()
    requester_map = {u.id: u for u in requesters}

    result = []
    for r in reqs:
        requester = requester_map.get(r.requester_id)
        if requester:
            result.append({
                "id": str(r.id),
                "requester_id": str(r.requester_id),
                "requester_name": requester.name,
                "requester_photo": requester.profile_photo,
                "requester_profession": requester.profession,
                "requester_city": requester.current_city,
                "created_at": r.created_at,
            })
    return result


# ── Friendship status with a user ─────────────────────────────────────────────

@router.get("/status/{user_id}")
def get_status(user_id: str, db: Session = Depends(get_db),
               current_user: User = Depends(get_current_user)):
    f = _get_friendship(db, current_user.id, user_id)
    if not f:
        return {"status": "none", "request_id": None}
    if f.status == "accepted":
        return {"status": "friends", "request_id": str(f.id)}
    if f.status == "pending":
        direction = "pending_sent" if str(f.requester_id) == str(current_user.id) else "pending_received"
        return {"status": direction, "request_id": str(f.id)}
    return {"status": f.status, "request_id": str(f.id)}


# ── Send friend request ───────────────────────────────────────────────────────

@router.post("/{user_id}")
def send_request(user_id: str, db: Session = Depends(get_db),
                 current_user: User = Depends(get_current_user)):
    if str(current_user.id) == user_id:
        raise HTTPException(400, "Cannot send a request to yourself")
    target = db.query(User).filter(User.id == user_id).first()
    if not target:
        raise HTTPException(404, "User not found")

    existing = _get_friendship(db, current_user.id, user_id)
    if existing:
        if existing.status == "accepted":
            raise HTTPException(400, "Already friends")
        if existing.status == "pending":
            raise HTTPException(400, "Request already pending")
        # Re-send after rejection
        existing.status = "pending"
        existing.requester_id = current_user.id
        existing.addressee_id = target.id
        db.commit()
        return {"message": f"Friend request sent to {target.name}"}

    db.add(Friendship(requester_id=current_user.id, addressee_id=target.id, status="pending"))
    db.add(Notification(
        user_id=target.id,
        title="New Friend Request",
        body=f"{current_user.name} wants to connect with you",
        type="friend_request",
    ))
    db.commit()
    return {"message": f"Friend request sent to {target.name}"}


# ── Accept ────────────────────────────────────────────────────────────────────

@router.post("/requests/{request_id}/accept")
def accept_request(request_id: str, db: Session = Depends(get_db),
                   current_user: User = Depends(get_current_user)):
    req = db.query(Friendship).filter(
        Friendship.id == request_id,
        Friendship.addressee_id == current_user.id,
        Friendship.status == "pending"
    ).first()
    if not req:
        raise HTTPException(404, "Request not found")
    req.status = "accepted"
    requester = db.query(User).filter(User.id == req.requester_id).first()
    if requester:
        db.add(Notification(
            user_id=req.requester_id,
            title="Friend Request Accepted",
            body=f"{current_user.name} accepted your friend request",
            type="friend_accepted",
        ))
    db.commit()
    return {"message": "Friend request accepted"}


# ── Decline ───────────────────────────────────────────────────────────────────

@router.post("/requests/{request_id}/decline")
def decline_request(request_id: str, db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    req = db.query(Friendship).filter(
        Friendship.id == request_id,
        Friendship.addressee_id == current_user.id,
        Friendship.status == "pending"
    ).first()
    if not req:
        raise HTTPException(404, "Request not found")
    req.status = "rejected"
    db.commit()
    return {"message": "Friend request declined"}


# ── Unfriend ──────────────────────────────────────────────────────────────────

@router.delete("/{user_id}")
def unfriend(user_id: str, db: Session = Depends(get_db),
             current_user: User = Depends(get_current_user)):
    f = _get_friendship(db, current_user.id, user_id)
    if not f:
        raise HTTPException(404, "Friendship not found")
    db.delete(f)
    db.commit()
    return {"message": "Unfriended successfully"}
