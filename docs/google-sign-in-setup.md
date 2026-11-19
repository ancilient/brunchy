# Google Sign-In setup (one time, about 10 minutes)

Both apps sign in with Google (free; it replaced phone + OTP because SMS costs money). Google needs to know the apps
and the server, so we create **one Google Cloud project** with **three OAuth clients**. Do this signed in with
**the project's Google account** (ask the team lead). Nothing here costs money and no billing account is needed.

What you end up with:

| OAuth client | Type | Used by |
|---|---|---|
| Brunchy server | Web application | The backend checks sign-ins against this ID (`GOOGLE_CLIENT_IDS`); the apps ask Google for tokens for it |
| Brunchy student app | Android | `com.ancilient.brunchy` + signing-key SHA-1 |
| Brunchy vendor app | Android | `com.brunchy.brunchy_vendor` + signing-key SHA-1 |

---

## 1. Create the project
1. Open https://console.cloud.google.com and sign in with **the project's Google account** (ask the team lead).
2. Top bar → project picker → **New project** → name **Brunchy** → **Create**. Make sure **Brunchy** is selected in the top bar afterwards.

## 2. Set up the consent screen (what users see when they sign in)
1. Left menu → **APIs & Services → OAuth consent screen** (newer consoles call it **Google Auth Platform**). Click **Get started**.
2. **App name:** `Brunchy` · **User support email:** <project Google account> → Next.
3. **Audience:** **External** → Next.
4. **Contact information:** <project Google account> → Next → agree to the policy → **Create**.
5. Go to **Audience** (or "Test users") → **Add users** → add every Google account that should be able to sign in
   while the app is in testing: <project Google account>, your personal Gmail (for the student app), and your
   teammates' accounts. Up to 100 test users. *(Before the pilot, click **Publish app**; Brunchy only asks for
   name + email, which needs no Google review.)*

## 3. Create the Web client (for the server)
1. **APIs & Services → Credentials** (or Google Auth Platform → **Clients**) → **Create credentials → OAuth client ID**.
2. **Application type:** Web application · **Name:** `Brunchy server` · leave the URI fields empty → **Create**.
3. Copy the **Client ID** (looks like `1234567890-abc...xyz.apps.googleusercontent.com`). You don't need the
   client secret. This ID is not secret; it goes into the backend settings in step 5.

## 4. Create the two Android clients (one per app)
Each Android client links a package name with the SHA-1 fingerprint of the key that signs the APK.

For **debug builds on this PC** (what `flutter run` uses), the fingerprint is:
```
SHA-1: ED:4C:83:02:A0:46:77:82:A7:31:27:CB:9E:F1:C7:83:47:3D:29:73
```
(Every computer has its own debug key. A teammate gets theirs with the command in "Other computers" below and adds
it as one more Android client.)

1. **Create credentials → OAuth client ID** → **Application type:** Android
   - **Name:** `Brunchy student app (debug)` · **Package name:** `com.ancilient.brunchy` · **SHA-1:** the value above → **Create**.
2. Again → Android
   - **Name:** `Brunchy vendor app (debug)` · **Package name:** `com.brunchy.brunchy_vendor` · **SHA-1:** the same value → **Create**.

The apps never contain these Android client IDs; Google matches the app by package name + signature.

## 5. Turn it on in the backend
In `backend/.env`:
```
GOOGLE_CLIENT_IDS=<the Web client ID from step 3>
```
Restart the backend (`Ctrl+C`, then `npm run dev`). Check http://localhost:4000/api/v1/auth/options shows
`"google": true`. The apps read the Web client ID from there, so they need no rebuild.

## 6. Register the vendor's Google account
A vendor can only sign in with the Google account registered for their stall:
```
cd backend
npm run vendor:email -- 1 <project Google account>     # stall 1 = Burger Hub
```
Any other Google account that signs in to the **student app** becomes a student. One Google account is either a
student or a stall, not both, so test the student app with a different account (e.g. your personal Gmail).

## 7. Try it
1. Backend running, phone connected, `adb reverse tcp:4000 tcp:4000`.
2. Vendor app → **Sign in with Google** → pick <project Google account> → Burger Hub's order board opens.
3. Student app → **Sign in with Google** → pick your other account → choose canteen → order.

---

## Troubleshooting

| Message / symptom | Fix |
|---|---|
| "Google sign-in is not set up on the server yet" | `GOOGLE_CLIENT_IDS` is empty in `backend/.env`, or the backend wasn't restarted. |
| Account picker closes straight away, or "Google sign-in did not work on this phone" | The Android client is missing or wrong: package name and SHA-1 must match exactly (step 4). Changes can take a few minutes to apply. |
| "Access blocked: Brunchy has not completed the Google verification process" / "app is in testing" | Add that Google account as a test user (step 2.5), or publish the app. |
| "Google sign-in failed. Please try again." (from the server) | The token was issued for another client: `GOOGLE_CLIENT_IDS` must be the **Web** client ID of the same project. |
| Vendor app: "This Google account is not registered to a stall" | Run `npm run vendor:email -- <stallId> <email>` (step 6). |
| Student app: "This account belongs to a stall" | That Google account is a vendor; use another account for the student app. |

## Other computers and release builds
- **Teammate's computer:** they print their debug SHA-1 and you add one more Android client per app with it:
  ```
  "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
  ```
- **Play Store builds:** add Android clients with the SHA-1 of the release (upload) key, and the one Play Console
  shows under *App integrity → App signing*.
- **Without any of this:** keep `DEV_LOGIN=true` in `backend/.env` and use the "Continue as demo …" button
  (development only).
