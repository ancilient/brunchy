# Phase 7 - Force Stop (Emergency Stop) Design

## 1. Problem

At rush time a stall needs one unmistakable control for a real operational failure: gas cut, power failure, food shortage, or another incident. The current app has some emergency-stop model and storage code, but it is not wired into the dashboard, the order workflow, or the repository contract; it therefore cannot safely claim that it has stopped orders or refunded anyone.

The Phase 7 control must be a domain operation, not merely a red UI button. After the vendor confirms a required reason, the stall becomes **CLOSED** and the same decision must govern every order path. Queued/not-started paid orders are cancelled and refunded automatically; preparing orders remain visible for an explicit per-order choice to finish or cancel-and-refund; ready orders remain collectable through the existing 3-digit handover flow. While stopped, incoming paid orders must not enter Preparing and the capacity queue must not auto-promote. The vendor receives a clear summary such as “3 cancelled and refunded, 2 need your choice.”

Phase 7 also completes the routine operating controls that share the same stall-status state: Pause for 10, 15, or 30 minutes with auto-resume; Close for today; Reopen after a stop. All controls and cancellation/refund decisions need an auditable timestamp and staff ID. In the mock app, the repository is authoritative for these effects and every future backend call will be explicitly marked.

### Scope and required outcomes

- Dashboard: a minimum-48dp red **Emergency stop + refund** action and a stateful closed banner/control.
- Confirmation: exactly `Gas cut`, `Power failure`, `Shortage`, and `Other`; `Other` requires non-blank detail.
- Order effects: atomic mock result with auto-cancel/refund counts and an explicit preparing-order worklist; ready orders untouched.
- Exception actions: `Cancel and refund` must require one of `OUT_OF_STOCK`, `KITCHEN_ISSUE`, or `STALL_EMERGENCY`.
- Normal controls: Pause (10/15/30 minutes and automatic expiry), Close for today, and Reopen.
- Safety: no capacity promotion or newly accepted order while the stall is closed; all state survives restart and has loading, error/retry, and offline-queued behaviour.

### Assumptions

- The app continues to use its mock repository until the backend exists; “refund” means a mock order state update and an explicitly marked future API call, not a real payment operation.
- A “not-started” order is an order in the current queued/placed status; Preparing means accepted; Ready means ready.
- The existing 3-digit code remains valid for Ready orders until a successful handover.
- The supplied defaults continue to apply: 3-digit codes are 100-999, students are shown by first name, and new-item approval is on in the mock.

## 2. Technical plan

### 2.1 One authoritative stall-control model

Add a small vendor-facing stall-control model with an explicit mode (`open`, `paused`, `closedForDay`, `emergencyStopped`), optional `pausedUntil`, an emergency record, and audit entries. The model will live beside the existing data models; it will not be encoded as unrelated SharedPreferences booleans. This makes ordinary Pause/Close, Emergency Stop, and Reopen mutually exclusive and lets the UI describe the actual reason a stall cannot take orders.

The repository will expose one `StallControlRepository` interface, implemented by a mock repository. Its emergency command returns an `EmergencyStopResult` in one operation: the resulting control state, automatically refunded queued orders, and the still-preparing orders needing a choice. Reopen, pause, close-for-day, and a per-order cancellation/refund will be separate commands. Future call sites will use stable `TODO(BACKEND-API)` markers; no UI code will talk directly to local storage or mutate orders.

### 2.2 Order and capacity-gate integration

`OrdersCubit` will receive the control repository/state and use it as a hard gate:

- A realtime paid order remains queued whenever the stall is not `open`; it never calls `acceptOrder`.
- `_autoPromoteQueueIfNeeded`, `fireBatch`, `readyBatch`, and a direct accept attempt will first refuse action when closed or paused, with a clear state-specific message.
- Emergency stop asks the mock repository to refund placed/queued orders and returns accepted/preparing orders unchanged for the decision list. It must never touch ready or collected orders.
- Cancelling a preparing order from that list uses the existing order mutation path with the required Phase 7 cancellation reason. Finishing it simply leaves it available to be marked Ready.
- Reopening enables later capacity promotion only after the vendor explicitly resumes normal flow; it does not silently process orders during the stop command.

