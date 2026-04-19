# City Companion

A local community & plan-hosting app — connect with people in your city for food runs, cricket matches, gym sessions, rides, and more. All plans are free to join.

## Project Structure

```
city_companion/
├── backend/          # FastAPI Python backend
│   ├── main.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .env.example
│   └── app/
│       ├── api/routes/   # auth, users, plans, rooms, communities, chat
│       ├── core/         # config, security (JWT)
│       ├── db/           # SQLAlchemy setup
│       ├── models/       # ORM models
│       └── schemas/      # Pydantic schemas
│
└── frontend/         # Flutter mobile app
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/         # theme, router
        ├── screens/      # feed, discover, rooms, communities, chat, profile, auth
        ├── widgets/      # plan_card, create_plan_sheet
        └── services/     # api_client, chat_service (WebSocket)
```

## Quick Start

### Backend

```bash
cd backend

# 1. Copy env
cp .env.example .env
# Edit .env with your DB credentials

# 2. Run with Docker (recommended)
docker-compose up --build

# OR run manually:
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

API docs available at: **http://localhost:8000/docs**

### Frontend (Flutter)

```bash
cd frontend

# 1. Install dependencies
flutter pub get

# 2. Run on device/emulator
flutter run

# 3. Build APK
flutter build apk --release
```

> **Note:** Update `_baseUrl` in `lib/services/api_client.dart` to match your backend URL.
> For Android emulator use `http://10.0.2.2:8000/v1`

## Core Features

| Feature | Backend | Flutter |
|---------|---------|---------|
| Phone OTP Auth | ✅ | ✅ |
| Create & Join Plans | ✅ | ✅ |
| Discover Nearby People | ✅ | ✅ |
| Roommate Finder | ✅ | ✅ |
| Communities | ✅ | ✅ |
| Real-time Chat (WebSocket) | ✅ | ✅ |
| Profile & Verification | ✅ | ✅ |
| Push Notifications | 🔜 | 🔜 |
| Map View | 🔜 | 🔜 |

## Tech Stack

**Backend:** FastAPI · PostgreSQL · Redis · SQLAlchemy · JWT · WebSockets

**Frontend:** Flutter · Riverpod · go_router · Dio · Firebase Auth · WebSocket
