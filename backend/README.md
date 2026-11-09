# Brunchy backend

The brain and the referee: it decides what is paid, what is in stock, what each pickup code is worth, and when to refund.
The apps only display what this server says.

**Status: milestone 1 done** — the full ordering loop works end to end with a mock payment gateway:
OTP login → canteens and today's menu → checkout with a 5-minute stock hold → payment webhook → one bill per stall with a
bill number and 3-digit pickup code → vendor accept / ready / handover → live updates over Socket.IO.
The API contract is in [`docs/api/openapi.yaml`](../docs/api/openapi.yaml).

## Stack
Node.js 22+ · Express 5 · TypeScript · MySQL 8 (plain SQL with `mysql2`) · Redis (OTP codes, rate limits, menu cache) ·
BullMQ (hold-expiry jobs) · Socket.IO (live bills) · zod (validation) · JWT (access + rotating refresh tokens) · vitest (tests).

## Run it on your computer
Needs **Node.js 22+** and **Docker Desktop**.

```
# from the repository root: start MySQL + Redis
docker compose up -d

cd backend
copy .env.example .env        # macOS/Linux: cp .env.example .env  (then change the two secrets)
npm install
npm run db:reset              # create the tables and load the demo canteens, stalls, menu and accounts
npm run dev                   # http://localhost:4000/api/v1/health
```

Try the whole flow with [`requests.http`](requests.http) (VS Code extension "REST Client"). Demo logins (the OTP is returned
as `devCode` in development, and printed in the server log):

| Phone | Account |
|---|---|
| 9876543210 | Demo Student |
| 9000000001 … 9000000006 | Vendor of stall 1 … 6 (Burger Hub, Juice Corner, Parotta Point, Chai & Snacks, Grill Point, South Kitchen) |

### From the phone
The server listens on all interfaces. Over USB the easiest is `adb reverse tcp:4000 tcp:4000`, after which the phone's
`http://localhost:4000` reaches your PC. On the same Wi-Fi use your PC's IP from `ipconfig` instead.

## Commands
| Command | What it does |
|---|---|
| `npm run dev` | Start the API with auto-reload |
| `npm test` | Run the integration tests (uses the separate `brunchy_test` database; Docker must be running) |
| `npm run typecheck` | TypeScript check |
| `npm run db:migrate` | Apply new files from `database/migrations` |
| `npm run db:reset` | Drop everything, migrate, seed (development only) |

## Layout
```
src/
  server.ts          HTTP + Socket.IO + background jobs
  app.ts             Express app and routes (mounted under /api/v1)
  config.ts          settings from .env, checked at startup
  db/                MySQL pool, transactions, migration runner
  middleware/        JWT auth + roles, Redis rate limit
  routes/            auth, canteens (menu), checkout, payments, orders (student), vendor
  services/          the business rules (checkout, payments, bills, holds, menu, auth, audit)
  payments/          gateway interface + mock gateway (Razorpay plugs in here)
  jobs/holdExpiry.ts releases unpaid holds after 5 minutes (BullMQ job + 1-minute sweeper)
  realtime.ts        Socket.IO rooms and events
tests/               launch-gate tests: stock race, webhook replay, handover rules, …
```

## Rules the code enforces (from the blueprint)
- Amounts are always computed on the server. The apps send product ids and quantities only.
- Checkout locks product rows in id order and takes min(requested, available) in one transaction, so stock never oversells
  (test: 200 parallel checkouts for 50 items sell exactly 50).
- An order becomes paid **only** through the signed gateway webhook; the same notification received again changes nothing.
- A payment that arrives after the hold expired re-reserves the stock if it is still there, otherwise records a refund.
- Pickup codes are 3 digits, unique among the stall's open bills of the day (enforced by a database unique key). Handover
  works once; 4 wrong codes lock the bill for 5 minutes.
- Server clock only. Every payment, refund, status change and handover is written to `audit_log`.

## Changes from the blueprint (agreed in the team)
- **3-digit pickup code instead of a QR** (OTP Workflow Team Guide; both apps already use it). The QR columns are not created.
- **Convenience fee** is a flat setting (`CONVENIENCE_FEE`, default ₹5) because the documents disagree (₹5 vs 10%).
- **Close for today** blocks new orders; paid bills already on the board continue. Auto-cancel + refund of unstarted bills
  comes with the refunds milestone.

## Not built yet (next milestones)
Razorpay adapter and real refunds · SMS provider for OTP · FCM push notifications · emergency stop with refunds ·
manager approvals, price-change requests, daily-menu admin · search and pickup slots · reports and vendor dashboard ·
admin web · connecting the Flutter apps (replace their mock repositories with calls to this API).
