# City Companion - Developer Setup Guide (Mobile App)

This guide outlines the steps required for a developer to clone, build, and run the City Companion app on a physical Android device, while connecting to a local backend.

## 🛠 Prerequisites

Ensure you have the following SDKs and tools installed on your host machine:

### 1. Flutter & Dart
- **Flutter SDK**: `3.38.5` (Stable channel)
- **Dart SDK**: `3.10.4`
- Verify installation by running:
  ```bash
  flutter doctor -v
  ```

### 2. Backend Environment
- **Python**: `3.12.3` (or compatible 3.10+ version)
- **PostgreSQL**: Running locally or via Docker
- **Redis**: Running locally or via Docker (for Celery/WebSockets)

### 3. Android SDK
- **Android Studio**: Latest version with Command Line Tools
- **Platform Tools**: Ensure `adb` (Android Debug Bridge) is installed and added to your system `PATH`.
- **Compile SDK Version**: Ensure you have SDK `36` installed (the `build.gradle.kts` is explicitly configured to compile against API level 36).

---

## 🖥 1. Backend Setup

The app requires the FastAPI backend to be running to fetch plans, authenticate via OTP, etc.

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Activate your virtual environment and install dependencies:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```
3. Start the FastAPI server on all interfaces (`0.0.0.0`) so it can be accessed over the network/tunnel:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

---

## 📱 2. Connecting the Physical Android Device

By default, an Android app running on a physical device **cannot access `localhost` or `127.0.0.1`** on your development machine. We solve this using an ADB Reverse Proxy.

### Step 2.1: Connect Device
1. Enable **Developer Options** and **USB Debugging** on your Android phone.
2. Connect your phone to your computer via USB.
3. Verify your device is detected:
   ```bash
   flutter devices
   # or
   adb devices
   ```

### Step 2.2: Setup ADB Reverse Tunnel (Crucial Step!)
To allow the phone to talk to your computer's `localhost:8000`, run the following command in your terminal. **This maps port 8000 on the phone to port 8000 on your PC.**

```bash
adb reverse tcp:8000 tcp:8000
```
> [!IMPORTANT]
> **You must run this command every time you physically reconnect the phone or restart the ADB server.** If you see `DioException [connection timeout]` in the Flutter console, run this command again!

---

## 🚀 3. Frontend / App Setup

The frontend codebase is pre-configured to handle physical device networking, but here is what we changed in the architecture to make it work:

1. **Cleartext Traffic**: In `frontend/android/app/src/main/AndroidManifest.xml`, we added `android:usesCleartextTraffic="true"`. This is required because modern Android blocks non-HTTPS (`http://`) traffic by default, which breaks local development.
2. **API Base URL**: In `frontend/lib/services/api_client.dart`, the base URL is explicitly set to `http://localhost:8000/v1` (which relies on the ADB reverse tunnel).
3. **SDK Targeting**: In `frontend/android/app/build.gradle.kts`, `compileSdk` and `targetSdk` are hardcoded to `36` to match our environment.

### Running the App
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Install Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run the application on your physical device:
   ```bash
   flutter run
   ```

---

## 🧪 4. Testing Authentication

- The app uses a mock OTP system for development. 
- You can enter any valid phone number layout (e.g., `+91 1234567890`) and request an OTP.
- The OTP will be printed in the backend terminal logs, or automatically returned as `dev_otp` in the network payload (depending on your `ENV` configuration).
- The app uses `flutter_secure_storage` to persist the JWT token across app restarts.
