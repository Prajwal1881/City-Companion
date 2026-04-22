from __future__ import annotations

import logging
from typing import Iterable, List

from app.core.config import settings, get_firebase_credentials_dict

logger = logging.getLogger(__name__)

# ── Optional Firebase setup ──────────────────────────────────────────────────
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _FIREBASE_AVAILABLE = True
except ImportError:
    _FIREBASE_AVAILABLE = False


def _get_firebase_app():
    if not _FIREBASE_AVAILABLE:
        raise RuntimeError("firebase-admin package not installed")

    if firebase_admin._apps:
        return firebase_admin.get_app()

    creds_dict = get_firebase_credentials_dict()
    if not creds_dict:
        raise RuntimeError("Firebase credentials not configured")

    cred = credentials.Certificate(creds_dict)
    return firebase_admin.initialize_app(cred)


# ── Token management (Postgres-backed) ───────────────────────────────────────

def register_device_token(user_id: str, token: str, db) -> None:
    """Upsert an FCM token for a user into Postgres."""
    from app.models.user import UserFCMToken
    existing = db.query(UserFCMToken).filter(UserFCMToken.token == token).first()
    if not existing:
        db.add(UserFCMToken(user_id=user_id, token=token))
        db.commit()
        logger.info("FCM token registered for user %s", user_id)


def unregister_device_token(user_id: str, token: str, db) -> None:
    """Remove an FCM token from Postgres."""
    from app.models.user import UserFCMToken
    db.query(UserFCMToken).filter(
        UserFCMToken.user_id == user_id,
        UserFCMToken.token == token,
    ).delete(synchronize_session=False)
    db.commit()


def _load_tokens_for_users(user_ids: Iterable[str], db) -> List[str]:
    """Fetch all FCM tokens for a list of user IDs from Postgres."""
    from app.models.user import UserFCMToken
    ids = list(user_ids)
    if not ids:
        return []
    rows = db.query(UserFCMToken.token).filter(UserFCMToken.user_id.in_(ids)).all()
    return [r.token for r in rows]


def _remove_stale_token(token: str, db) -> None:
    """Remove an invalid/unregistered FCM token from Postgres."""
    from app.models.user import UserFCMToken
    db.query(UserFCMToken).filter(UserFCMToken.token == token).delete(synchronize_session=False)
    db.commit()


# ── Notification senders ─────────────────────────────────────────────────────

def send_plan_cancelled_notification(
    recipient_user_ids: Iterable[str],
    host_name: str,
    plan_title: str,
    db=None,
) -> int:
    """Send push notification for plan cancellation."""
    user_ids = list(recipient_user_ids)
    if not user_ids or db is None:
        return 0

    tokens = _load_tokens_for_users(user_ids, db)
    if not tokens:
        logger.info("No FCM tokens found for users — skipping push notification")
        return 0

    try:
        _get_firebase_app()
    except Exception as exc:
        logger.warning("Skipping push notification: %s", exc)
        return 0

    sent_count = 0
    for i in range(0, len(tokens), 500):
        chunk = tokens[i: i + 500]
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
            # Clean up stale tokens that are no longer registered
            if response.failure_count:
                for idx, result in enumerate(response.responses):
                    if not result.success:
                        exc = result.exception
                        if exc and "registration-token-not-registered" in str(exc):
                            _remove_stale_token(chunk[idx], db)
        except Exception as exc:
            logger.warning("Push send failed: %s", exc)

    return sent_count
