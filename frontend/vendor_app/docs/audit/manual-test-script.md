# Manual phone test

1. Install a release build on a 320dp device.
2. Set system text scale to 2.0 and open every tab.
3. Repeat at 360dp and 411dp; confirm no clipped/overflow banners.
4. Log in to stall A, then log out.
5. Log in to stall B; confirm no A session, stock, or orders appear.
6. Create/edit a menu item and confirm image fallback.
7. Reduce stock to zero; confirm it cannot go negative; restock it.
8. Set capacity to one and create three mock orders.
9. Ready, collect, and cancel eligible orders; confirm FIFO promotion.
10. Use Batch Fire and verify capacity is respected.
11. Trigger a 100-order burst and confirm one audible alert.
12. Verify a Ready order with its three-digit code; retry the same code.
13. Try a wrong code and a not-ready/cancelled order.
14. Pause, close, and emergency-stop; confirm blocked actions and audit staff/time.
15. Check Today/Week/Month totals, trend, top items, peak hours and prep time.
