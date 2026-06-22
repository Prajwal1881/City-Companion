@echo off
title City Companion - Frontend
cd /d "%~dp0frontend"
echo Starting Flutter frontend...
echo Available devices: windows, chrome, edge
echo.
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/v1
pause