The mock repository owns the mutations and emits the same order-stream updates that a backend would emit. This prevents the current split-brain behaviour where the emergency cubit stores a flag without changing the actual order source.

### 2.3 State and UI flow

Replace the disconnected `EmergencyStopCubit` storage implementation with a `StallControlCubit` that loads, executes, and retries repository commands. The Dashboard consumes it to show:

1. An always-visible red `Emergency stop + refund` button when open, with a confirmation dialog. The dialog requires one of the four agreed reasons and requires a detail field only for Other.
2. A closed-state banner with the reason, time, cancellation summary, and a button to review preparing orders.
3. A preparing-order decision sheet with only **Finish order** and **Cancel and refund**. The latter opens a required reason picker limited to the three specified reason codes.
4. Pause controls (10/15/30), Close for today, and Reopen, each with confirmation where a paid-order outcome can change.

Orders retains its existing list and handover UI, but receives the shared closed banner plus disabled/guarded cooking actions. Ready cards and the existing 3-digit handover remain enabled during a stop.

### 2.4 Persistence, offline, and audit behaviour

The repository writes the complete control state and append-only audit entries to the existing local persistence service for mock-mode restart recovery. Each entry has action, before/after mode, time, staff ID, reason/detail when applicable, and affected-order IDs/counts. Reopen appends an entry; it never clears historical records.

When offline, a control command or refund action is queued with a generated idempotency key and shown as **Pending sync**, rather than reported as a completed backend refund. The mock will apply it optimistically only when that is reversible; otherwise it holds the operation pending and exposes retry. This keeps the contract safe for a later real backend, which must make each emergency command idempotent.

## 3. Alternatives considered

### Keep and wire the current `EmergencyStopCubit`

Rejected. Its state is based on direct local-storage reads/writes and it does not alter `MockOrderRepository`, gate `OrdersCubit`, or produce the required preparing-order decision list. Wiring UI around it would display a stop that the order source could immediately contradict.

### Put all stall controls directly on `OrderRepository`

Rejected. Order actions and stall-level operational state have different lifecycles, payloads, and future backend paths. A separate `StallControlRepository` keeps the API seam clear while `OrdersCubit` remains its consumer for the few order effects. Both mock repositories will share the same in-memory state/stream so their view cannot diverge.

### Cancel preparing orders automatically

Rejected by the product rule. Preparing food may already be usable, so the vendor must explicitly decide whether to finish it or cancel/refund it. Only placed/queued orders are automatically refunded. Ready orders remain collectable and cannot be cancelled by the stop workflow.

### Block the entire app with a full-screen closed overlay

Rejected. It could prevent the vendor from reviewing preparing orders or handing a Ready order to a student. A persistent, high-contrast closed banner plus guarded actions communicates the stop without breaking the limited work that must continue.

### Automatically promote every queued order when Reopen is tapped

Rejected. Reopen is the explicit act that returns the stall to an open state, but immediately filling all capacity could surprise a vendor recovering from an incident. After confirmation the existing capacity rule may resume promotion up to the configured limit; it will never promote while the stop is active. This preserves the Phase 4 capacity contract and makes the recovery point deliberate.

### Treat offline refund as complete

Rejected. A local device cannot refund money. Offline UI will distinguish a locally recorded/queued request from a completed backend refund, retain retry metadata, and use an idempotency key when it is eventually sent.

## 4. Files to change

