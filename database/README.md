# Brunchy database (MySQL 8)

**Status:** not started. The full design is in the blueprint, section 10 (*Database design and SQL queries*).

## Layout
```
database/
├── migrations/   numbered schema changes, applied in order, never edited once merged
│                 e.g. 001_create_canteens_stalls_products.sql, 002_create_orders.sql
└── seeds/        test data for local development, e.g. 001_demo_menu.sql
                  (start from frontend/web_prototype/src/data/mockData.ts)
```

## Tables (from blueprint v3.1)
canteens → stalls → products (strict Canteen > Stall > Product hierarchy), daily_menu, price_change_requests,
users, orders (one per payment), stall_orders (one bill per stall), order_items, stall_bill_counters,
payments, refunds, vendor_ledger, audit_log.

## Rules
- Money is `DECIMAL(10,2)`, ids are `INT`. Never use FLOAT for money.
- All times are stored in UTC (`time_zone = '+00:00'`); convert to IST only for display.
- Soft deletes only (`is_active`). The app's database user has no `DROP` and no `DELETE` on core tables.
- Change the schema only by adding a new migration file, reviewed in a pull request. Never edit production by hand.
- No real student data in seed files or in git.
