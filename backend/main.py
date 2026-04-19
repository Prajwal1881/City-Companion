from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import auth, users, plans, rooms, communities, events, chat
from app.core.config import settings
from app.db.database import engine
from app.models import base

base.Base.metadata.create_all(bind=engine)

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

@app.get("/")
def root():
    return {"status": "ok", "app": "City Companion API v1"}
