# Brunchy

Campus canteen pre-ordering for Sathyabama University, by Ancilient Technologies.
Students order and pay on their phone, get one bill per stall, and collect their food at the counter with a pickup code.
Stalls receive paid orders and do almost no extra work.

## Repository layout

```
brunchy/
├── frontend/
│   ├── student_app/     Flutter student app (connected to the backend: login, menu, checkout, mock payment, live bills)
│   ├── vendor_app/      Flutter vendor app (connected to the backend: live orders, handover, stock, stall controls)
│   └── web_prototype/   React + Vite + Capacitor prototype of the student app (reference only)
├── backend/             Node.js + Express + TypeScript API (milestone 1: ordering loop works, mock payments)
├── database/            MySQL schema: migrations and seed data
├── docs/                project documents; client PDFs stay local (see docs/README.md)
└── .github/workflows/   cloud builds of the APKs
```

| Folder | Owner | Status |
|---|---|---|
| `frontend/student_app` | Frontend team | Connected to the backend (mock payments) |
| `frontend/vendor_app` | Frontend team | Connected to the backend (dashboard still demo data) |
| `backend` | Backend team | Milestone 1 done: login, menu, checkout, mock payment, bills, handover, live updates |
| `database` | Backend team | Milestone 1 schema + demo seed |

## How the parts connect

```
 Student app ─┐
 Vendor app  ─┼──  HTTPS (JSON) + WebSocket + push  ──▶  backend (Node.js + Express)
 Admin web   ─┘                                              │
                                              ┌──────────────┼───────────────┐
                                            MySQL          Redis       Google Sign-In / Razorpay / FCM
                                     (stock, orders,  (cache,     
                                      money: the truth) job queue)
```
The apps never talk to the database directly. The server decides what is paid, what is in stock and what each pickup code is worth.
The API contract (every request and response) is [`docs/api/openapi.yaml`](docs/api/openapi.yaml), kept by the backend team. Agree on changes there before you code them.

## Tech stack

| Layer | Choice |
|---|---|
| Student and vendor apps | Flutter (Dart) |
| Admin page | Flutter Web (web build of the vendor app) |
| Backend API | Node.js + Express + TypeScript |
| Database | MySQL 8 |
| Cache, rate limits, job queue | Redis + BullMQ |
| Live updates | WebSocket (Socket.IO) |
| Push notifications | Firebase Cloud Messaging |
| Payments | Razorpay or Cashfree (UPI, test mode first) |
| Hosting | One cloud VM + Docker + Nginx |

## Getting started (full setup guide)

This runs the **whole system on your own computer**: MySQL and Redis in Docker, the backend API, and both apps on an
Android phone connected by USB. Commands are for **Windows** (PowerShell or the VS Code terminal); macOS/Linux
differences are noted. Total first-time setup: about 1 hour, mostly downloads.

### How the pieces talk to each other
```
 Your phone (USB)                         Your PC
 ┌──────────────────┐   adb reverse    ┌─────────────────────────────┐   ┌──────────────────────┐
 │ Student app      │ ── localhost: ──▶│ Backend API  :4000          │──▶│ Docker: MySQL  :3307 │
 │ Vendor app       │    4000          │ (npm run dev in backend/)   │──▶│ Docker: Redis  :6379 │
 └──────────────────┘                  └─────────────────────────────┘   └──────────────────────┘
```
On the phone, `localhost:4000` means the phone itself. **`adb reverse tcp:4000 tcp:4000` forwards it over the USB
cable to your PC.** If that link is missing, or the backend is not running, the apps show
*"Cannot reach Brunchy. Check your internet and try again."*

---

### Step 1. Install the tools (once per computer)

| Tool | Version | Get it | Check it works |
|---|---|---|---|
| Git | any | https://git-scm.com/downloads | `git --version` |
| Docker Desktop | latest | https://www.docker.com/products/docker-desktop (enables WSL 2, needs a restart) | `docker --version` |
| Node.js | 22 or newer (LTS) | https://nodejs.org | `node --version` |
| Android Studio | latest | https://developer.android.com/studio (open it once; it installs the Android SDK and its own Java) | |
| Flutter SDK | 3.47 (stable) | https://docs.flutter.dev/get-started/install/windows: unzip to `C:\src\flutter` (**not** inside OneDrive or Program Files) and add `C:\src\flutter\bin` to your PATH | `flutter --version` |
| VS Code (optional) | latest | https://code.visualstudio.com, plus the **Flutter** and **REST Client** extensions | |

Then, in Android Studio: **Settings → Languages & Frameworks → Android SDK → SDK Tools** → tick **Android SDK
Command-line Tools** → Apply. Finally, in a new terminal:
```
flutter doctor --android-licenses      # accept the Android licenses (type y)
flutter doctor                         # Flutter and Android toolchain should show ✓ (Chrome / Visual Studio can be ignored)
```

