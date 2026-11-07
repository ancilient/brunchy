# Brunchy web prototype (React + Vite + Capacitor)

> **Reference only.** The main student app is the Flutter version in [`../student_app`](../student_app).
> This React version was the first prototype. Keep it for reference; build new features in Flutter.
> Run every command below from this folder (`frontend/web_prototype`).

React + Vite web app wrapped as an Android app with Capacitor 8.

## Build the APK

### Option A: on your computer (one command)
Needs **Node 22+**, **JDK 21** and the **Android SDK**. Installing Android Studio and opening it once sets up the SDK and a JDK 21.

```
npm install
npm run apk
```
The finished app is `Brunchy.apk` in this folder. Copy it to the phone and open it to install (allow "install unknown apps" when asked).
The first build downloads Gradle and Android libraries, so it takes several minutes. Later builds are quick.

If you built this project before with an older Capacitor version, delete the `android` folder first. The script tells you if this is needed.

### Option B: on GitHub (no Android Studio needed)
Open **Actions → Build Web Prototype APK → Run workflow** on GitHub.
When the run finishes, download **Brunchy-prototype-apk** from the run's Artifacts section.

### Try it in a browser
`npm run dev`, then open http://localhost:3000. On a phone-sized window it looks the same as the app.

## Important before giving it to real users
This build is a **working demo**: it has no server.
- **Payment:** tapping Google Pay / PhonePe / the QR button marks the order paid **without charging anything**.
- **Orders:** the order stays on the phone. No stall receives it. "Simulate Kitchen Acceptance" and the hand-over button stand in for the vendor.
- **Login:** the OTP is not sent; any code works (the demo fills in 1234).

Going live needs a backend (orders, stock, vendor app), a payment gateway (Razorpay, Cashfree, etc.) with server-side payment verification, and an SMS OTP provider.
The APK from `npm run apk` is a debug build: it installs on any phone, but the Play Store needs a release build signed with your own key (Android Studio: Build → Generate Signed App Bundle).

## Project layout
```
src/                 the app (React)
src/native.ts        Android back button handling
capacitor.config.ts  app id (com.ancilient.brunchy), name, Android status-bar settings
assets/              app icon and splash images (used when the android/ folder is first created)
scripts/build-apk.mjs   the `npm run apk` script
android/             Capacitor's Android project (generated)
```
Client documents (blueprint PDFs) are in `docs/client-reference/` at the repository root.
