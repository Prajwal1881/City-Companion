@echo off
title City Companion - Backend
cd /d "%~dp0backend"
echo Starting FastAPI backend...
call .venv\Scripts\activate.bat
uvicorn main:app --reload --host 0.0.0.0 --port 8000
pause
