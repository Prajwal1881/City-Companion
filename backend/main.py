import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.api.routes import auth, users, plans, rooms, communities, events, chat, notifications, friends
from app.core.config import settings
from app.db.database import engine
from app.models import base

from sqlalchemy import text

base.Base.metadata.create_all(bind=engine)

# ── Safe startup migrations ──────────────────────────────────────────────────
# Adds columns that were introduced after the initial DB creation.
# Uses IF NOT EXISTS so it's safe to run on every startup.
def _run_startup_migrations():
    migrations = [
        "ALTER TABLE conversations ADD COLUMN IF NOT EXISTS updated_at BIGINT",
        # Add firebase_uid column first (without UNIQUE — safe to re-run)
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128)",
        # Then add the unique constraint separately (safe to re-run)
        """DO $$ BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = 'users_firebase_uid_key' AND conrelid = 'users'::regclass
          ) THEN
            ALTER TABLE users ADD CONSTRAINT users_firebase_uid_key UNIQUE (firebase_uid);
          END IF;
        END $$;""",
        """DO $$ BEGIN
          IF (SELECT data_type FROM information_schema.columns
              WHERE table_name='conversations' AND column_name='created_at') = 'timestamp without time zone'
          THEN
            ALTER TABLE conversations ALTER COLUMN created_at TYPE BIGINT
              USING EXTRACT(EPOCH FROM created_at)::BIGINT * 1000;
          END IF;
        END $$;""",
        """DO $$ BEGIN
          IF (SELECT data_type FROM information_schema.columns
              WHERE table_name='conversations' AND column_name='updated_at') = 'timestamp without time zone'
          THEN
            ALTER TABLE conversations ALTER COLUMN updated_at TYPE BIGINT
              USING EXTRACT(EPOCH FROM updated_at)::BIGINT * 1000;
          END IF;
        END $$;""",
        """DO $$ BEGIN
          IF (SELECT data_type FROM information_schema.columns
              WHERE table_name='messages' AND column_name='sent_at') = 'timestamp without time zone'
          THEN
            ALTER TABLE messages ALTER COLUMN sent_at TYPE BIGINT
              USING EXTRACT(EPOCH FROM sent_at)::BIGINT * 1000;
          END IF;
        END $$;""",
        # ── Performance indexes ──
        "CREATE INDEX IF NOT EXISTS idx_plans_active_date ON plans (plan_date) WHERE is_active = true",
        "CREATE INDEX IF NOT EXISTS idx_plans_lat_lng ON plans (latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL",
        "CREATE INDEX IF NOT EXISTS idx_users_lat_lng ON users (latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL",
        "CREATE INDEX IF NOT EXISTS idx_rooms_active_city ON rooms (city, created_at DESC) WHERE is_active = true",
        "CREATE INDEX IF NOT EXISTS idx_messages_conv_sent ON messages (conversation_id, sent_at DESC)",
        "CREATE INDEX IF NOT EXISTS idx_conv_members_user ON conversation_members (user_id)",
        "CREATE INDEX IF NOT EXISTS idx_friendships_lookup ON friendships (requester_id, addressee_id, status)",
        "CREATE INDEX IF NOT EXISTS idx_conversations_type_ref ON conversations (type, reference_id) WHERE reference_id IS NOT NULL",
        "CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id, is_read, created_at DESC)",
    ]
    for sql in migrations:
        try:
            with engine.begin() as conn:
                conn.execute(text(sql))
        except Exception:
            pass

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
app.include_router(friends.router,       prefix="/v1/friends",       tags=["Friends"])

_uploads_dir = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(_uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=_uploads_dir), name="uploads")

@app.get("/")
def root():
    return {"status": "ok", "app": "City Companion API v1"}
