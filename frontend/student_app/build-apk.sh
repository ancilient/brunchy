#!/usr/bin/env bash
# Builds Brunchy-flutter.apk. Needs Flutter (https://docs.flutter.dev/get-started/install) and Android Studio.
set -e
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "ERROR: Flutter not found. Install it and add flutter/bin to PATH."; exit 1; }
if [ ! -d android ]; then
  flutter create . --platforms=android --org com.ancilient --project-name brunchy
  flutter pub get
  dart run tool/setup_android.dart
  dart run flutter_launcher_icons || echo "Icon generation failed; the app will use the default Flutter icon."
else
  flutter pub get
fi
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk Brunchy-flutter.apk
echo "Done: $(pwd)/Brunchy-flutter.apk  (copy it to the phone and open it to install)"