**Make `adb` work in any terminal (recommended).** Add the Android SDK's `platform-tools` folder to your PATH:
`C:\Users\<you>\AppData\Local\Android\Sdk\platform-tools` (Windows search → "Edit the system environment variables" →
Environment Variables → Path → New). Open a new terminal and check with `adb version`. Until you do this, use the full
path: `"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"` (PowerShell: `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"`).

### Step 2. Get the code (once)
```
git clone https://github.com/ancilient/brunchy.git
cd brunchy
```
Prefer a folder outside OneDrive (for example `C:\dev\brunchy`): OneDrive syncing can lock build files.

### Step 3. Set up the backend and database (once)
Start **Docker Desktop** first and wait until it says "Engine running". Then, from the `brunchy` folder:
```
docker compose up -d          # starts MySQL 8 + Redis (first time downloads the images)
docker ps                     # both brunchy-mysql (healthy) and brunchy-redis should be "Up"

cd backend
copy .env.example .env        # macOS/Linux: cp .env.example .env
npm install
npm run db:reset              # creates all tables and loads the demo canteens, stalls, menu and accounts
npm test                      # optional: 45 tests should pass
```
Open `backend\.env` and replace `JWT_ACCESS_SECRET` and `MOCK_GATEWAY_SECRET` with long random strings
(`node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` prints one). Keep
`DEV_LOGIN=true` and `IGNORE_CANTEEN_HOURS=true` for development.

**Sign in with Google (optional at first).** Both apps sign in with Google. Until the Google Cloud project is set up,
the apps show a **"Continue as demo …"** button (because `DEV_LOGIN=true`), so you can start without it. To turn
Google sign-in on, follow [`docs/google-sign-in-setup.md`](docs/google-sign-in-setup.md) (about 10 minutes), put the
Web client ID in `GOOGLE_CLIENT_IDS=` in `backend\.env`, and register the vendor's Google account for a stall:
```
npm run vendor:email -- 1 <google-account-email>     # stall 1 = Burger Hub
```

### Step 4. Set up the apps (once)
```
cd frontend\student_app
flutter pub get
cd ..\vendor_app
flutter pub get
```

### Step 5. Prepare your phone (once)
1. **Settings → About phone → tap "Build number" 7 times** (Xiaomi: "MIUI version"; Samsung: Software information).
2. **Settings → System → Developer options → turn on "USB debugging"**. OPPO/Realme/OnePlus: also turn on
   **"Disable permission monitoring"**; Xiaomi: also **"Install via USB"**.
3. Connect the phone by USB. On the phone, tap **Allow** on "Allow USB debugging?" (tick "Always allow").
4. Check: `adb devices` must list your phone as `device`. If it says `unauthorized`, unlock the phone and tap Allow.

---

### Every day: run the whole system

**Terminal 1: database + backend** (leave it running)
```
cd brunchy
docker compose up -d
cd backend
npm run dev
```
Wait for `Brunchy API listening on http://localhost:4000/api/v1`. Check in a browser: http://localhost:4000/api/v1/health
should show `{"status":"ok"}`.

**Terminal 2: connect the phone and run an app**
```
adb reverse tcp:4000 tcp:4000         # run again every time you plug the phone in or restart it
adb reverse --list                    # must show: tcp:4000 tcp:4000

cd brunchy\frontend\student_app       # or frontend\vendor_app for the stall app
flutter run
```
The first `flutter run` takes 5–10 minutes (Gradle downloads); later runs about a minute. While it runs: `r` = hot
reload, `R` = restart, `q` = quit. Both apps can be installed at the same time; run one, press `q`, then run the other.

**Sign in**

| App | With Google (after the setup) | Without Google (development) |
|---|---|---|
| Student app | **Sign in with Google** with any Google account that is not a stall's account; the first sign-in creates the student | **Continue as Demo Student** |
| Vendor app | **Sign in with Google** with the account registered for the stall (`npm run vendor:email`) | **Continue as demo vendor (Burger Hub)** |

One Google account is either a student or a stall vendor, not both: test the two apps with two different accounts.

**Try the full flow:** student app → Main Canteen → add a Burger Hub item → Cart → Pay (mock payment, nothing is
charged) → the bill appears on the vendor app's board within seconds → Accept → Ready → in the Handover tab type the
3-digit code the student sees → the student's bill shows *Completed*.

**Without the vendor app:** play the stall from VS Code with [`backend/requests.http`](backend/requests.http)
(REST Client extension), steps 8–12.

**Stop:** `Ctrl+C` in Terminal 1, then `docker compose down` (your data is kept). `docker compose down -v` deletes it.
**Start over with fresh demo data:** `npm run db:reset` in `backend/`.

### Phone on Wi-Fi instead of USB
Phone and PC on the same Wi-Fi. Find your PC's IPv4 address with `ipconfig` (e.g. `192.168.1.10`), allow port 4000
in Windows Firewall (Windows Security → Firewall → Advanced settings → Inbound Rules → New Rule → Port → TCP 4000 → Allow),
then:
```
flutter run --dart-define=API_URL=http://192.168.1.10:4000/api/v1
```
Campus Wi-Fi often blocks device-to-device traffic; a phone hotspot works.

