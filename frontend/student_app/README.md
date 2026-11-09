# Brunchy student app (Flutter)

The main student app, connected to the Brunchy backend ([`../../backend`](../../backend), contract in
[`docs/api/openapi.yaml`](../../docs/api/openapi.yaml)). Login, menu, stock, checkout, payment and bill status all come
from the server; the cart and canteen choice stay on the phone. Run every command below from this folder (`frontend/student_app`).

It uses the app id `com.ancilient.brunchy`, the same as the React prototype, so a phone can have only one of them installed.

## Run it against your local backend
1. Start the backend (see [`backend/README.md`](../../backend/README.md)): `docker compose up -d` in the repo root, then
   `npm run dev` in `backend/`.
2. Connect the phone with **USB debugging** and forward the backend port to it (the phone's `localhost:4000` then reaches your PC):
   ```
   adb reverse tcp:4000 tcp:4000
   ```
   `adb` is in `%LOCALAPPDATA%\Android\Sdk\platform-tools`. Run it again after unplugging the phone.
3. Run the app:
   ```
   flutter pub get
   flutter run
   ```
4. Log in with the pre-filled demo student (9876543210). In development the backend returns the OTP, and the app fills it in.

**Phone on Wi-Fi instead of USB:** use your PC's IP address (from `ipconfig`) and allow port 4000 in Windows Firewall:
```
flutter run --dart-define=API_URL=http://192.168.1.10:4000/api/v1
```

**Vendor side while the vendor app is not connected yet:** accept / ready / hand over with the calls in
[`backend/requests.http`](../../backend/requests.http) (Burger Hub vendor phone 9000000001). The student screen updates live.

## Build an APK
Needs **Flutter 3.47** (stable) and **Android Studio**. Run `flutter doctor` once to check.
- **Windows:** double-click `build-apk.bat` · **Mac / Linux:** `./build-apk.sh`
- To point an APK at a server: `flutter build apk --dart-define=API_URL=https://api.example.com/api/v1`

Debug builds may use plain `http://` (for the local backend); release builds need `https://`.

## Where things are
```
lib/api/api_client.dart       HTTP calls, login tokens (auto-refresh), server clock offset; API_URL setting
lib/api/realtime.dart         Socket.IO live updates (bill.updated, order.updated)
lib/api/mappers.dart          server JSON -> the app's model classes (and server bill statuses -> screen statuses)
lib/state/app_state.dart      menu, cart, checkout + 5-minute hold, shortage prompt, payment, orders, login
lib/state/menu_data.dart      bundled demo menu, shown only before the first successful load from the server
lib/main.dart                 app shell: header, bottom tabs, popups, Android back button
lib/screens/                  one file per screen group
lib/ui/                       colours, fonts and icons
```

## Not connected yet
- **Payment** uses the backend's mock gateway (no money moves). Razorpay comes in a later milestone.
- **Push notifications** (FCM) and the **SMS** for the OTP come later; live updates work while the app is open.
- Login tokens are kept in shared_preferences; move them to `flutter_secure_storage` before the Play Store release.
