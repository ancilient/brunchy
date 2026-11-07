# Brunchy Vendor API contract

All paths are versioned by the deployment gateway. JSON uses camelCase. Money is INR number; timestamps are ISO-8601 UTC (`Z`). Protected requests use `Authorization: Bearer <accessToken>` and vendor/stall authorization.

## Endpoint catalogue

| ID | Method/path | Request/response purpose |
|---|---|---|
| API-001 | POST `/auth/login` | `{name,phone,canteenId}` -> `{vendor,accessToken,refreshToken,expiresAt}` |
| API-002, API-003 | GET `/canteens`; GET `/canteens/{canteenId}/stalls` | Lists `{id,name}` and `{id,canteenId,name}` |
| API-004 | POST `/vendor/session/stall` | `{stallId,date,forceTakeover}`; 409 `STALL_ALREADY_CLAIMED` |
| API-005 | GET `/stalls/{stallId}/orders` | Query `date,status,page=1,limit=50`; `{items:Order[],page,limit,total,nextCursor}` |
| API-006 | WS `/ws/stalls/{stallId}/orders` | Authenticated ordered order events |
| API-007, API-008, API-009 | PATCH `/orders/{id}/accept`; PATCH `/orders/{id}/reject`; PATCH `/orders/{id}/ready` | Returns `Order`; reject body `{reason}` |
| API-011, API-012 | GET `/orders/lookup?stallId=&code=`; POST `/orders/{id}/handover` | Lookup active order; atomic handover returns `Order` |
| API-013, API-014, API-015, API-016 | GET/POST/PATCH/DELETE `/stalls/{stallId}/menu[/{itemId}]` | `MenuItem` collection/mutation |
| API-017, API-018, API-019 | GET/PATCH `/stalls/{stallId}/inventory/{date}[/{itemId}]`; POST `/stalls/{stallId}/day/close` | Inventory list/stock mutation; close `{forceClose}` |
| API-020, API-021 | POST `/orders/{id}/cancel-refund`; POST `/orders/{id}/unready` | Cancel body `{reason}`; returns `Order` |
| API-022, API-023 | GET `/stalls/{stallId}/dashboard`; GET `/stalls/{stallId}/dashboard/chart` | Query `period=today|week|month`, chart also `metric=revenue|orders` |
| API-024 | PATCH `/vendor/profile` | `{canteenId}` -> `Vendor` |
| API-025, API-026, API-027, API-028, API-029 | POST `/stalls/{id}/pause|close|emergency-stop|reopen`; GET `/stalls/{id}/status` | Stall control/audit; stop includes `{staffId,reason,detail}` |
| API-030, API-031 | POST `/auth/refresh`; POST `/auth/logout` | Rotated token tuple; revoke + client clear all state |
| API-032 | PUT `/vendor/stall/accepting` | `{accepting:boolean}`; refuses new orders while false |

## Types and enums

`Order`: `{id,billNumber,counterCode,studentFirstName,stallId,items,totalAmount,status,placedAt,acceptedAt?,readyAt?,collectedAt?,isPaid,otpAttempts,otpLockedUntil?,isCodeUsed}`. `counterCode` is a three-character string `100`–`999`; items are `{menuItemId,name,price,quantity}`; status is `placed|accepted|ready|collected|cancelled|refunded`.

`MenuItem`: `{id,stallId,name,price,isAvailable,category?,isComplex,station?,isVeg,stock,imageUrl?,prepMinutes,isPendingApproval,pendingPrice?}`. `InventoryItem`: `{id,stallId,menuItemId,menuItemName,date,openingStock,currentStock,reason}`; reason `sale|restock|waste|spoilage|correction`. Cancellation reason: `OUT_OF_STOCK|KITCHEN_ISSUE|STALL_EMERGENCY`.

Dashboard: `{totalRevenue,orderCount,avgOrderValue,revenueChangePct,orderCountChangePct,aovChangePct,revenueChangeIsNew,revenueChangeIsNone,orderChangeIsNew,orderChangeIsNone,aovChangeIsNew,aovChangeIsNone,chartData,topItems,slowItems,peakHours,statusSplit,avgPrepMinutes}`. Chart point: `{label,revenue,orders}`; top item: `{name,qty,orderCount,revenue}`; peak hour: `{hour,count}`.

Stall modes: `open|paused|closedForDay|emergencyStopped`; audit: `{action,occurredAt,staffId,previousMode,nextMode,reason?,affectedOrderCount}`; emergency reason: `GAS_CUT|POWER_FAILURE|SHORTAGE|OTHER`.

## Mutation, errors, and realtime

Every mutation requires `Idempotency-Key` UUID, scoped to vendor + endpoint + resource. Duplicate in-flight requests wait for the original result; replays return the identical status/body for 24 hours. This covers status, handover, refund, stock, session claim, and stall control.

Errors are `{code,message,details?}`. Codes: `AUTH_REFRESH_INVALID`, `STALL_ALREADY_CLAIMED`, `STALL_NOT_OPEN`, `ORDER_NOT_QUEUED`, `ORDER_NOT_PREPARING`, `ORDER_NOT_READY`, `ORDER_ALREADY_COLLECTED`, `CANNOT_CANCEL_IN_STATE`, `COUNTER_CODE_CAPACITY_REACHED`, `VALIDATION_ERROR`.

Handover is atomic/idempotent: only Ready changes to collected, sets `isCodeUsed=true`, records `collectedAt`, and makes the code permanently unusable. Codes are unique among a stall's active orders. Emergency stop refunds paid `placed`, leaves `accepted` for resolution, and preserves `ready` handover.

Websocket handshake uses the bearer token. Event: `{eventId,cursor,type,occurredAt,order}`; type is `new_order|order_updated|order_cancelled`. `cursor` is monotonic per stall. Reconnect sends `?afterCursor=` and receives missed events in order; clients deduplicate `eventId`. Ping/pong: 30 seconds; token expiry closes 4401.

## Examples

```json
{"items":[{"id":"o_004","billNumber":"B104","counterCode":"104","studentFirstName":"Sneha","stallId":"stall_001","items":[{"menuItemId":"item_001","name":"Veg Burger","price":80.0,"quantity":1}],"totalAmount":80.0,"status":"ready","placedAt":"2026-11-06T04:00:00Z","acceptedAt":"2026-11-06T04:02:00Z","readyAt":"2026-11-06T04:08:00Z","collectedAt":null,"isPaid":true,"otpAttempts":0,"otpLockedUntil":null,"isCodeUsed":false}],"page":1,"limit":50,"total":1,"nextCursor":null}
```

```json
{"code":"ORDER_NOT_READY","message":"Order is not ready yet","details":{"orderId":"o_004"}}
```

```json
{"eventId":"evt_1","cursor":"42","type":"order_updated","occurredAt":"2026-11-06T04:08:00Z","order":{"id":"o_004","status":"ready"}}
```
