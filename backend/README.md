# Brunchy backend

The brain and the referee: it decides what is paid, what is in stock, what each pickup code is worth, and when to refund.
The apps only display what this server says.

**Status:** not started.

## Stack
Node.js 22 + Express + TypeScript, MySQL 8 (the only source of truth for stock and money), Redis (menu cache, OTP codes, rate limits),
BullMQ (background jobs), Socket.IO (live orders to vendors), Firebase Cloud Messaging (push), Razorpay or Cashfree (UPI payments).

## Planned layout
```
backend/
├── src/
│   ├── server.ts        starts Express + Socket.IO
│   ├── config.ts        reads settings from .env
│   ├── routes/          HTTP endpoints: auth, menu, checkout, payments, orders, vendor, admin
│   ├── services/        business rules: stock reservation, bills, pickup codes, refunds
│   ├── db/              MySQL connection + query helpers
│   ├── jobs/            BullMQ workers: hold expiry, code expiry, refunds, notifications
│   └── middleware/      auth (JWT + roles), rate limits, errors
├── tests/
├── .env.example         every setting with placeholder values (the real .env is never committed)
├── package.json
└── tsconfig.json
```
The database schema lives in [`../database`](../database), and the API contract in [`../docs/api`](../docs/api).

## Rules from the blueprint
- Amounts are always computed on the server; never trust a price or total sent by an app.
- Stock is reserved in one atomic MySQL transaction and held for 5 minutes before payment.
- A payment is real only when the gateway's signed webhook says so. The webhook must be safe to receive many times.
- Every checkout carries an idempotency key, so a retry never charges twice.
- Server time only: timers never use the phone's clock.
- Log every payment, refund, handover and vendor action to `audit_log`.

## First endpoints to build
1. `POST /auth/otp/send`, `POST /auth/otp/verify`
2. `GET /canteens`, `GET /canteens/:id/menu`
3. `POST /checkout` (stock reservation, one order with one bill per stall)
4. `POST /payments/webhook` (Razorpay, test mode)
5. `GET /orders/me`
6. Vendor: accept, reject, mark ready, complete with pickup code
