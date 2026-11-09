# Brunchy Vendor App 🍔

A production-ready Flutter app designed for food stall vendors in college campus canteens.

## Key Highlights
- **High-Efficiency UI/UX:** 44px+ minimum touch targets, high contrast, clean typography.
- **Audio & Speech Notifications:** Plays loud order chimes and speaks order counts via TTS on the alarm audio channel for busy kitchen staff.
- **3-Digit Student Code Verification:** Fast handover verification with clear error feedback and duplicate-collection protection.
- **Real-Time Order Handling:** Automatic 3-minute auto-cancel countdown bar, one-tap accept/ready transitions, and a 5-second undo window.
- **Zero-Friction Stock Tracking:** Auto-populated from yesterday's closing stock with single-tap +/- stepper controls.
- **Sales Analytics Dashboard:** Interactive revenue/order charts, peak rush hours heatmap, top/slow-selling items, and AOV metrics.

## Getting Started

### Prerequisites
- Flutter **3.47** (stable) with the Java bundled in Android Studio. The Android build uses Gradle 9.3.1, AGP 9.1.0
  and Kotlin 2.4.0, the same as the student app.
- Android SDK installed & configured

### Run it against your local backend (default)
The app talks to the Brunchy backend ([`backend/`](../../backend), contract in [`docs/api/openapi.yaml`](../../docs/api/openapi.yaml)).
1. Start the backend: `docker compose up -d` in the repo root, then `npm run dev` in `backend/`.
2. Phone on USB with USB debugging: `adb reverse tcp:4000 tcp:4000`
3. Run the app:
   ```bash
   flutter pub get
   flutter run
   ```
4. Log in with a stall's phone number (seed data): **9000000001** Burger Hub, 9000000002 Juice Corner, 9000000003
   Parotta Point, 9000000004 Chai & Snacks, 9000000005 Grill Point, 9000000006 South Kitchen. In development the
   backend returns the OTP and the app fills it in. The stall comes from the account; there is nothing to pick.

Phone on Wi-Fi instead: `flutter run --dart-define=API_URL=http://<your PC's IP>:4000/api/v1` (allow port 4000 in the firewall).

### What is live and what is still demo data
| Screen | Source |
|---|---|
| Login, Orders board (live over Socket.IO), Accept / Ready / Undo Ready / Reject / Cancel with refund, Handover by code | Backend |
| Menu: switch items on/off, set quantity | Backend (adding items or changing name/price needs the manager-approval flow, not built yet) |
| Inventory: today's quantities; End of day closes the stall | Backend |
| Stall controls: Pause, Close for today, Reopen, Emergency stop (refunds orders not started) | Backend |
| Dashboard figures | Still demo data (no reports endpoint yet) |

### Offline demo mode
`flutter run --dart-define=USE_MOCK=true` runs the original in-memory demo (no backend needed). In that mode any
phone number and the code `123456` log in, and the pre-loaded ready order uses counter code `104`.

### Tests
`flutter test` (they use the in-memory repositories). The 5 tests in `test/regression/orders_fix_regression_test.dart`
fail on purpose until those Orders fixes are made.