| File | Change |
| --- | --- |
| `lib/data/models/stall_control.dart` | New immutable mode, pause, emergency-result, and audit-entry data types. |
| `lib/data/models/cancel_reason.dart` | Confirm the three Phase 7 cancellation reasons are available and expose only the permitted subset for this flow. |
| `lib/data/repositories/stall_control_repository.dart` | New abstraction for status loading and control commands; every method declares its future backend API marker. |
| `lib/data/mock/mock_stall_control_repository.dart` | New source of truth for mock stall control, audit entries, control persistence, and emergency result calculation. |
| `lib/data/repositories/order_repository.dart` | Keep normal per-order cancellation but document the Phase 7 idempotency/API marker where needed; do not add direct stall-state mutations. |
| `lib/data/mock/mock_order_repository.dart` | Expose only the repository-supported order updates/events needed by the control repository; no UI-owned mutation. |
| `lib/services/local_storage_service.dart` | Replace emergency-specific preference fragments with serialized stall-control/audit/pending-command storage and a migration read for current mock data. |
| `lib/features/stall_control/stall_control_cubit.dart` and `stall_control_state.dart` | New loading, ready, action-in-progress, error/retry, and offline-pending state. |
| `lib/features/stall_control/widgets/*.dart` | New confirmation dialog, closed banner, control panel, preparing-order decision sheet, and cancellation-reason dialog. |
| `lib/features/dashboard/dashboard_screen.dart` | Host the emergency control and routine-control panel/banners without compromising responsive analytics. |
| `lib/features/orders/orders_cubit.dart` | Gate receipt/promotion/batch/direct-start actions through shared control state and refresh from repository events. |
| `lib/features/orders/orders_screen.dart` | Render the closed/paused status, disable unavailable actions, and open the preparing-order decisions. |
| `lib/features/home/home_screen.dart` | Provide the shared control cubit high enough in the widget tree for Dashboard and Orders. |
| `lib/injection_container.dart` | Register the new mock repository/cubit and connect the shared mock repositories. |
| `lib/core/constants/app_strings.dart` | Centralize all new vendor-visible English strings. |
| `test/unit/stall_control_repository_test.dart` | New mock emergency, pause, close, reopen, audit, and idempotency tests. |
| `test/unit/orders_cubit_stall_control_test.dart` | New closed-state capacity-gate tests. |
| `test/widget/emergency_stop_flow_test.dart` | New dialog, summary, preparing decision, Ready handover, and responsive UI tests. |

The legacy `lib/features/emergency_stop/` implementation and `lib/data/models/emergency_stop_model.dart` will be removed only after the replacement has tests and the new control state has been wired. The unrelated `design_docs/phase7_emergency_stop.md` is an earlier draft; the maintained design source will be this file in `docs/design/`.

## 5. Data model and API boundary

### `StallControlState`

| Field | Type | Meaning |
| --- | --- | --- |
| `stallId` | `String` | Scoped stall identifier. |
| `mode` | `StallOperatingMode` | `open`, `paused`, `closedForDay`, or `emergencyStopped`. |
| `pausedUntil` | `DateTime?` | Server/mock time at which a timed pause expires. |
| `closedAt` | `DateTime?` | When Close or Emergency Stop took effect. |
| `emergencyReason` | `EmergencyStopReason?` | `gasCut`, `powerFailure`, `shortage`, or `other`. |
| `emergencyDetail` | `String?` | Required non-empty detail only for `other`. |
| `pendingSync` | `bool` | The device has an offline command awaiting backend confirmation. |
| `auditEntries` | `List<StallControlAuditEntry>` | Append-only local mock audit history. |

### Command results

`EmergencyStopResult` contains the new `StallControlState`, `cancelledAndRefundedOrderIds`, `preparingOrderIds`, and a generated idempotency key. The UI uses the actual returned lists to show the summary; it never derives refund counts from whatever happens to be visible in an order tab.

`StallControlAuditEntry` contains `id`, `action`, `occurredAt`, `staffId`, `previousMode`, `nextMode`, optional reason/detail, optional affected order IDs, and `syncStatus`. The model intentionally records action facts, not student names or payment data.

### Future API markers

The final implementation will use the same API IDs in code and Phase 9 documentation:

- `API-022 POST /stalls/{stallId}/pause`
- `API-023 POST /stalls/{stallId}/close`
- `API-024 POST /stalls/{stallId}/emergency-stop`
- `API-025 POST /stalls/{stallId}/reopen`
- `API-026 GET /stalls/{stallId}/status`
- `API-027 POST /orders/{orderId}/cancel-refund`

Every command includes an idempotency key. The mock names and returns those keys now so switching to a real transport remains a repository replacement rather than a UI rewrite.

## 6. Edge cases and handling

