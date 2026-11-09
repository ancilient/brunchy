# Brunchy

Campus canteen pre-ordering for Sathyabama University, by Ancilient Technologies.
Students order and pay on their phone, get one bill per stall, and collect their food at the counter with a pickup code.
Stalls receive paid orders and do almost no extra work.

## Repository layout

```
brunchy/
├── frontend/
│   ├── student_app/     Flutter student app (main app; demo screens done, not yet connected to the backend)
│   ├── vendor_app/      Flutter vendor app (demo screens done, not yet connected to the backend)
│   └── web_prototype/   React + Vite + Capacitor prototype of the student app (reference only)
├── backend/             Node.js + Express + TypeScript API (milestone 1: ordering loop works, mock payments)
├── database/            MySQL schema: migrations and seed data
├── docs/                project documents; client PDFs stay local (see docs/README.md)
└── .github/workflows/   cloud builds of the APKs
```

| Folder | Owner | Status |
|---|---|---|
| `frontend/student_app` | Frontend team | Screens done (demo data) |
| `frontend/vendor_app` | Frontend team | Screens done (demo data) |
| `backend` | Backend team | Milestone 1 done: login, menu, checkout, mock payment, bills, handover, live updates |
| `database` | Backend team | Milestone 1 schema + demo seed |

## How the parts connect

```
 Student app ─┐
 Vendor app  ─┼──  HTTPS (JSON) + WebSocket + push  ──▶  backend (Node.js + Express)
 Admin web   ─┘                                              │
                                              ┌──────────────┼───────────────┐
                                            MySQL          Redis       Razorpay / SMS / FCM
                                     (stock, orders,  (cache, OTP,
                                      money: the truth) job queue)
```
The apps never talk to the database directly. The server decides what is paid, what is in stock and what each pickup code is worth.
The API contract (every request and response) is [`docs/api/openapi.yaml`](docs/api/openapi.yaml), kept by the backend team. Agree on changes there before you code them.

## Tech stack

| Layer | Choice |
|---|---|
| Student and vendor apps | Flutter (Dart) |
| Admin page | Flutter Web (web build of the vendor app) |
| Backend API | Node.js + Express + TypeScript |
| Database | MySQL 8 |
| Cache, OTP, rate limits, job queue | Redis + BullMQ |
| Live updates | WebSocket (Socket.IO) |
| Push notifications | Firebase Cloud Messaging |
| Payments | Razorpay or Cashfree (UPI, test mode first) |
| Hosting | One cloud VM + Docker + Nginx |

## Getting started

```
git clone https://github.com/ancilient/brunchy.git
cd brunchy
```
Then open only the folder for your role and follow its README:

- **Student app:** `frontend/student_app/README.md` (needs Flutter and Android Studio)
- **Backend:** `backend/README.md` (needs Node.js 22+ and Docker)
- **Database:** `database/README.md`

Open the app folder itself in Android Studio or VS Code (for example `frontend/student_app`), not the repository root.

## Working together

1. Get the latest code before you start: `git pull`
2. Work on your own branch: `git checkout -b feature/short-description`
3. Commit small steps with clear messages: `git commit -m "Add OTP verify endpoint"`
4. Push your branch: `git push -u origin feature/short-description`
5. Open a pull request into `main` on GitHub. A teammate reviews it, then it is merged.

Rules:
- Don't push straight to `main`.
- Never commit secrets (`.env` files, API keys, keystores). Commit a `.env.example` with placeholder values instead.
- Don't commit build outputs (`build/`, `node_modules/`, `*.apk`). The `.gitignore` already skips them.
- Announce API contract changes in the team chat before merging them.
