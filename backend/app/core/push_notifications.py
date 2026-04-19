from __future__ import annotations

import logging
import os
from typing import Iterable, List

import firebase_admin
from firebase_admin import credentials, messaging
import redis

from app.core.config import settings

logger = logging.getLogger(__name__)
r = redis.from_url(settings.REDIS_URL, decode_responses=True)


def _get_firebase_app():
    if firebase_admin._apps:
        return firebase_admin.get_app()

    credentials_path = settings.FIREBASE_CREDENTIALS_PATH
    if not credentials_path:
        raise RuntimeError("FIREBASE_CREDENTIALS_PATH is not configured")
    if not os.path.exists(credentials_path):
        raise RuntimeError("Firebase credentials file not found")

    cred = credentials.Certificate(credentials_path)
    return firebase_admin.initialize_app(cred)


def _token_key(user_id: str) -> str:
    return f"user:{user_id}:fcm_tokens"


def register_device_token(user_id: str, token: str) -> None:
    if token:
        r.sadd(_token_key(user_id), token)


def unregister_device_token(user_id: str, token: str) -> None:
    if token:
        r.srem(_token_key(user_id), token)


def _load_tokens_for_users(user_ids: Iterable[str]) -> List[str]:
    tokens: set[str] = set()
    for user_id in user_ids:
        tokens.update(r.smembers(_token_key(user_id)))
    return list(tokens)


def send_plan_cancelled_notification(
    recipient_user_ids: Iterable[str],
    host_name: str,
    plan_title: str,
) -> int:
    user_ids = list(recipient_user_ids)
    if not user_ids:
        return 0

    tokens = _load_tokens_for_users(user_ids)
    if not tokens:
        return 0

    try:
        _get_firebase_app()
    except Exception as exc:
        logger.warning("Skipping push notification setup: %s", exc)
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
                for token in invalid_tokens:
                    for user_id in user_ids:
                        r.srem(_token_key(user_id), token)
        except Exception as exc:
            logger.warning("Push send failed for plan cancel: %s", exc)

    return sent_count
