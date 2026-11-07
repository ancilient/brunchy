# Production-Readiness Remediation Design

## 1. Problem

The nine-phase audit found that the app has substantial working functionality but is not production-ready: every phase has at least one unmet acceptance criterion, the static analyzer reports errors in obsolete emergency-stop/local-storage code, and the backend handoff contract is incomplete. Passing widget/unit tests does not compensate for a build that cannot meet its analyzer gate or for flows that can violate capacity, stall scoping, code uniqueness, or operational-stop rules.

The remediation must fix the actual sources of truth, not conceal findings with UI-only guards. Order mutation rules need repository enforcement; session cleanup and counter-code lookups need correct scope; emergency controls need one supported implementation; responsive/accessibility requirements need full-screen tests; branding needs native as well as Flutter splash coverage; and documentation/API markers must correspond exactly to real call sites.

The target is a release candidate that satisfies the original nine-phase acceptance brief: zero `flutter analyze` issues, passing tests, a reliable mock repository boundary with every future API seam explicitly marked, safe vendor control flows, and Android/iOS branding assets that build from this repository. Real payment, backend sync, and refund settlement remain backend-owned and will be represented as validated mock contracts rather than fabricated production payment behavior.

### Remediation scope

- Remove or migrate obsolete emergency-stop code so there is one tested stall-control implementation.
- Repair every audit finding in Phases 1-9, including the global static-analysis failures.
- Add regression tests for the full dashboard, session cleanup, code scope/idempotency, capacity bypass, stock/photo behavior, emergency decisions, native branding configuration, and API-marker/document consistency.
- Keep API traffic behind repository interfaces and add no secrets or direct backend calls.

### Assumptions

- The backend remains unavailable; mock effects are clearly labelled and real refund completion is never claimed locally.
- The current product decisions remain unchanged: 3-digit codes 100-999, first-name display, manager approval on in mock mode, and no QR/camera handover.
- “Production-ready” here means a clean, buildable client release candidate and backend-ready contract, not permission to process real student payments without the backend, compliance approval, and real-device acceptance testing.

## 2. Technical remediation plan

### Foundation and safety first

1. Delete the obsolete `features/emergency_stop` path and migrate any still-needed persistence into the supported stall-control implementation. Repair local-storage parsing/nullability errors, then make `flutter analyze` the non-negotiable first gate.
2. Make `MockOrderRepository` the single order-state authority: stall-scoped lookup, guaranteed active-code allocation with explicit exhaustion handling, durable mock snapshot/reset behaviour, and idempotent handover result semantics.
3. Inject stall-control state into all order mutation paths. The repository, not only `OrdersCubit`, will reject acceptance/promotion while paused/closed/stopped; direct “Move to Preparing” will be removed from the normal flow.

### Phase 1-3 repairs

- Use the app typography constants for all dashboard/vendor body text at 14sp or above. Add full `DashboardScreen` responsive tests across the required widths/scales, including period controls, status cards, top items, peak hours, loading/empty/error/offline states.
- Clear dated stall-session keys on logout; preserve the mock picker only behind a non-release debug configuration; bind session identity to its single assigned stall and remove user-driven cross-stall switching from normal vendor settings.
- Scope lookup and uniqueness by stall, make handover retry return an idempotent already-collected result, and queue only genuine network failures with a stable action ID. A queued handover reserves/uses the local code state so it cannot create duplicate handovers.

### Phase 4-6 repairs

- Remove direct acceptance from the normal order card and make all starts follow capacity/batch promotion. Add tests that prove capacity cannot be exceeded by UI or repository calls.
- Implement real long-press stepper repeat and reset-daily-stock confirmation. Use a validated local image pipeline for a WebP asset capped at 150KB or an explicit placeholder; do not describe a PNG as compressed WebP. Keep price changes pending rather than changing the live price before approval.
- Render average prep time, make period-specific chart labels correct, and provide distinct loading/empty/error-retry/offline states per analytics card. Add full-screen responsive regressions.

### Phase 7-9 repairs

