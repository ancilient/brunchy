# Brunchy vendor app (Flutter)

**Status:** not started.

The app stall staff use at the counter. Its web build is also the Admin page for canteen managers and the Ancilient admin (role-based screens).

## Screens (from the build guide, part 4)
- **Dashboard:** accepting-orders switch, today's orders and sales, Pause (10/15/30 min), Close for today, Emergency stop.
- **Items and stock:** price, big + / − quantity stepper, on/off switch, automatic SOLD OUT at 0, reset daily stock.
- **Live orders board:** New / Preparing / Ready tabs, sound and vibration on every paid order; Accept, Reject, Item unavailable, Mark Ready.
- **Hand-over:** enter the student's 3-digit pickup code to complete the bill.
- **Reports:** today's sales and item totals, money owed and paid.

## To create it
From the `frontend/` folder:
```
flutter create vendor_app --org com.ancilient --platforms=android,web
```
Then reuse the colours and fonts from `../student_app/lib/ui/theme.dart` so both apps match.
