# Changing names, prices, photos, settings and app texts

Until the admin dashboard exists, these are the ways to change what students and vendors see.
Everything here runs on the server: log in first.

```bash
ssh root@<server-ip>
cd /opt/brunchy/deploy
```

All commands below start with `docker compose -f docker-compose.prod.yml exec api node dist/db/catalog.js`.
To save typing, set this once per login:

```bash
alias catalog='docker compose -f docker-compose.prod.yml exec api node dist/db/catalog.js'
```

Changes show in the apps within about 30 seconds (the menu is cached briefly). Every change is written to the
audit log.

## 1. See the ids
```bash
catalog list
```
```
Canteen 1: Main Canteen
  Stall 1: Burger Hub
    Item 101: Cheese Burger  Rs 80.00
    Item 102: French Fries  Rs 40.00  [photo]
```

## 2. Rename a canteen, a stall or a food item
Put names with spaces in quotes.
```bash
catalog canteen:rename 1 "Main Canteen (Block 1)"
catalog stall:rename 1 "Burger Hub Express"
catalog item:rename 101 "Classic Cheese Burger"
```

## 3. Change a price
```bash
catalog item:price 101 85
catalog item:price 101 85.50
```
Orders already placed keep the price they were placed at.

## 4. Food photos
Photos show on the student menu (round, 64 px; square photos look best, about 400 × 400 px, under 300 KB,
JPG/PNG/WebP). Without a photo the app shows an emoji.

**Option A: upload the photo to the server** (no outside hosting needed). From your PC:
```bash
scp cheese-burger.jpg root@<server-ip>:/opt/brunchy/deploy/uploads/
```
Then on the server:
```bash
catalog item:photo 101 cheese-burger.jpg
```
It becomes `https://<API_DOMAIN>/uploads/cheese-burger.jpg`. Use simple file names: letters, numbers, `-`, `_`.

**Option B: a photo already online** (must be `https://`):
```bash
catalog item:photo 101 https://example.com/photos/cheese-burger.jpg
```

Remove a photo: `catalog item:photo 101 none`. Mark veg / non-veg: `catalog item:veg 101 yes` (or `no`).

## 5. Settings: Customer Care, GST number, fees
These live in `/opt/brunchy/deploy/.env` (never in GitHub). Edit with `nano .env`, then restart the API:
```bash
docker compose -f docker-compose.prod.yml up -d api
```

| Setting | What it does | Example |
|---|---|---|
| `SUPPORT_EMAIL` | "Email" button in Customer Care (opens the student's mail app with their Order ID filled in) | `help@yourdomain.in` |
| `SUPPORT_PHONE` | "Call" button | `+919876543210` |
| `SUPPORT_WHATSAPP` | "WhatsApp" button (country code, digits only) | `919876543210` |
| `GSTIN` | GST number printed on bills (empty shows "GSTIN: to be added") | `33ABCDE1234F1Z5` |
| `PLATFORM_FEE_PERCENT` | Platform fee, % of the food total | `3` |
| `CONVENIENCE_FEE_PERCENT` | Convenience fee, % of the food total | `3` |
| `FREE_ORDERS_PER_STUDENT` | A student's first N paid orders have no fees (0 = off) | `2` |

Empty contact settings hide their button. The apps read these at start, so no new APK is needed.

## 6. Texts inside the apps
Wording on the screens (buttons, headings, messages) is in the app code, so changing it needs a new APK.
Ask a developer, or change it and rebuild:

| What | Where |
|---|---|
| Student Terms & Conditions (50–100 words, checked by a test) | `frontend/student_app/lib/state/terms.dart` |
| Student screens (menu, cart, orders, profile, Customer Care) | `frontend/student_app/lib/screens/*.dart` |
| Vendor app common texts (buttons, greetings, errors) | `frontend/vendor_app/lib/core/constants/app_strings.dart` |
| Vendor screens | `frontend/vendor_app/lib/features/*/` |
| Public privacy policy and terms web pages | `gh-pages` branch: `privacy.html`, `terms.html` |

After a text change, rebuild the APK pointing at the live server, e.g. for the student app:
```bash
flutter build apk --release --dart-define=API_URL=https://<API_DOMAIN>/api/v1
```