- Add a Preparing-order resolution sheet after emergency stop: each order gets Finish or Cancel and refund with only `OUT_OF_STOCK`, `KITCHEN_ISSUE`, `STALL_EMERGENCY`; enforce codes exactly. Stop must refund only paid queued orders and produce a reconciled summary. Implement durable queued-command retry/ack records.
- Use the supplied badge on Login and native Android/iOS launch screens. Verify native resources rather than relying only on Flutter splash.
- Replace the short API document with a complete contract: each endpoint’s method/path/auth/request/response/errors/idempotency/caller and all realtime events/models. Add exact `TODO(BACKEND-API): API-xx METHOD /path` markers wherever mocks stand in for real requests, and test/document ID consistency.

## 3. Files and verification

Expected changes include `local_storage_service.dart`, `mock_order_repository.dart`, `order_repository.dart`, `orders_cubit.dart`, order/handover/session/dashboard/menu/inventory widgets and tests, the supported stall-control feature, branding/native resource files, `pubspec.yaml`, and both final documentation files. Obsolete emergency-stop files will be removed only after all imports and persistence migration tests pass.

Verification will run after each coherent repair: targeted unit/widget tests, full `flutter test`, full `flutter analyze`, Android build, icon/native-splash resource inspection, API-marker search, and a final fresh Goldfish audit using `docs/design/all-phases-audit-brief.md`. The implementation report will list residual backend-only assumptions explicitly.

## 4. Goldfish review resolutions and frontend boundary

This is a Vendor-app frontend release scope. The mock repository models contracts and failure states; it does not process payments, own backend scheduling, or claim a refund has settled.

### Authoritative frontend mock coordinator

Introduce a persisted, per-stall `MockVendorStore`, owned by the repository layer. It holds control state, orders, used-code records, audit records, and pending commands in one versioned snapshot. `OrderRepository` and `StallControlRepository` become façades over this store. Every multi-record operation executes synchronously within the store before one repository result/event is emitted. On corrupt storage the store resets to the documented fixture and reports a recoverable mock-data warning; logout clears every key with the vendor-stall prefix.

### Exact command contracts

| Command | Atomic frontend mock effect | Backend seam |
| --- | --- | --- |
| `promoteNext(stallId, capacity, key)` | Validate open mode, FIFO queue and capacity; promote at most one queued order; return counts/queue state. | `TODO(BACKEND-API): API-007 POST /stalls/{stallId}/orders/promote` |
| `emergencyStop(stallId, reason, key)` | Persist closed mode, refund only paid queued orders, audit, preparing worklist, and one idempotent summary result. | `TODO(BACKEND-API): API-024 POST /stalls/{stallId}/emergency-stop` |
| `resolvePreparing(orderId, outcome, reason, key)` | Finish leaves Preparing for Ready action; cancel refunds only the targeted paid Preparing order with permitted reason. | `TODO(BACKEND-API): API-027 POST /orders/{orderId}/cancel-refund` |
| `verifyHandover(stallId, code)` | Scope lookup to stall and return a `HandoverResult` preview state. | `TODO(BACKEND-API): API-011 GET /stalls/{stallId}/handover/{code}` |
| `completeHandover(stallId, orderId, key)` | Atomically mark collected + code permanently used and return `completedNow` or `alreadyCollected`. | `TODO(BACKEND-API): API-012 POST /orders/{orderId}/handover` |

`HandoverResult` explicitly distinguishes valid, not-ready, already-collected (with time), no-order, cancelled/refunded, completed-now, and pending-sync. Active code allocation is deterministic from 100-999; codes are never reused by the mock for the persisted fixture lifetime. Exhaustion returns a clear unavailable result and creates no duplicate.

Pending offline commands use a durable envelope: `id`, `idempotencyKey`, `type`, `stallId`, `orderId`, payload, status, attempts, createdAt, and lastError. Only a classified transport failure queues an envelope. The store persists the optimistic local result before showing Pending sync; reconnect retries sequentially, removes only acknowledged command IDs, and reconciles an idempotent conflict with the stored command result.

### Criterion-to-test release matrix

