# Orders fixes: stage-1 design

| Bug | Root cause | Proposed fix |
|---|---|---|
| B1 | `orders_screen.dart:626` puts helper/reject inside every card; `_showRejectDialog` has no typed result ownership. | Typed confirm-sheet result; sheet is the only popper, caller shows result SnackBar. Use `canPop`, cream scaffold. |
| B2 | `orders_cubit.dart:224` returns silently when capacity is full; `orders_screen.dart:332` never reports outcome. | Return a batch result; start FIFO to available slots or show capacity-full SnackBar with raise-and-fire action. |
| B3 | `orders_cubit.dart:241-246` suppresses every failure and `orders_screen.dart:348` supplies a queued-batch ID list on Preparing. | Persist batch ID at arrival; enumerate Preparing batch headers; return ready count and show SnackBar. |
| B4 | `_TimerBar` is card-local UI while `mock_order_repository.dart:56` only emits new orders every 45 seconds. No deadline/ticker mutates an order. | Store `autoStartAt` and `overCapacity`; one repository ticker evaluates deadlines, plus resume/reload evaluation. |
| B5 | No repository/local-storage accepting state (`local_storage_service.dart:69` stores capacity only). | Persist per-stall boolean; reject new arrivals; add full-width toggle and stop confirmation. |

## Decisions

**D1:** Event-driven promotion; deadline auto-starts at zero even when full and flags `overCapacity`. No auto-refund. One repository ticker, evaluated on resume/reload.

**D2:** Fire starts FIFO up to capacity or reports full with “Raise to N and fire”. Ready All applies to every Preparing order in its persistent batch and reports its count. Empty batches have no header. Singular label is “1 order”.

**D3:** Per-stall persisted `acceptingOrders`, default ON. Priority: emergency > closed > paused > not accepting > open. OFF refuses arrivals only; existing work continues. Toggle queues offline action. API marker and handover docs will be updated in implementation.
