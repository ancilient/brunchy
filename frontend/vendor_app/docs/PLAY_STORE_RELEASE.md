# Play Store release handoff

## Before backend integration

The application ID is `com.brunchy.brunchy_vendor`; keep it unchanged after the first Play upload. Version is `1.0.1+2`. Mock repositories remain a local development fallback only. Before production, replace each registration in `lib/injection_container.dart` with the backend HTTP/WebSocket repository implementation described in `BACKEND_API_CONTRACT.md`.

## Signing

1. Create a private Android upload key and store it outside source control.
2. Copy `android/key.properties.example` to `android/key.properties` and enter the real alias, passwords and key path.
3. Back up the upload key and passwords securely. Losing them delays future releases.

## Build and upload

Run `flutter analyze`, `flutter test`, then `flutter build appbundle --release`. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console Internal testing first. Complete the Play listing, privacy-policy URL, Data Safety form, content rating, target audience, app-access instructions, screenshots and release notes before requesting production rollout.

## Required backend release checks

Use production HTTPS and authenticated WebSocket URLs, enable token refresh/revocation, test idempotent mutations/reconnect replay, verify all timestamps are UTC, and remove mock fallback registration from the production flavor. Do not upload a Play production build until these checks pass.
