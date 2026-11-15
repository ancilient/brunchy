@echo off
REM Runs the vendor app on the USB-connected phone, talking to the backend on this PC (http://localhost:4000).
REM The phone reaches the PC through "adb reverse", which Android forgets whenever the phone reconnects,
REM so this sets it up every time. Extra arguments go to flutter run, e.g.  run.bat --release
cd /d "%~dp0"
REM Terminals opened before PUB_CACHE was set (in Windows user settings) don't see it; read it from there.
if not defined PUB_CACHE for /f "tokens=2,*" %%a in ('reg query HKCU\Environment /v PUB_CACHE 2^>nul ^| findstr /b /c:"    PUB_CACHE"') do set "PUB_CACHE=%%b"
where flutter >nul 2>nul || (echo ERROR: Flutter not found. Install it and add flutter\bin to PATH. & pause & exit /b 1)
where adb >nul 2>nul || (echo ERROR: adb not found. Add Android SDK platform-tools to PATH. & pause & exit /b 1)

adb get-state >nul 2>nul || (echo ERROR: No phone found. Plug it in over USB and allow USB debugging. & pause & exit /b 1)
adb reverse tcp:4000 tcp:4000 >nul || (echo ERROR: Could not forward port 4000 to the phone. & pause & exit /b 1)
echo Phone connected: its localhost:4000 now reaches this PC.

curl -s -m 3 http://localhost:4000/api/v1/health >nul 2>nul
if errorlevel 1 (
  echo.
  echo WARNING: The backend is not answering on http://localhost:4000.
  echo          Start MySQL and Redis, then "npm run dev" in the backend folder. The app will open anyway.
  echo.
)

call flutter run %*