- **Repeated emergency-stop tap:** disable while the command is in progress; the repository also treats the same idempotency key as one operation.
- **Stop already active after restart:** hydrate the existing control state and show it; do not repeat cancellations or overwrite its audit reason.
- **Pause expiry:** resolve expiry against repository/mock time whenever state is loaded or an order action is attempted, append an auto-resume audit entry, then allow normal capacity behaviour.
- **Closed/paused incoming order:** retain it as queued; neither a realtime handler nor batch control can promote it before the explicit reopen/expiry.
- **A preparing order changes to Ready during the decision flow:** re-read state before cancellation; remove the decision item and preserve the Ready order.
- **An order is already refunded/collected:** no second refund; report an idempotent no-op/reconciled outcome rather than failing the complete stop.
- **Other reason has only whitespace:** validation blocks confirmation.
- **Offline after a stop command:** show pending sync and retain the local audit/command; do not claim payment settlement is complete. Retry keeps the same idempotency key.
- **Very narrow or large-text display:** controls stack with 48dp targets; long reasons and status text wrap/ellipsis safely, and the Ready handover control remains available.
- **Concurrent backend correction after reconnect:** repository refresh wins; UI displays the reconciled status and audit result rather than applying a second local transition.

## 7. Tests and verification

Unit tests will prove that an emergency stop refunds only placed/queued orders, leaves Preparing for explicit choice, leaves Ready/Collected intact, suppresses promotion while stopped, writes audit records with staff ID/time, validates the four emergency reasons, and keeps cancellation reasons limited to the three specified values. They will also cover pause expiry, close-for-day, reopen, duplicate idempotency keys, and offline pending/retry behaviour.

Widget tests will exercise the required reason dialog, Other validation, red dashboard control, closed summary, preparing-order choices, Ready handover availability, and no-overflow behaviour at 320dp and text scale 2.0. Integration-level cubit tests will cover realtime arrivals, capacity/batch actions during every non-open mode, and recovery after restart.

Before marking Phase 7 done, run `flutter analyze` with zero issues and the full Flutter test suite. The final check will include the existing 100-order simulation: stop during queued/preparing/ready orders, confirm no new promotion during the stop, select outcomes for preparing orders, reopen, and confirm the configured capacity resumes normally. The implementation report will state the exact files changed, commands/test results, and assumptions.

## 8. Independent review resolutions

The Goldfish review identified implementation blockers. This revised design accepts them as follows:

1. **Atomic order ownership:** the mock order repository will own one bulk `emergencyStopAndRefundPlaced` operation, including state mutation and events. Stall control delegates to that one operation rather than looping through public cancellation calls. The real backend replacement must expose the equivalent atomic command.
2. **Repository enforcement:** every mutating order operation receives the current stall-control guard. UI/cubit guards remain only for fast feedback. `acceptOrder` requires a placed order and an open stall; `markReady` requires an accepted order and permits it during any control mode so a vendor can finish a preparing order; handover continues to require Ready; cancellation during the emergency worklist is limited to accepted orders and the three approved reasons.
3. **Mock restart consistency:** order mutations and stall control are persisted as one mock operational snapshot. If that storage is unavailable/corrupt, the mock starts from a known seed state and records no false audit/reconciliation claim.
4. **Offline commands:** each pending command has `id`, `idempotencyKey`, action payload, retry count, and state. A connection source triggers sequential retry; an acknowledgement removes only that command, never the full queue.
5. **Pause lifecycle:** `StallControlCubit` owns a cancellable timer based on an injected/repository clock and publishes the auto-resumed state/audit entry at expiry. It invokes normal capacity promotion only after that explicit transition.
6. **Action-by-mode matrix:**

| Action | Open | Paused | Closed for day | Emergency stopped |
| --- | --- | --- | --- | --- |
| Receive/accept/auto-promote/batch fire | Allowed | Queue only | Queue only | Queue only |
| Mark a Preparing order Ready | Allowed | Allowed | Allowed | Allowed (Finish) |
| Ready handover | Allowed | Allowed | Allowed | Allowed |
| Emergency worklist cancellation | N/A | N/A | N/A | Accepted only; approved reason required |
| Ordinary direct cancellation | Placed/Accepted only | Placed/Accepted only | Placed/Accepted only | Placed/Accepted only; never Ready |

7. **Scoped commands and lifecycle:** every control call requires the current authenticated stall/staff context. A missing context is an error, not `vendor_unknown`. The shared control cubit will be provided at the router shell; mock repository stream ownership remains solely with the existing realtime service.
