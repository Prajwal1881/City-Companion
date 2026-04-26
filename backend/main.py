from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import auth, users, plans, rooms, communities, events, chat, notifications
from app.core.config import settings
from app.db.database import engine
from app.models import base

from sqlalchemy import text

base.Base.metadata.create_all(bind=engine)

# ── Safe startup migrations ──────────────────────────────────────────────────
# Adds columns that were introduced after the initial DB creation.
# Uses IF NOT EXISTS so it's safe to run on every startup.
def _run_startup_migrations():
    with engine.connect() as conn:
        migrations = [
            # conversations.updated_at added in chat feature
            "ALTER TABLE conversations ADD COLUMN IF NOT EXISTS updated_at BIGINT",
            # user_fcm_tokens table — created by create_all, but friendships may be missing
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128) UNIQUE",
            # friendships table may be missing on older DBs
        ]
        for sql in migrations:
            try:
                conn.execute(text(sql))
            except Exception as e:
                pass  # Column already exists or table doesn't exist yet
        conn.commit()

_run_startup_migrations()

app = FastAPI(
    title="City Companion API",
    description="Backend for City Companion — local plans, roommates, communities",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,        prefix="/v1/auth",        tags=["Auth"])
app.include_router(users.router,       prefix="/v1/users",       tags=["Users"])
app.include_router(plans.router,       prefix="/v1/plans",       tags=["Plans"])
app.include_router(rooms.router,       prefix="/v1/rooms",       tags=["Rooms"])
app.include_router(communities.router, prefix="/v1/communities", tags=["Communities"])
app.include_router(events.router,      prefix="/v1/events",      tags=["Events"])
app.include_router(chat.router,        prefix="/v1/chat",        tags=["Chat"])
app.include_router(notifications.router, prefix="/v1/notifications", tags=["Notifications"])

@app.get("/")
def root():
    return {"status": "ok", "app": "City Companion API v1"}
