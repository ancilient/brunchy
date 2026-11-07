# Brunchy student app (Flutter)

The main student app. It was rewritten from the React prototype in [`../web_prototype`](../web_prototype): same screens, flow, wording, colours, fonts, icons, menu and demo behaviour, in Flutter (Dart).
Run every command below from this folder (`frontend/student_app`).
Both versions use the app id `com.ancilient.brunchy`, so a phone can have only one of them installed at a time: uninstall one before installing the other.

## Build the APK
Needs **Flutter 3.27 or newer** (https://docs.flutter.dev/get-started/install) and **Android Studio** (for the Android SDK). Run `flutter doctor` once to check.

- **Windows:** double-click `build-apk.bat`
- **Mac / Linux:** `./build-apk.sh`

The result is `Brunchy-flutter.apk` in this folder. Copy it to the phone and open it to install.

The first run also creates the `android/` folder (`flutter create`) and sets the app name, icon, launch colour and internet permission (`tool/setup_android.dart`, `flutter_launcher_icons`). Later runs just rebuild.

To run it on a connected phone or emulator while working on it:
```
flutter pub get
flutter run
```

## Where things are
```
lib/main.dart                 app shell: header, bottom tabs, popups, Android back button   (App.tsx)
lib/state/app_state.dart      cart, checkout, payment hold, orders, login, saving on the phone (CanteenContext.tsx)
lib/state/menu_data.dart      canteens, stalls and menu, generated from src/data/mockData.ts
lib/screens/                  one file per screen group, each names the React file it matches
lib/ui/theme.dart             colours and fonts (the Tailwind values)
lib/ui/icons.dart             the Lucide icons the React app uses, same shapes
```

## Current limits (until it is connected to `backend/`)
It is a working demo with no server: payments are simulated (nothing is charged), orders stay on the phone, and the login OTP is not sent.
The logic to replace with API calls is in `lib/state/app_state.dart`; each method there maps to a backend endpoint.
Fonts download from Google Fonts on first launch (like the web app); without internet the first time, the phone's default font is used until it has been online once.
