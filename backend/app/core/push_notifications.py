from __future__ import annotations

import json
import logging
import os
from typing import Iterable, List
from uuid import UUID

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _FIREBASE_AVAILABLE = True
except ImportError:
    _FIREBASE_AVAILABLE = False
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.user import UserFCMToken

logger = logging.getLogger(__name__)


def _get_firebase_app():
    if not _FIREBASE_AVAILABLE:
        raise RuntimeError("firebase-admin package not installed")

    if firebase_admin._apps:
        return firebase_admin.get_app()

    # Try per-field env vars first
    creds_dict = settings.get_firebase_credentials_dict()
    if creds_dict:
        cred = credentials.Certificate(creds_dict)
        return firebase_admin.initialize_app(cred)

    # Fallback: full JSON string
    credentials_json = settings.FIREBASE_CREDENTIALS_JSON
    if credentials_json:
        try:
            cred = credentials.Certificate(json.loads(credentials_json))
            return firebase_admin.initialize_app(cred)
        except Exception as exc:
            raise RuntimeError("Invalid FIREBASE_CREDENTIALS_JSON") from exc

    # Fallback: file path
    credentials_path = settings.FIREBASE_CREDENTIALS_PATH
    if credentials_path:
        if not os.path.exists(credentials_path):
            raise RuntimeError("Firebase credentials file not found")
        cred = credentials.Certificate(credentials_path)
        return firebase_admin.initialize_app(cred)

    raise RuntimeError(
        "Firebase credentials are not configured. Set FIREBASE_CREDENTIALS_JSON or FIREBASE_CREDENTIALS_PATH."
    )


def register_device_token(db: Session, user_id: UUID, token: str) -> None:
    if not token:
        return
    existing = (
        db.query(UserFCMToken)
        .filter(UserFCMToken.token == token)
        .first()
    )
    if existing:
        if existing.user_id != user_id:
            existing.user_id = user_id
        return
    db.add(UserFCMToken(user_id=user_id, token=token))


def unregister_device_token(db: Session, user_id: UUID, token: str) -> None:
    if not token:
        return
    (
        db.query(UserFCMToken)
        .filter(UserFCMToken.user_id == user_id, UserFCMToken.token == token)
        .delete(synchronize_session=False)
    )


def _load_tokens_for_users(db: Session, user_ids: Iterable[UUID]) -> List[str]:
    ids = list(user_ids)
    if not ids:
        return []
    rows = (
        db.query(UserFCMToken.token)
        .filter(UserFCMToken.user_id.in_(ids))
        .all()
    )
    return [row[0] for row in rows]


def send_plan_cancelled_notification(
    db: Session,
    recipient_user_ids: Iterable[str],
    host_name: str,
    plan_title: str,
) -> int:
    user_ids: List[UUID] = []
    for raw in recipient_user_ids:
        try:
            user_ids.append(UUID(str(raw)))
        except ValueError:
            logger.warning("Skipping invalid user id for push token lookup: %s", raw)

    if not user_ids:
        return 0

    tokens = _load_tokens_for_users(db, user_ids)
    if not tokens:
        return 0

    try:
        _get_firebase_app()
    except Exception as exc:
        logger.error("Skipping push notification setup due to error:", exc_info=True)
        return 0

    sent_count = 0
    for i in range(0, len(tokens), 500):
        chunk = tokens[i : i + 500]
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title="Plan Cancelled",
                body=f"{host_name} cancelled '{plan_title}'",
            ),
            data={
                "type": "plan_cancelled",
                "plan_title": plan_title,
                "host_name": host_name,
            },
            tokens=chunk,
        )
        try:
            response = messaging.send_each_for_multicast(message)
            sent_count += response.success_count
            if response.failure_count:
                invalid_tokens: List[str] = []
                for idx, result in enumerate(response.responses):
                    if not result.success:
                        exc = result.exception
                        if exc and "registration-token-not-registered" in str(exc):
                            invalid_tokens.append(chunk[idx])
                if invalid_tokens:
                    (
                        db.query(UserFCMToken)
                        .filter(UserFCMToken.token.in_(invalid_tokens))
                        .delete(synchronize_session=False)
                    )
                    db.flush()
        except Exception as exc:
            logger.error("Push send failed for plan cancel:", exc_info=True)

    return sent_count

def send_test_notification(db: Session, user_id: UUID) -> dict:
    tokens = _load_tokens_for_users(db, [user_id])
    if not tokens:
        return {"success": False, "error": "No device tokens found for user"}

    try:
        _get_firebase_app()
    except Exception as exc:
        logger.error("Failed to init firebase for test notification:", exc_info=True)
        return {"success": False, "error": f"Firebase init failed: {exc}"}

    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title="Test Notification",
            body="If you see this, Firebase Push Notifications are working!",
        ),
        data={"type": "test_push"},
        tokens=tokens,
    )
    try:
        response = messaging.send_each_for_multicast(message)
        return {
            "success": True,
            "success_count": response.success_count,
            "failure_count": response.failure_count,
            "total_tokens": len(tokens)
        }
    except Exception as exc:
        logger.error("Test push send failed:", exc_info=True)
        return {"success": False, "error": str(exc)}
