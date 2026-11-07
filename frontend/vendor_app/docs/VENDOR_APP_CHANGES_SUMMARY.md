# Brunchy Vendor App - Change Summary

## Phases 1-5

- Responsive dashboard cards, period tabs, compact chart labels, 3-digit counter-code handover, capacity gate, batching, overload state, menu and stock workflows were added to the Flutter mock app.
- Session/logout, a mock stall picker, offline-action storage, repository abstractions, sample menu data, product editing and stock controls are present. The 100-order simulation was removed from the release app for backend handoff.
- The normal handover path is Ready -> 3-digit code verification -> collected. Codes are scoped to active stall orders and become used at handover.

## Phase 6 - Analytics

- Dashboard periods, Revenue/Orders/AOV comparison cards, revenue/orders chart toggle, peak hours, top/slow items, fulfilment split, skeleton loading, error/retry and chart empty state use `DashboardRepository` and `MockDashboardRepository`.
- Known follow-up: average prep time is carried by `DashboardStats` but has not yet been rendered as a dashboard metric; full-screen offline/empty state coverage still needs completion.

## Phase 7 - Stall controls

- Added a shared `StallControlRepository`, mock control state, audit entries, pause, close for day, emergency stop and reopen controls.
- Emergency stop refunds queued orders atomically in the mock, preserves Preparing orders for finish/exception handling, preserves Ready handover, and blocks new acceptance while non-open.
- Test: `test/unit/stall_control_repository_test.dart` covers emergency effect and closed-stall action blocking.

## Phase 8 - Branding

- The supplied Aqua Burger Badge is stored under `assets/branding/`; a transparent foreground version is used for Android adaptive icons and in-app splash/drawer branding.
- `flutter_launcher_icons` generates Android and iOS icons. The app name is `Brunchy Vendor`.

## How to test

1. Run `flutter test` and `flutter analyze`.
2. Open Orders; adjust capacity, fire a batch, and mark orders Ready using the backend-provided orders.
3. On Dashboard, select Emergency stop + refund, choose a reason, verify queued orders refund and Ready orders can still hand over.
4. Build Android and confirm the launcher icon/name and splash badge.

## Assumptions and known gaps

- All repository implementations are mock-only until backend APIs exist. No real payment refund is made by the app.
- Counter codes are 100-999 and the visible student identifier is first name.
- New menu items require approval in mock mode.
- Phase 6 analytics follow-ups and Phase 7 full offline retry persistence remain backend-integration follow-ups.
- Backend endpoint, field, idempotency, pagination and realtime requirements are authoritative in `docs/BACKEND_API_CONTRACT.md`; implementation markers use its API IDs.
