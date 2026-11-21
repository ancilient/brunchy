# Deploying the Brunchy backend to a VPS

One Ubuntu 24.04 server (Hostinger KVM 2) runs everything in Docker:

```
Internet ──HTTPS──▶ Caddy (free certificate) ──▶ API (Node 22, Socket.IO, jobs) ──▶ MySQL 8, Redis 7 (private)
```

Files in this folder:

| File | What it is |
|---|---|
| `docker-compose.prod.yml` | The four containers: `caddy`, `api`, `mysql`, `redis` |
| `Caddyfile` | HTTPS + reverse proxy to the API (WebSockets included) |
| `.env.example` | Production settings template. Copy to `.env` on the server; never commit `.env` |
| `server-setup.sh` | One-time server preparation (Docker, firewall, swap, auto-updates, backup schedule) |
| `backup.sh` | Nightly MySQL backup, kept 14 days |

The API image is built from `backend/Dockerfile`. Each start applies any new database migrations automatically.

## 1. Before you start (once)
- The server's **IP address**, and **SSH key login** working from your PC:
  `ssh root@<server-ip>` should log in without asking for a password.
- Razorpay key ID and secret (test keys until KYC is approved), and the Google Web client ID.

## 2. Prepare the server (once)
```bash
ssh root@<server-ip>
apt-get update -y && apt-get install -y git
git clone https://github.com/ancilient/brunchy.git /opt/brunchy
bash /opt/brunchy/deploy/server-setup.sh
```

## 3. Settings (once)
```bash
cd /opt/brunchy/deploy
cp .env.example .env
nano .env
```
- `API_DOMAIN`: `api.<ip-with-dashes>.sslip.io`, e.g. IP `203.0.113.10` gives `api.203-0-113-10.sslip.io`.
- `MYSQL_ROOT_PASSWORD`, `DB_PASSWORD`, `JWT_ACCESS_SECRET`: run `openssl rand -hex 32` once for each.
- Razorpay keys, `GOOGLE_CLIENT_IDS`. Keep `DEV_LOGIN=false` and `IGNORE_CANTEEN_HOURS=false`.
- Then `chmod 600 .env` so only root can read it.

## 4. Start
```bash
cd /opt/brunchy/deploy
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
curl https://<API_DOMAIN>/api/v1/health
```
The first start takes a few minutes (building the image, getting the certificate).

**First time only, load the canteens, stalls and menu** (the demo data from `database/seeds`; it only runs on an
empty database):
```bash
docker compose -f docker-compose.prod.yml exec api node dist/db/migrate.js seed
```
Then link each stall's Google account (stall 1 = Burger Hub):
```bash
docker compose -f docker-compose.prod.yml exec api node dist/db/set-vendor-email.js 1 vendor@example.com
```

## 5. Connect the rest
- **Apps:** build release APKs with the live address:
  `flutter build apk --dart-define=API_URL=https://<API_DOMAIN>/api/v1` (student and vendor apps).
- **Google sign-in:** nothing to change for the apps (they use the same Web client ID).
- **Razorpay webhook:** Dashboard → Webhooks → add `https://<API_DOMAIN>/api/v1/payments/webhook`, events
  `payment.captured` and `payment.failed`, set a secret, put it in `RAZORPAY_WEBHOOK_SECRET`, then restart the API.
- **Uptime alert:** add a free monitor (e.g. UptimeRobot) for `https://<API_DOMAIN>/api/v1/health`.

## Everyday commands (run in /opt/brunchy/deploy)
| Task | Command |
|---|---|
| Deploy the latest `main` | `git -C /opt/brunchy pull && docker compose -f docker-compose.prod.yml up -d --build` |
| Restart the API (e.g. after editing `.env`) | `docker compose -f docker-compose.prod.yml up -d api` |
| See API logs | `docker compose -f docker-compose.prod.yml logs -f --tail=100 api` |
| Status of all containers | `docker compose -f docker-compose.prod.yml ps` |
| Back up now | `bash backup.sh` |
| Open a MySQL prompt | `docker compose -f docker-compose.prod.yml exec mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" brunchy'` |

Backups are in `/var/backups/brunchy` (restore steps are at the top of `backup.sh`). Copy them off the server
regularly; a backup that only lives on the same server does not survive losing the server.
