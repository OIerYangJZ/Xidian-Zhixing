@echo off
chcp 65001 >nul
title xduWhisperBox Frontend
cd /d "%~dp0"
echo ========================================
echo   xduWhisperBox Frontend Launcher
echo ========================================
echo.

echo [1/4] Enabling Flutter Web support...
flutter config --enable-web
echo.

echo [2/4] Checking Flutter environment...
call flutter --version
echo.

echo [3/4] Installing dependencies...
call flutter pub get
echo.

echo [4/4] Starting Flutter Web...
echo NOTE: Make sure the backend is running first!
echo.
call flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080/api

echo.
echo.
echo ===== Flutter exited =====
echo Press any key to close this window...
pause >nul
