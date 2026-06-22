@echo off
echo Killing any existing backend on port 8000...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000 ^| findstr LISTENING') do taskkill /f /pid %%a 2>nul

echo Starting Backend...
start "City Companion - Backend" cmd /k "cd /d "%~dp0backend" && call .venv\Scripts\activate.bat && uvicorn main:app --reload --host 0.0.0.0 --port 8000"

timeout /t 2 /nobreak >nul

echo Starting Frontend...
start "City Companion - Frontend" cmd /k "cd /d "%~dp0frontend" && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/v1"
