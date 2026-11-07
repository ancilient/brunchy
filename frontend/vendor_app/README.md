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
- Flutter SDK `>=3.6.0` (Tested on Flutter 3.27.3, Dart 3.6.1)
- Android SDK installed & configured
- Java 17+

### Running the App
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run unit and widget tests
flutter test

# 3. Launch on connected Android device or emulator
flutter run
```

### Local mock data
- **Vendor Login:** Enter any vendor name and 10-digit phone number (e.g. `9876543210`). Select either canteen.
- **Stall Selection:** Pick any stall (e.g. `Burger Point`).
- **Student code:** The pre-loaded ready order uses counter code `104`.
- Automatic and burst order simulation are not included in release builds.
