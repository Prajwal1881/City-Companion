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

# ── Optional Redis setup (for FCM token storage) ─────────────────────────────
_redis_client = None
if settings.REDIS_URL:
    try:
        import redis as redis_lib
        _redis_client = redis_lib.from_url(settings.REDIS_URL, decode_responses=True)
    except Exception as e:
        logger.warning("Redis not available for push notifications: %s", e)


def _get_firebase_app():
    if not _FIREBASE_AVAILABLE:
        raise RuntimeError("firebase-admin package not installed")

    if firebase_admin._apps:
        return firebase_admin.get_app()

    creds_dict = get_firebase_credentials_dict()
    if not creds_dict:
        raise RuntimeError("Firebase credentials not configured (set FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, etc.)")

    cred = credentials.Certificate(creds_dict)
    return firebase_admin.initialize_app(cred)


def _token_key(user_id: str) -> str:
    return f"user:{user_id}:fcm_tokens"


def register_device_token(user_id: str, token: str) -> None:
    if token and _redis_client:
        _redis_client.sadd(_token_key(user_id), token)


def unregister_device_token(user_id: str, token: str) -> None:
    if token and _redis_client:
        _redis_client.srem(_token_key(user_id), token)


def _load_tokens_for_users(user_ids: Iterable[str]) -> List[str]:
    if not _redis_client:
        return []
    tokens: set[str] = set()
    for user_id in user_ids:
        tokens.update(_redis_client.smembers(_token_key(user_id)))
    return list(tokens)


def send_plan_cancelled_notification(
    recipient_user_ids: Iterable[str],
    host_name: str,
    plan_title: str,
) -> int:
    """Send push notification for plan cancellation. No-op if Firebase not configured."""
    user_ids = list(recipient_user_ids)
    if not user_ids:
        return 0

    tokens = _load_tokens_for_users(user_ids)
    if not tokens:
        logger.info("No FCM tokens found — skipping push notification")
        return 0

    try:
        _get_firebase_app()
    except Exception as exc:
        logger.warning("Skipping push notification: %s", exc)
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
            if response.failure_count and _redis_client:
                for idx, result in enumerate(response.responses):
                    if not result.success:
                        exc = result.exception
                        if exc and "registration-token-not-registered" in str(exc):
                            for user_id in user_ids:
                                _redis_client.srem(_token_key(user_id), chunk[idx])
        except Exception as exc:
            logger.warning("Push send failed for plan cancel: %s", exc)

    return sent_count
