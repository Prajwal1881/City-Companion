# Local Setup Guide

Instructions to run City Companion's backend and frontend on your local machine.

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Python | 3.11+ | `python3 --version` |
| Flutter | >= 3.2.0 | `flutter --version` |
| Docker & Docker Compose | Latest | `docker --version` |
| Android Studio / Xcode | Latest | For mobile emulators |

---

## Backend

### Option A: Docker Compose (recommended)

This spins up PostgreSQL, Redis, and the API server in one command.

```bash
cd backend

# 1. Create your .env file
cp .env.example .env
# Edit .env — at minimum set a real SECRET_KEY
# Firebase, Cloudinary, and Google Places are optional for local dev

# 2. Start everything
docker-compose up --build
```

The API is now running at **http://localhost:8000**.
Swagger docs are at **http://localhost:8000/docs**.

To stop: `Ctrl+C` then `docker-compose down`.
To reset the database: `docker-compose down -v` (deletes the pgdata volume).

### Option B: Manual setup (without Docker)

You need PostgreSQL 14+ and Redis 7+ running locally.

```bash
cd backend

# 1. Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate      # Linux/macOS
# venv\Scripts\activate       # Windows

# 2. Install dependencies
pip install -r requirements.txt

# 3. Set up environment
cp .env.example .env
# Edit .env with your local PostgreSQL and Redis connection strings:
#   DATABASE_URL=postgresql://postgres:password@localhost:5432/city_companion
#   REDIS_URL=redis://localhost:6379
#   SECRET_KEY=any-random-string-for-local-dev

# 4. Create the database
psql -U postgres -c "CREATE DATABASE city_companion;"

# 5. Start the server
uvicorn main:app --reload --port 8000
```

The `--reload` flag enables hot reload on file changes.

### Environment variables reference

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `REDIS_URL` | No | Redis connection string. OTP falls back to hardcoded `555555` if unavailable |
| `SECRET_KEY` | Yes | JWT signing secret. Change from default in production |
| `FIREBASE_PROJECT_ID` | No | For push notifications. App works without it |
| `FIREBASE_PRIVATE_KEY` | No | Firebase service account key |
| `FIREBASE_CLIENT_EMAIL` | No | Firebase service account email |
| `CLOUDINARY_CLOUD_NAME` | No | For cloud image uploads. Falls back to local filesystem |
| `CLOUDINARY_API_KEY` | No | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | No | Cloudinary API secret |
| `GOOGLE_PLACES_API_KEY` | No | For location autocomplete in plan creation |

### Testing the backend

Once the server is running, verify it works:

```bash
# Health check
curl http://localhost:8000/

# Send OTP (dev mode — always returns the OTP)
curl -X POST http://localhost:8000/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+911234567890"}'

# Verify OTP (use 555555 for local dev)
curl -X POST http://localhost:8000/v1/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+911234567890", "otp": "555555"}'
```

The verify-otp response returns a JWT `access_token`. Use it as `Authorization: Bearer <token>` for all other endpoints.

---

## Frontend

### 1. Install dependencies

```bash
cd frontend
flutter pub get
```

### 2. Run code generators

The project uses Retrofit and Riverpod code generation:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Run the app

#### Pointing to your local backend

By default, the app connects to the deployed API (`city-companion.onrender.com`). To use your local backend:

```bash
# Android emulator (10.0.2.2 maps to host's localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1

# iOS simulator (localhost works directly)
flutter run --dart-define=API_BASE_URL=http://localhost:8000/v1

# Physical device (use your machine's local IP)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/v1
```

#### Using the deployed backend (no local server needed)

```bash
flutter run
```

This connects to the production API on Render.

### 4. Firebase setup (optional for local dev)

Push notifications and Firebase Auth require Firebase configuration files:

- **Android**: Place `google-services.json` in `frontend/android/app/`
- **iOS**: Place `GoogleService-Info.plist` in `frontend/ios/Runner/`

The app works without Firebase — OTP auth and core features function without it.

### 5. Google Maps (optional)

If you need the map screen to render tiles:

- **Android**: Add your Google Maps API key to `frontend/android/app/src/main/AndroidManifest.xml`
- **iOS**: Add it to `frontend/ios/Runner/AppDelegate.swift`

The app uses OpenStreetMap (flutter_map) as a fallback, so maps work without a Google API key.

---

## Running both together

Open two terminals:

```bash
# Terminal 1 — Backend
cd backend
docker-compose up --build

# Terminal 2 — Frontend (Android emulator)
cd frontend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1
```

### Quick login flow

1. App opens to splash screen, then redirects to phone auth
2. Enter any phone number (e.g., `+911234567890`)
3. Enter OTP: **555555** (hardcoded for dev)
4. You're in — the app creates a new user automatically on first login

---

## Ports

| Service | Port |
|---------|------|
| API | 8000 |
| PostgreSQL | 5432 |
| Redis | 6379 |

## Troubleshooting

**`Connection refused` from Flutter app**
- Android emulator: use `10.0.2.2` not `localhost`
- Physical device: use your machine's LAN IP and ensure firewall allows port 8000

**`password authentication failed` from backend**
- If using Docker Compose: delete the volume (`docker-compose down -v`) and restart — the postgres password is only set on first volume creation

**`redis.exceptions.ConnectionError`**
- Redis is optional. The app falls back to hardcoded OTP (`555555`) and local WebSocket broadcasting without it

**`No module named 'app'`**
- Make sure you're running uvicorn from inside the `backend/` directory

**Flutter build errors after pulling changes**
- Run `flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs`
