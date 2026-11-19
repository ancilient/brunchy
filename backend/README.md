# Brunchy backend

The brain and the referee: it decides what is paid, what is in stock, what each pickup code is worth, and when to refund.
The apps only display what this server says.


**Status: milestone 1 done** — the full ordering loop works end to end with a mock payment gateway:
Sign in with Google → canteens and today's menu → checkout with a 5-minute stock hold → payment webhook → one bill per stall with a
bill number and 3-digit pickup code → vendor accept / ready / handover → live updates over Socket.IO.
The API contract is in [`docs/api/openapi.yaml`](../docs/api/openapi.yaml).

## Stack
Node.js 22+ · Express 5 · TypeScript · MySQL 8 (plain SQL with `mysql2`) · Redis (rate limits, menu cache) ·
BullMQ (hold-expiry jobs) · Socket.IO (live bills) · zod (validation) · Google Sign-In (`google-auth-library` verifies
ID tokens) · JWT (access + rotating refresh tokens) · vitest (tests).

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

Try the whole flow with [`requests.http`](requests.http) (VS Code extension "REST Client").

### Sign-in
The apps sign in with **Google** (free; phone + OTP was removed because SMS costs money):
the app gets an ID token from Google, `POST /auth/google` verifies it with Google (`GOOGLE_CLIENT_IDS` = the OAuth Web
client ID) and returns Brunchy's own access + refresh tokens. A new Google account becomes a student (student app
only); a vendor must use the Google account registered for their stall:
```
npm run vendor:email -- 1 someone@gmail.com      # stall 1 = Burger Hub ... 6 = South Kitchen
```
One-time Google Cloud setup: [`docs/google-sign-in-setup.md`](../docs/google-sign-in-setup.md).
**Development login** (`DEV_LOGIN=true`, refused in production): `POST /auth/dev-login {"app":"student"}` or
`{"app":"vendor","stallId":1}`. The apps show a "Continue as demo …" button for it.

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
- **No separate convenience fee or stall GST** on what the student pays.
- **Platform fee** (`PLATFORM_FEE_PERCENT`, default 2.36%) is charged on item total only and covers platform fee + GST.
- **Close for today** blocks new orders; paid bills already on the board continue. Auto-cancel + refund of unstarted bills
  comes with the refunds milestone.

## Payments (Razorpay test mode)
Set `PAYMENT_GATEWAY=razorpay` plus `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` in `backend/.env` (test keys from the
Razorpay dashboard). Checkout creates a Razorpay order; the student app opens Checkout; the app then calls
`POST /payments/razorpay/confirm` with the signed response so local/dev works **without** a public webhook URL.
`RAZORPAY_WEBHOOK_SECRET` is only needed when you expose `/api/v1/payments/webhook` (ngrok or deployed API).

## Not built yet (next milestones)
Real refunds via Razorpay · FCM push notifications · emergency stop with refunds ·
manager approvals, price-change requests, daily-menu admin · search and pickup slots · reports and vendor dashboard ·
admin web.
