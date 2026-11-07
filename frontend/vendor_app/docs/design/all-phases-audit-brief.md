# Brunchy Vendor - Independent Nine-Phase Audit Brief

Review the repository against these acceptance criteria. Report PASS, PARTIAL, or FAIL with concrete evidence. Do not assume a feature is complete merely because a model, document, or unused widget exists.

## P1 Responsive dashboard
No overflow at 320/360/411dp and text scales 1.0/1.3/2.0; chart labels every 3 hours; no clipped period tabs/card titles; body text >=14sp.

## P2 Session
Visible logout confirmation warns on queued offline actions; logout clears session/stall/canteen and returns Login; vendor has one stall, header shows canteen/stall; mock picker behind mock flag; session persists until logout.

## P3 Handover
3-digit unique active-stall codes only, no QR/camera package; cards show code/items/quantity/first name/amount/paid/time; Handover has keypad and previews Valid/Not ready/Already collected/No order/Cancelled states; Hand over is idempotent, permanently uses code, queues offline action.

## P4 Capacity
Persisted 0-50 capacity, 0 confirmation; new paid order goes Preparing if capacity otherwise FIFO Queued with position/wait; Ready promotes queue; Queued/Preparing/Ready counts; make list, 2-minute fire batches/Ready all; overload levels; single burst alert; ListView; mock 100-order simulation.

## P5 Items
Photo/name/price/veg/stock/on-off/status; large stepper including long press/type/+5/10/20; restock/reset; add/edit/price request; WebP <=150KB; 10+ sample items across 3 categories including low/sold out.

## P6 Analytics
Today/week/month comparisons; revenue/orders/AOV/trend toggle/top items/peak/average prep; each card loading/empty/error-retry/offline; no 320dp/2.0 overflow.

## P7 Controls
Dashboard red Emergency stop + refund with required Gas cut/Power failure/Shortage/Other reason; stalled CLOSED; queued refund; preparing per-order finish/cancel+refund; Ready collectable; summary; cancellation reason codes OUT_OF_STOCK/KITCHEN_ISSUE/STALL_EMERGENCY; pause 10/15/30 auto resume, close/reopen, audit time/staff; stopped queue does not promote.

## P8 Branding
Provided Aqua Burger logo under assets/branding; transparent adaptive foreground safe zone; Android/iOS launcher icons, name Brunchy Vendor, native splash and Login logo; no stretch/recolour.

## P9 Docs/API seams
Both final docs exist and cover all phases; API contract contains frontend tree/screens/state/models/events and all listed API areas with ID/method/path/auth/request/response/errors/idempotency/file/function. Every mock-to-real seam has matching `TODO(BACKEND-API): API-xx METHOD /path` code markers.

Global: null-safe, no secrets, repository boundary, loading/empty/error/offline everywhere, English strings central, zero `flutter analyze` issues, relevant tests including handover/capacity/stepper/emergency/analytics.