| Phases | Frontend repair and release proof |
| --- | --- |
| P1 | Full DashboardScreen parameterized widget suite: 320/360/411 × 1.0/1.3/2.0 and loaded/loading/empty/error/offline fixtures; body-font assertions >=14sp; all chart/period labels visible. |
| P2 | Vendor-stall prefix cleanup test; logout confirmation/return-to-login test; fixed single-stall identity in release configuration; restart-session test. |
| P3 | Stall-scoped lookup, permanent used-code/exhaustion, structured result, double-completion and offline-envelope tests. |
| P4 | Atomic promotion tests for all callers; no manual-start card; FIFO/count/wait/batch/overload/burst/100-order assertions. |
| P5 | Long-press/type/reset/add/edit/approval test suite; validated WebP compressor service with <=150KB result or explicit placeholder/error state. |
| P6 | Render average prep; period-correct labels; every analytics card has loading/empty/error-retry/offline fixture and matrix test. |
| P7 | Stop transaction/retry/audit test; Preparing decision sheet; exact reason-code test; pause expiry/background hydrate/close/reopen/non-promotion tests. |
| P8 | Login/Flutter splash/native Android 12 resources/iOS storyboard asset checks; adaptive safe-zone/dimension assertions; Android build inspection. |
| P9 | Complete API inventory and Markdown endpoint schema; test that every mock seam has exactly one matching `TODO(BACKEND-API)` marker and document API ID. |

### Analyzer and native release gates

Record the current analyzer diagnostic list, remove obsolete emergency code only after store migration tests, and resolve every remaining error, warning, and info until `flutter analyze` returns zero diagnostics. Native branding verification checks generated Android adaptive-icon XML, Android 12 splash drawable/theme, iOS asset catalog plus LaunchScreen storyboard, and image dimensions/alpha without recolouring or stretching the supplied badge.

## 5. Final ownership, API, persistence, and release contracts

### One owner and one transaction boundary

`MockVendorStore` is the only persisted operational-state owner. It contains one JSON snapshot per `(schemaVersion, vendorId, stallId)` at key `vendor_store_v1_<vendorId>_<stallId>`. The snapshot has `orders`, `control`, `usedCounterCodes`, `audit`, `pendingCommands`, and `lastCommandResults`. Repository façades never retain a second order/control cache. A store `transaction<T>` copies the snapshot, applies all validation/mutation, writes the replacement snapshot once, then returns one immutable result; repository events are emitted only after the write succeeds. This is the sole atomicity/crash boundary for promotion, handover, and emergency stop.

Migration reads existing legacy keys once, writes the v1 snapshot, records `migratedFromLegacy: true`, then removes exactly the known legacy keys. Logout removes every `vendor_store_v1_<vendorId>_` key, every dated `stall_YYYY-MM-DD` key, and queued action keys. Corrupt snapshot JSON resets only that vendor/stall to stable fixtures and exposes a mock-data recovery message; it never silently claims a refund or handover outcome.

### Canonical command signatures

```
promoteNext({stallId, capacity, staffId, idempotencyKey})
emergencyStop({stallId, staffId, reason, detail, idempotencyKey})
resolvePreparing({stallId, staffId, orderId, outcome, cancelReason, idempotencyKey})
verifyHandover({stallId, code})
completeHandover({stallId, staffId, orderId, idempotencyKey})
```

All validate authenticated stall scope, order status, `isPaid`, and command idempotency inside the store transaction. `Finish` is an explicit no-refund acknowledgement that keeps the order Preparing; only its normal Ready action changes status. `Cancel` is accepted only for a paid Preparing order and one of exactly `OUT_OF_STOCK`, `KITCHEN_ISSUE`, `STALL_EMERGENCY`. Counter codes are unique among active orders and become permanently used in the persisted mock fixture after collection; code exhaustion returns `counter_code_capacity_reached` rather than reusing a value.

Pending command replay is FIFO by `createdAt`; a later command for the same order cannot replay before its earlier command is acknowledged or terminally reconciled. Transport failure is the only queueable failure. Each acknowledgement removes its own `id`; an idempotency conflict uses `lastCommandResults[key]`; a non-transport rejection becomes terminal with its backend/mock error and leaves the authoritative snapshot unchanged.

### Canonical API-ID migration

