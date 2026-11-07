# Brunchy Vendor App — BUILD_NOTES.md

## Part A — What Was Done

### 1. Executive Summary
The **Brunchy Vendor App** is a high-efficiency Flutter Android application custom-engineered for college campus canteen food stall operators. Its core guiding principle is **"Reduce the Vendor's Work"** — minimizing manual taps, avoiding keyboard entry during rush hours, automating calculations, and broadcasting orders hands-free via real-time speech and alarm audio.

---

### 2. Features Built & Document Mapping

| Feature | Logic Document Section / Rule | Implementation File(s) | Vendor Effort Reduction Mechanism |
| :--- | :--- | :--- | :--- |
| **Authentication & Stall Selection** | R-01, R-02, R-03 | `login_screen.dart`, `choose_stall_screen.dart` | Single phone per stall; daily stall selection; remembers vendor identity across restarts. |
| **Audio & Voice Order Broadcast** | R-06, User Requirement | `audio_service.dart`, `tts_service.dart` | Hands-free alerts on Android alarm stream; announces new order count via TTS so vendors don't need to watch the screen while cooking. |
| **Realtime Live Order Stream** | R-05, R-07 | `realtime_service.dart`, `mock_order_repository.dart` | WebSocket emulation pushing live orders; automatic 3-minute auto-cancel countdown bar. |
| **Quick Order Actions** | R-08, R-10, R-11 | `orders_screen.dart`, `order_detail_screen.dart` | One-tap Accept and Reject (with standard canned reasons); 5-second undo for "Mark Ready". |
| **4-Digit Student OTP Verification** | R-10, Goldfish Review | `otp_entry_sheet.dart`, `otp_cubit.dart` | Replaced slow QR code scanning with numeric keypad auto-advancing 4-digit OTP; server-side validated; celebratory confetti. |
| **1-Tap Menu Availability** | R-12, R-13 | `menu_screen.dart`, `menu_item_tile.dart` | One-tap toggle instantly disables sold-out items to prevent orders; quick category filters. |
| **Opening Stock Auto-Restock** | R-17, R-18 | `inventory_screen.dart`, `inventory_item_row.dart` | Automatically pre-fills from yesterday's closing stock; 1-tap stepper bounded between 0 and opening stock; real-time "Sold Today" computation. |
| **End of Day Flow** | R-14, R-15 | `home_screen.dart` | Prompts to carry forward stock; severe warning dialog if active orders remain. |
| **Sales Analytics Dashboard** | Document Part C | `dashboard_screen.dart`, `sales_chart.dart` | Summary cards (Revenue, Orders, AOV), Bar chart toggle (Revenue/Orders), 24h rush heatmap, top and slow items list. |
| **Settings & Test Tools** | Extra Utility | `settings_screen.dart` | Audio test button, switch canteen dialog, and vendor profile inspection. |

---

### 3. Files Created & Architecture
- **State Management:** Flutter BLoC / Cubit architecture with clean separation of presentation, domain, and data layers.
- **Dependency Injection:** `injection_container.dart` with GetIt service locator.
- **Local Storage:** `shared_preferences` wrapped in `local_storage_service.dart`.
- **Audio & Speech:** `audioplayers` + `flutter_tts` on alarm audio stream.
- **Charts:** `fl_chart` with interactive tooltip touch points.

---

## Part B — Backend Team Integration Guide

### 1. API Endpoints Table

