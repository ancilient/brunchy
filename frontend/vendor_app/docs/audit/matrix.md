# Vendor app audit matrix

| ID | Requirement | File:function | Test | Verify |
|---|---|---|---|---|
| R1-01 | Responsive orders UI | `orders_screen.dart:OrdersScreen` | `widget_test.dart` | 320/360/411dp; scale 1.0/2.0 |
| R1-02 | Responsive dashboard UI | `dashboard_screen.dart:DashboardScreen` | `dashboard_overflow_test.dart` | 320/360/411dp; scale 1.0/2.0 |
| R1-03 | Responsive menu/inventory UI | `menu_screen.dart:MenuScreen`; `inventory_screen.dart:InventoryScreen` | manual | 320/360/411dp; scale 1.0/2.0 |
| R1-04 | Four screen states | `orders_state.dart`; `dashboard_state.dart`; `menu_state.dart`; `inventory_state.dart` | manual | loading, empty, error, populated |
| R2-01 | Capacity slider/auto-accept | `stall_control_panel.dart:StallControlPanel` | `capacity_gate_test.dart` | bounds and persistence |
| R2-02 | FIFO queue/promotion | `mock_order_repository.dart:promoteQueue` | `capacity_gate_test.dart` | Ready/complete/cancel promotion |
| R2-03 | Make list/batch fire | `orders_screen.dart`; `orders_cubit.dart` | manual | selected orders transition once |
| R2-04 | Overload levels/alerts | `stall_control_cubit.dart`; `realtime_service.dart` | manual | 100-order burst, one alert |
| R3-01 | Logout clears session/stall/canteen | `auth_cubit.dart:logout`; `local_storage_service.dart:clearSession` | manual | login A, logout, login B |
| R4-01 | 100–999 pickup code and items | `order.dart`; `order_detail_screen.dart` | `order_model_test.dart` | code range and visible items |
| R4-02 | Verification/handover permanence | `otp_cubit.dart`; `mock_order_repository.dart:handoverOrder` | `order_verification_test.dart` | wrong, repeated, double-tap, cancelled |
| R5-01 | Menu images/add/edit/samples | `menu_item_tile.dart`; `add_edit_item_sheet.dart`; `mock_data.dart` | manual | image fallback and save |
| R5-02 | Stepper never below zero | `inventory_item_row.dart`; `inventory_cubit.dart` | `stock_stepper_test.dart` | repeated decrement |
| R5-03 | Restock/sold-count accuracy | `inventory_cubit.dart`; `mock_inventory_repository.dart` | `inventory_sold_count_test.dart` | restock and order impact |
| R6-01 | Period analytics metrics | `dashboard_cubit.dart`; `dashboard_stats.dart` | manual | Today/Week/Month, revenue/orders/AOV |
| R6-02 | Trend/top items/peak/prep time | `sales_chart.dart`; `top_items_list.dart`; `peak_hours_bar.dart` | manual | fixed-data hand calculation |
| R6-03 | UTC storage and IST display | `date_formatter.dart`; `dashboard_repository.dart` | manual | boundary timestamps |
| R7-01 | Emergency stop/pause/close audit | `stall_control_cubit.dart`; `stall_control_repository.dart` | `stall_control_repository_test.dart` | time + staff ID |
| R7-02 | Cancel/refund and audit | `orders_cubit.dart:cancelAndRefund` | manual | each status and log |
| R7-03 | Stop blocks order processing | `orders_cubit.dart`; `mock_order_repository.dart` | manual | status-specific actions while stopped |
| R8-01 | Aqua Burger assets/name | `app.dart`; `splash_screen.dart`; `login_screen.dart` | manual | launcher, splash, login |
| R9-01 | Change summary/doc parity | `docs/VENDOR_APP_CHANGES_SUMMARY.md` | document audit | implementation claims traceable |
| R9-02 | Contract/model field parity | `docs/BACKEND_API_CONTRACT.md`; `lib/data/models/*.dart` | document audit | fields/types/enums/errors |
| R9-03 | Marker/contract ID-path parity | `lib/data/mock/*repository.dart`; `orders_cubit.dart` | marker diff script | every marker has exact contract endpoint |
| R9-04 | Backend completeness | `docs/BACKEND_API_CONTRACT.md` | document audit | auth/refresh/realtime/idempotency/pagination/samples |
