# Brunchy Vendor handover

## Run with mock data

Run `flutter pub get`, then `flutter run`. The dependency container currently registers mock repositories for local UI verification; no simulated order generation is included in the release build.

## Switch to backend

Replace each `Mock*Repository` registration in `lib/injection_container.dart` with its HTTP/WebSocket implementation. Preserve repository interfaces and all `TODO(BACKEND-API)` IDs. Use [the API contract](BACKEND_API_CONTRACT.md) as the interface source of truth.

## Required backend behaviour

UTC timestamps; IST presentation; vendor/stall authorization; paginated orders; ordered replayable realtime events; atomic/idempotent handover, refunds, inventory and status updates; 3-digit code uniqueness among active stall orders and permanent invalidation after handover; audit records with staff ID/time.

The backend must persist `accepting` per vendor/stall (`PUT /vendor/stall/accepting`) and refuse newly placed orders when false without interrupting existing orders.

## Frontend assumptions and gaps

Money is INR numeric JSON; API JSON is camelCase. Mock sample data remains only as a fallback until the backend repositories are registered. The production transport must route mutations through its reconnect/idempotency policy. Run backend integration tests before production release.

## Versions

Use the Flutter/Dart versions pinned by the project SDK and `pubspec.lock`; Android release uses the existing Gradle wrapper.