Phase 9 will first produce one registry table from every repository method, then update every code comment, TODO marker, and contract entry in the same change. Existing bracket comments are replaced, not reused. IDs are stable: API-01..04 auth; API-05 order list; API-06 realtime; API-07 capacity promotion; API-08 reject; API-09 ready; API-10 batch; API-11 handover verify; API-12 handover complete; API-13..17 products/inventory; API-18 analytics; API-19 device token; API-20 normal cancel; API-21 unready; API-22 pause; API-23 close; API-24 emergency stop; API-25 reopen; API-26 status/audit; API-27 preparing cancel-refund. Every mock call gets exactly one `TODO(BACKEND-API): API-xx METHOD /path` line, including auth/menu/inventory/dashboard/realtime.

### Deterministic native and analyzer gates

The Android release check requires `values-v31/styles.xml` to reference a branded splash drawable, adaptive icon XML to reference the transparent foreground plus colour background, and all legacy launcher densities to exist. The iOS check requires `LaunchScreen.storyboard` to reference a branded asset in `Assets.xcassets`, whose alpha/dimensions match the supplied badge without aspect distortion. Tests/script checks assert those files/values. The analyzer baseline is saved before remediation; each diagnostic is assigned to a changed file or explicitly removed with obsolete code, and release requires an empty full `flutter analyze` output plus passing full tests and Android build.

## 6. Final Goldfish corrections - executable contracts

`MockVendorStore` replaces both `MockOrderRepository` state ownership and `MockStallControlRepository` state ownership. There is no `StallControlStore`. The two repositories delegate to the same injected store instance; the legacy emergency feature and preferences are removed after migration.

The store serializes all `transaction` calls through a single in-process async mutex. Initialization loads exactly one versioned JSON snapshot; a write failure retains the previous in-memory snapshot, returns `store_write_failed`, emits no event, and shows no optimistic success. The snapshot schema includes `schemaVersion`, `fixtureVersion`, `revision`, and all vendor/stall state. A migration failure resets to the named fixture version and returns `mock_data_recovered`; tests cover initialization, corrupt data, write failure, migration and restart.

`ingestPaidOrder({stallId, order, idempotencyKey})` is the sole realtime/mock upsert command. In one transaction it validates the stall, assigns/reserves the 3-digit code, applies control mode and capacity, then writes either Preparing or FIFO Queued plus position/wait. Direct `acceptOrder` is removed from the public interface and normal UI; `promoteNext` is the only start command. Event payloads carry the post-transaction order, queue counts, store revision, and idempotency key.

Code lifecycle is exact: allocation reserves a code when the paid order is ingested; queued/preparing/ready codes are active; collected burns the code permanently; cancelled/refunded releases it only if it was never handed over. The store retries same-idempotency ingestion by returning its persisted prior result. Exhaustion returns `counter_code_capacity_reached` with no order mutation.

Offline commands are not displayed as complete. The persisted envelope is first saved with `pending`; the UI says Pending sync. Only a successful replay applies the authoritative store/backend mutation and changes it to `acknowledged`. A rejected replay marks it `failed` with a human-readable action, leaves the pre-command snapshot intact, and offers retry/discard. For mock-mode tests, a transport interface injects success, transport failure, or terminal rejection; server revision wins on reconciliation. Commands are FIFO per order and globally ordered by created time.

The canonical interface migration is part of this implementation, not deferred: remove `acceptOrder`; add `ingestPaidOrder`, `promoteNext`, stall-scoped `verifyHandover`, `completeHandover`, `resolvePreparing`, and typed `HandoverResult`. Replace every existing bracket API comment with one canonical `TODO(BACKEND-API)` marker from the API-01..27 registry, update all call sites/tests, and generate the complete Phase 9 API table from that registry.

Pause expiry receives an injected `Clock`; hydrate resolves expiry before emitting state and schedules the next expiry. Background/restart tests advance the fake clock and assert one auto-resume audit entry and subsequent allowed promotion. Native gates require Android build plus generated resource validation, and macOS CI `flutter build ios --no-codesign` with LaunchScreen/storyboard and asset assertions.

## 4. Goldfish review resolutions