| ID | Endpoint | Method | Purpose | Auth | Mock File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **[API-001]** | `/auth/login` | POST | Authenticate vendor with phone & canteen | None | `mock_auth_repository.dart` |
| **[API-002]** | `/canteens` | GET | List available canteens on campus | Bearer | `mock_auth_repository.dart` |
| **[API-003]** | `/canteens/{id}/stalls` | GET | List stalls for selected canteen | Bearer | `mock_auth_repository.dart` |
| **[API-004]** | `/stalls/{id}/claim` | POST | Claim active stall for today | Bearer | `mock_auth_repository.dart` |
| **[API-005]** | `/stalls/{id}/orders` | GET | Fetch active orders for stall | Bearer | `mock_order_repository.dart` |
| **[API-006]** | `/orders/ws` | WS | Realtime WebSocket order push | Bearer | `mock_order_repository.dart` |
| **[API-007]** | `/orders/{id}/accept` | POST | Mark order preparing | Bearer | `mock_order_repository.dart` |
| **[API-008]** | `/orders/{id}/reject` | POST | Reject order with reason & refund | Bearer | `mock_order_repository.dart` |
| **[API-009]** | `/orders/{id}/ready` | POST | Mark order ready for pickup | Bearer | `mock_order_repository.dart` |
| **[API-010]** | `/orders/{id}/collect` | POST | Validate 4-digit student OTP | Bearer | `mock_order_repository.dart` |
| **[API-011]** | `/stalls/{id}/menu` | GET | Fetch menu items | Bearer | `mock_menu_repository.dart` |
| **[API-012]** | `/stalls/{id}/menu` | POST | Add new menu item | Bearer | `mock_menu_repository.dart` |
| **[API-013]** | `/stalls/{id}/menu/{itemId}`| PATCH | Update item / toggle availability | Bearer | `mock_menu_repository.dart` |
| **[API-014]** | `/stalls/{id}/menu/{itemId}`| DELETE| Delete item from menu | Bearer | `mock_menu_repository.dart` |
| **[API-015]** | `/stalls/{id}/inventory/{date}` | GET | Get opening & current inventory | Bearer | `mock_inventory_repository.dart` |
| **[API-016]** | `/stalls/{id}/inventory/{date}/{itemId}` | PATCH | Update stock count & reason | Bearer | `mock_inventory_repository.dart` |
| **[API-017]** | `/stalls/{id}/inventory/end-day` | POST | Lock day closing & save for tomorrow | Bearer | `mock_inventory_repository.dart` |
| **[API-018]** | `/stalls/{id}/dashboard` | GET | Fetch revenue, counts, chart & rush hours | Bearer | `mock_dashboard_repository.dart` |
| **[API-019]** | `/stalls/{id}/orders/past` | GET | Paginated past orders history | Bearer | `mock_order_repository.dart` |
| **[API-020]** | `/orders/{id}` | GET | Get single order details | Bearer | `mock_order_repository.dart` |
| **[API-021]** | `/orders/{id}/undo-ready`| POST | Undo ready status within 5 seconds | Bearer | `mock_order_repository.dart` |
| **[API-022]** | `/vendor/profile` | PATCH | Update vendor canteen profile | Bearer | `mock_auth_repository.dart` |

---

### 2. Critical Dashboard Formulas (Backend Match Requirement)
1. **Average Order Value (AOV):**
   $$\text{AOV} = \frac{\text{Total Revenue}}{\text{Total Completed Orders}}$$
   *(If Completed Orders = 0, AOV = 0.00)*

2. **Percentage Change vs Previous Period:**
   $$\text{Change \%} = \frac{\text{Current} - \text{Previous}}{\text{Previous}} \times 100$$
   - When Previous = 0 and Current > 0: App renders `"New"` (teal badge).
   - When Previous = 0 and Current = 0: App renders `"—"` (neutral).

3. **Inventory Sold Today:**
   $$\text{Sold Today} = \text{Opening Stock} - \text{Current Stock}$$

---

### 3. Swapping Mock Repositories for Live APIs
In `lib/injection_container.dart`:
1. Register `Dio` client with `AuthInterceptor(sl<LocalStorageService>())`.
2. Replace `MockAuthRepository`, `MockOrderRepository`, `MockMenuRepository`, `MockInventoryRepository`, `MockDashboardRepository` with their respective remote implementations adhering to the corresponding abstract repository contracts in `lib/data/repositories/`.
