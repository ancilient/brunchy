@echo off
REM Builds Brunchy-flutter.apk. Needs Flutter (https://docs.flutter.dev/get-started/install) and Android Studio.
cd /d "%~dp0"
where flutter >nul 2>nul || (echo ERROR: Flutter not found. Install it and add flutter\bin to PATH. & pause & exit /b 1)
if not exist android (
  call flutter create . --platforms=android --org com.ancilient --project-name brunchy || goto :fail
  call flutter pub get || goto :fail
  call dart run tool/setup_android.dart || goto :fail
  call dart run flutter_launcher_icons || echo Icon generation failed; the app will use the default Flutter icon.
) else (
  call flutter pub get || goto :fail
)
call flutter build apk --release || goto :fail
copy /y build\app\outputs\flutter-apk\app-release.apk Brunchy-flutter.apk >nul
echo.
echo Done: %cd%\Brunchy-flutter.apk  (copy it to the phone and open it to install)
pause
exit /b 0
:fail
echo.
echo Build failed. Read the red lines above; run "flutter doctor" to check your setup.
pause
exit /b 1