### Installing an APK instead of `flutter run`
`flutter build apk --debug` (or `--dart-define=API_URL=...` for Wi-Fi), then `adb install -r build\app\outputs\flutter-apk\app-debug.apk`.
A debug APK still needs the backend running **and** `adb reverse` (or the Wi-Fi URL). Release APKs only allow
`https://` servers, so they cannot reach a local backend.

---

### Troubleshooting

| Problem | Cause and fix |
|---|---|
| **"Cannot reach Brunchy. Check your internet and try again."** | The phone cannot reach the backend. Check in this order: (1) Terminal 1 shows the backend running and http://localhost:4000/api/v1/health works on the PC; (2) `adb reverse --list` shows `tcp:4000 tcp:4000` (if empty, run `adb reverse tcp:4000 tcp:4000` again, it is lost on every unplug/reinstall/reboot); (3) the app is a **debug** build. Then close and reopen the app. |
| `adb` is not recognized | Add `platform-tools` to PATH (Step 1) or use the full path to `adb.exe`. |
| `adb devices` shows nothing / `unauthorized` | Use a data USB cable, set USB mode to "File transfer", unlock the phone and accept the "Allow USB debugging" prompt. |
| `INSTALL_FAILED_VERIFICATION_FAILURE` / install blocked | Watch the phone and tap **Install** on the prompt; Developer options → turn off "Verify apps over USB", turn on "Disable permission monitoring" (OPPO) / "Install via USB" (Xiaomi). |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | An older Brunchy app with another signature is installed (e.g. the React prototype, same app id). Uninstall it first. |
| `docker compose up` fails / "cannot connect to the Docker daemon" | Start Docker Desktop and wait for "Engine running". |
| Backend: `ECONNREFUSED 127.0.0.1:3307` or Redis errors | Docker containers are not running: `docker compose up -d`, then `docker ps`. |
| Backend: `EADDRINUSE :4000` | Another backend is already running. Close the other terminal (or find it in Task Manager → node.exe). |
| Backend exits with "Invalid backend settings" | `backend\.env` missing or a secret shorter than 16 characters. Repeat Step 3. |
| App: "This canteen is not taking orders right now" | Outside canteen hours (IST). Set `IGNORE_CANTEEN_HOURS=true` in `backend\.env` and restart the backend. |
| App shows an old menu or wrong stock | Close and reopen the app; for a clean start run `npm run db:reset`. |
| `flutter run` builds for Windows / Chrome | Pick the phone: `flutter devices`, then `flutter run -d <id>`; in Android Studio pick the phone in the device dropdown. |
| Gradle / Java version errors | Use Flutter 3.47 and the Java bundled with Android Studio; both apps use Gradle 9.3.1. `flutter clean` then `flutter pub get`. |
| Dart errors like `Error when reading .../Pub/Cache/...` | Run `flutter pub get` again in that app folder (from your own terminal). |
| Vendor app logs straight in to an old stall or shows errors | It kept an old demo session: log out (Settings) or uninstall and reinstall, then sign in again. |
| "Google sign-in is not set up on the server yet" | `GOOGLE_CLIENT_IDS` is empty in `backend\.env` (or the backend wasn't restarted). Use the demo button, or do [`docs/google-sign-in-setup.md`](docs/google-sign-in-setup.md). |
| Google account picker closes at once / "Google sign-in did not work on this phone" | The app's Android OAuth client (package name + this PC's SHA-1) is missing in Google Cloud. See the setup guide, step 4. |
| "Access blocked … app is in testing" | Add that Google account as a test user in Google Cloud (setup guide, step 2). |
| Vendor app: "not registered to a stall" · Student app: "belongs to a stall" | Register the vendor's account with `npm run vendor:email -- <stallId> <email>`; use a different Google account for the student app. |

Then open only the folder for your role and follow its README:

- **Student app:** [`frontend/student_app/README.md`](frontend/student_app/README.md)
- **Vendor app:** [`frontend/vendor_app/README.md`](frontend/vendor_app/README.md)
- **Backend:** [`backend/README.md`](backend/README.md) · **Database:** [`database/README.md`](database/README.md) · **API contract:** [`docs/api/openapi.yaml`](docs/api/openapi.yaml)

Open the app folder itself in Android Studio or VS Code (for example `frontend/student_app`), not the repository root.

## Working together

1. Get the latest code before you start: `git pull`
2. Work on your own branch: `git checkout -b feature/short-description`
3. Commit small steps with clear messages: `git commit -m "Add order history endpoint"`
4. Push your branch: `git push -u origin feature/short-description`
5. Open a pull request into `main` on GitHub. A teammate reviews it, then it is merged.

Rules:
- Don't push straight to `main`.
- Never commit secrets (`.env` files, API keys, keystores). Commit a `.env.example` with placeholder values instead.
- Don't commit build outputs (`build/`, `node_modules/`, `*.apk`). The `.gitignore` already skips them.
- Announce API contract changes in the team chat before merging them.
