// App state, backed by the Brunchy backend (backend/, contract in docs/api/openapi.yaml).
// The server is the only truth for stock, prices, payment and bill status; this class keeps a copy for the screens,
// plus the cart and choices that only live on the phone. Field and method names match the original demo version,
// so the screens barely changed.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/mappers.dart';
import '../api/realtime.dart';
import 'menu_data.dart';
import 'models.dart';

const _stateKey = 'brunchy_state_v2'; // cart and choices (v1 was the offline demo)
const _userKey = 'brunchy_user_v2';
const _menuCacheKey = 'brunchy_menu_cache_v1';

final _loggedOut = UserProfile(userId: 0, name: '', phone: '', registerNo: '', isLoggedIn: false);

class AppState extends ChangeNotifier {
  AppState._(this._prefs) : api = ApiClient(_prefs) {
    _realtime = Realtime(api)
      ..onBill = _applyBill
      ..onOrder = _applyOrder
      ..onReconnect = () => unawaited(refreshOrders());
    api.onSessionExpired = _forgetSession;
  }

  final SharedPreferences _prefs;
  final ApiClient api;
  late final Realtime _realtime;

  List<Canteen> canteens = [];
  List<Stall> stalls = [];
  List<Product> products = [];
  List<Order> orders = [];
  UserProfile currentUser = _loggedOut;
  List<CartLine> cart = [];
  String pickupSlot = 'now';
  int selectedCanteenId = 1;
  int demoClockMultiplier = 1; // kept for the header's demo control; timers now follow the server clock
  double convenienceFee = 5; // the server decides; updated from each order

  /// True when the last menu refresh failed and the menu shown may be out of date.
  bool menuOffline = false;

  List<StockShortage> stockShortages = [];
  Order? activePendingOrder;
  int holdSecondsLeft = 300;
  bool isHoldActive = false;
  int holdExpiredCount = 0;
  Timer? _holdTimer;
  DateTime? _holdExpiresAt;

  // An order the server created with shortages, waiting for the student's "take available / remove" answers.
  int? _unconfirmedOrderId;
  final Map<int, String> _shortageDecisions = {};
  bool _shortagesAnswered = false;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppState._(prefs);
    s._init();
    unawaited(s.refresh());
    return s;
  }

  void _init() {
    // Show something straight away: the last menu from the server, or the bundled demo menu on first start.
    if (!_loadMenuJson(_prefs.getString(_menuCacheKey))) _loadBundledMenu();

    final rawUser = _prefs.getString(_userKey);
    if (api.hasSession && rawUser != null) {
      try {
        currentUser = UserProfile.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      } catch (_) {}
    }

    final raw = _prefs.getString(_stateKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        cart = (j['cart'] as List).map((e) => CartLine.fromJson(e as Map<String, dynamic>)).toList();
        cart.removeWhere((l) => productById(l.productId) == null);
        selectedCanteenId = (j['selected_canteen_id'] as int?) ?? 1;
        pickupSlot = (j['pickup_slot'] as String?) ?? 'now';
      } catch (_) {}
    }
    if (currentUser.isLoggedIn) _realtime.connect();
  }

  void _save() {
    _prefs.setString(_stateKey, jsonEncode({
      'cart': cart.map((l) => l.toJson()).toList(),
      'selected_canteen_id': selectedCanteenId,
      'pickup_slot': pickupSlot,
    }));
  }

  /// Save and redraw. Every change goes through here.
  void _changed() {
    _save();
    notifyListeners();
  }

  // ---------------- loading from the server ----------------

  /// Menu, profile and orders. Called at start, after login, and after payment.
  Future<void> refresh() async {
    await refreshMenu();
    if (!currentUser.isLoggedIn) return;
    try {
      final me = await api.get('/me');
      currentUser = userFromApi(me['user'] as Map<String, dynamic>);
      _prefs.setString(_userKey, jsonEncode(currentUser.toJson()));
    } on ApiException catch (_) {
      // offline: keep the saved profile
    }
    await refreshOrders();
  }

  Future<void> refreshMenu() async {
    if (!currentUser.isLoggedIn) return; // the menu needs a login
    try {
      final list = await api.get('/canteens');
      final ids = (list['canteens'] as List).map((c) => (c as Map<String, dynamic>)['id'] as String).toList();
      final menus = await Future.wait(ids.map((id) => api.get('/canteens/$id/menu')));
      final cache = jsonEncode({'canteens': list['canteens'], 'menus': menus});
      _loadMenuJson(cache);
      _prefs.setString(_menuCacheKey, cache);
      menuOffline = false;
      cart.removeWhere((l) => productById(l.productId) == null);
    } on ApiException catch (_) {
      menuOffline = true;
    }
    _changed();
  }

  bool _loadMenuJson(String? raw) {
    if (raw == null) return false;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final distances = {for (final c in _bundled().canteens) c.id: c.distanceMeters};
      final newCanteens = <Canteen>[];
      final newStalls = <Stall>[];
      final newProducts = <Product>[];
      for (final c in (j['canteens'] as List).cast<Map<String, dynamic>>()) {
        final id = int.parse(c['id'] as String);
        newCanteens.add(canteenFromApi(c, distanceMeters: distances[id] ?? 0));
      }
      for (final m in (j['menus'] as List).cast<Map<String, dynamic>>()) {
        final canteenId = int.parse((m['canteen'] as Map<String, dynamic>)['id'] as String);
        for (final st in (m['stalls'] as List).cast<Map<String, dynamic>>()) {
          newStalls.add(stallFromApi(st, canteenId));
          for (final p in (st['products'] as List).cast<Map<String, dynamic>>()) {
            newProducts.add(productFromApi(p, canteenId));
          }
        }
      }
      if (newCanteens.isEmpty) return false;
      canteens = newCanteens;
      stalls = newStalls;
      products = newProducts;
      if (canteenById(selectedCanteenId) == null) selectedCanteenId = canteens.first.id;
      return true;
    } catch (_) {
      return false;
    }
  }

  ({List<Canteen> canteens, List<Stall> stalls, List<Product> products}) _bundled() {
    final menu = jsonDecode(kMenuJson) as Map<String, dynamic>;
    return (
      canteens: (menu['canteens'] as List).map((e) => Canteen.fromJson(e as Map<String, dynamic>)).toList(),
      stalls: (menu['stalls'] as List).map((e) => Stall.fromJson(e as Map<String, dynamic>)).toList(),
      products: (menu['products'] as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  void _loadBundledMenu() {
    final b = _bundled();
    canteens = b.canteens;
    stalls = b.stalls;
    products = b.products;
  }

  Future<void> refreshOrders() async {
    if (!currentUser.isLoggedIn) return;
    try {
      final r = await api.get('/orders?limit=30');
      orders = (r['orders'] as List).map((o) => orderFromApi(o as Map<String, dynamic>)).toList();
      notifyListeners();
    } on ApiException catch (_) {}
  }

  /// A bill changed on the server (vendor accepted, ready, handed over…): update it in place.
  void _applyBill(Map<String, dynamic> json) {
    final bill = billFromApi(json);
    for (final o in orders) {
      final i = o.bills.indexWhere((b) => b.stallOrderId == bill.stallOrderId);
      if (i > -1) {
        o.bills[i] = bill;
        notifyListeners();
        return;
      }
    }
    unawaited(refreshOrders()); // a bill we have not seen yet
  }

  void _applyOrder(Map<String, dynamic> json) {
    final order = orderFromApi(json);
    final i = orders.indexWhere((o) => o.orderId == order.orderId);
    if (i > -1) {
      orders[i] = order;
    } else {
      orders.insert(0, order);
    }
    notifyListeners();
  }

  // ---------------- lookups ----------------
  Product? productById(int id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Stall? stallById(int id) {
    for (final s in stalls) {
      if (s.id == id) return s;
    }
    return null;
  }

  Canteen? canteenById(int id) {
    for (final c in canteens) {
      if (c.id == id) return c;
    }
    return null;
  }

  Canteen? get cartCanteen => canteenById(selectedCanteenId);
  int get cartItemCount => cart.fold(0, (s, l) => s + l.quantity);

  static const _openBillStatuses = ['waiting_for_acceptance', 'accepted', 'preparing', 'ready'];

  bool get hasActiveOrder => orders.any((o) => o.status == 'paid' && o.bills.any((b) => _openBillStatuses.contains(b.status)));

  List<StallBill> getStudentBills() {
    final bills = orders.where((o) => o.status == 'paid').expand((o) => o.bills).toList();
    bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bills;
  }

  /// Rough busy level from the student's own view of open bills (the server's busy level comes later).
  String getLiveBusyLevel(int canteenId) {
    final open = stalls.where((s) => s.canteenId == canteenId && s.status == 'open').length;
    if (open == 0) return 'Low';
    final active = orders
        .where((o) => o.status == 'paid' && o.canteenId == canteenId)
        .expand((o) => o.bills)
        .where((b) => _openBillStatuses.contains(b.status))
        .length;
    final ratio = active / open;
    if (ratio < 4) return 'Low';
    if (ratio < 12) return 'Medium';
    return 'High';
  }

  // ---------------- login (OTP) ----------------

  /// Asks the server to send a code. Returns the code itself in development builds of the server (devCode), else null.
  Future<String?> requestOtp(String phone) async {
    final r = await api.post('/auth/otp', {'phone': phone});
    return r['devCode'] as String?;
  }

  /// Checks the code. New phone numbers become student accounts (name required). Throws ApiException on failure.
  Future<void> verifyOtp({required String phone, required String code, required String name, String? registerNo}) async {
    final r = await api.post('/auth/verify', {
      'phone': phone,
      'code': code,
      if (name.isNotEmpty) 'name': name,
      if (registerNo != null && registerNo.isNotEmpty) 'registerNo': registerNo,
    });
    final user = userFromApi(r['user'] as Map<String, dynamic>);
    if ((r['user'] as Map<String, dynamic>)['role'] != 'student') {
      throw ApiException(403, 'NOT_A_STUDENT', 'This number belongs to a stall account. Use the Brunchy Vendor app.');
    }
    await api.saveSession(r['accessToken'] as String, r['refreshToken'] as String);
    currentUser = user;
    _prefs.setString(_userKey, jsonEncode(currentUser.toJson()));
    _realtime.connect();
    _changed();
    unawaited(refresh());
  }

  void logoutStudent() {
    final rt = api.refreshToken;
    if (rt != null) unawaited(api.post('/auth/logout', {'refreshToken': rt}).then((_) {}, onError: (_) {}));
    _forgetSession();
  }

  void _forgetSession() {
    _realtime.disconnect();
    unawaited(api.clearSession());
    _prefs.remove(_userKey);
    currentUser = _loggedOut;
    cart = [];
    orders = [];
    _stopHold();
    activePendingOrder = null;
    _changed();
  }

  void setSelectedCanteenId(int id) {
    selectedCanteenId = id;
    _changed();
  }

  void setPickupSlot(String slot) {
    pickupSlot = slot;
    _changed();
  }

  void setDemoClockMultiplier(int m) {
    demoClockMultiplier = m;
    notifyListeners();
  }

  // ---------------- cart (on the phone until checkout) ----------------
  /// Returns null on success, or the reason it could not be added. The server checks everything again at checkout.
  String? addToCart(Product product, [int quantity = 1]) {
    final canteen = canteenById(product.canteenId);
    if (canteen == null || canteen.status != 'open') return 'This canteen is not taking orders right now.';
    final stall = stallById(product.stallId);
    if (stall == null || stall.status != 'open') return '${stall?.name ?? 'Stall'} is currently ${stall?.status ?? 'closed'}.';
    if (cart.isNotEmpty && productById(cart.first.productId)?.canteenId != product.canteenId) {
      return 'One cart equals one canteen. Please clear your current cart to order from another canteen.';
    }
    if (product.stock <= 0) return 'This item is sold out.';
    final idx = cart.indexWhere((l) => l.productId == product.id);
    if (idx > -1) {
      final current = cart[idx].quantity;
      if (current + quantity > product.stock) return 'Only ${product.stock} available in stock.';
      cart[idx].quantity = current + quantity;
    } else {
      cart.add(CartLine(productId: product.id, quantity: quantity));
    }
    _changed();
    return null;
  }

  void updateCartQuantity(int productId, int delta) {
    final idx = cart.indexWhere((l) => l.productId == productId);
    if (idx == -1) return;
    final newQty = cart[idx].quantity + delta;
    if (newQty <= 0) {
      cart.removeAt(idx);
    } else {
      final live = productById(productId);
      if (live != null && newQty > live.stock) return;
      cart[idx].quantity = newQty;
    }
    _changed();
  }

  void clearCart() {
    cart = [];
    _changed();
  }

  // ---------------- checkout & payment ----------------
  bool _checkoutBusy = false;

  /// Reserves the cart on the server (5-minute hold). Shortages open the "Only N left" sheet;
  /// once all are answered, calling this again confirms that order instead of starting a new one.
  Future<CheckoutResult> startCheckout() async {
    if (cart.isEmpty) return const CheckoutResult(success: false, message: 'Cart is empty');
    if (_checkoutBusy) return const CheckoutResult(success: false);
    _checkoutBusy = true;
    try {
      Map<String, dynamic> r;
      final pendingConfirm = _unconfirmedOrderId;
      if (pendingConfirm != null && _shortagesAnswered) {
        r = await api.post('/checkout/$pendingConfirm/confirm-partial', {
          'lines': [for (final e in _shortageDecisions.entries) {'productId': '${e.key}', 'action': e.value}],
        });
      } else {
        if (pendingConfirm != null) unawaited(_cancelOnServer(pendingConfirm)); // an abandoned shortage prompt
        final canteenId = productById(cart.first.productId)?.canteenId ?? selectedCanteenId;
        r = await api.post('/checkout', {
          'canteenId': '$canteenId',
          'items': [for (final l in cart) {'productId': '${l.productId}', 'qty': l.quantity}],
          'idempotencyKey': _newKey(),
        });
      }
      _unconfirmedOrderId = null;
      _shortageDecisions.clear();
      _shortagesAnswered = false;

      final order = orderFromApi(r['order'] as Map<String, dynamic>, pickupSlot: pickupSlot);
      convenienceFee = order.convenienceFee;
      if (order.status == 'cancelled') {
        cart = [];
        _changed();
        return const CheckoutResult(success: false, message: 'Nothing left in the cart to order.');
      }
      if (r['needsConfirmation'] == true) {
        _unconfirmedOrderId = order.orderId;
        stockShortages = [
          for (final sh in (r['shortages'] as List).cast<Map<String, dynamic>>())
            if (productById(int.parse(sh['productId'] as String)) case final p?)
              StockShortage(product: p, requested: (sh['requested'] as num).toInt(), available: (sh['available'] as num).toInt()),
        ];
        notifyListeners();
        return const CheckoutResult(success: false, shortage: true);
      }
      _startHold(order, r['payment'] as Map<String, dynamic>?);
      _changed();
      return const CheckoutResult(success: true);
    } on ApiException catch (e) {
      unawaited(refreshMenu()); // stock or stall status changed: show the latest
      return CheckoutResult(success: false, message: e.message);
    } finally {
      _checkoutBusy = false;
    }
  }

  void _startHold(Order order, Map<String, dynamic>? payment) {
    activePendingOrder = order;
    final expires = payment?['expiresAt'] as String?;
    _holdExpiresAt = expires == null ? api.serverNow().add(const Duration(minutes: 5)) : DateTime.parse(expires);
    isHoldActive = true;
    _tickHold();
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickHold());
  }

  /// Counts down with the server's clock, so changing the phone's time changes nothing.
  void _tickHold() {
    final end = _holdExpiresAt;
    if (!isHoldActive || end == null) return;
    final left = end.difference(api.serverNow()).inSeconds;
    if (left <= 0) {
      holdSecondsLeft = 0;
      _stopHold();
      holdExpiredCount++;
      activePendingOrder?.status = 'expired';
      activePendingOrder = null;
      _changed();
      unawaited(refreshMenu());
    } else {
      holdSecondsLeft = left;
      notifyListeners();
    }
  }

  void _stopHold() {
    isHoldActive = false;
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void handleShortageChoice(int productId, bool takeAvailable) {
    StockShortage? s;
    for (final x in stockShortages) {
      if (x.product.id == productId) s = x;
    }
    if (s == null) return;
    final keep = takeAvailable && s.available > 0;
    _shortageDecisions[productId] = keep ? 'take_available' : 'remove';
    if (keep) {
      for (final l in cart) {
        if (l.productId == productId) l.quantity = s.available;
      }
    } else {
      cart.removeWhere((l) => l.productId == productId);
    }
    stockShortages = stockShortages.where((x) => x.product.id != productId).toList();
    if (stockShortages.isEmpty) _shortagesAnswered = true;
    _changed();
  }

  void clearShortages() {
    stockShortages = [];
    notifyListeners();
  }

  /// The payment sheet was closed: release the held stock on the server straight away.
  void cancelCheckoutHold() {
    final pending = activePendingOrder;
    if (pending != null) {
      pending.status = 'cancelled';
      unawaited(_cancelOnServer(pending.orderId));
    }
    _stopHold();
    activePendingOrder = null;
    _changed();
  }

  Future<void> _cancelOnServer(int orderId) async {
    try {
      await api.post('/checkout/$orderId/cancel');
    } on ApiException catch (_) {
      // already paid/expired, or offline: the server's 5-minute expiry releases it anyway
    }
    unawaited(refreshMenu());
  }

  /// Pays with the backend's mock gateway (development: no money moves).
  /// TODO(Razorpay milestone): open the Razorpay checkout here; the server confirms through its webhook.
  Future<int?> completeUpiPayment(String method) async {
    final pending = activePendingOrder;
    if (pending == null) return null;
    final upiApp = method.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final r = await api.post('/payments/mock/${pending.orderId}/pay', {'upiApp': upiApp});
    if (r['result'] != 'paid' && r['result'] != 'replay') {
      throw ApiException(402, 'PAYMENT_NOT_COMPLETED', 'Payment was not completed. Please try again.');
    }
    if (activePendingOrder == pending) activePendingOrder = null;
    _stopHold();
    cart = [];
    _changed();
    await refreshOrders();
    unawaited(refreshMenu());
    return pending.orderId;
  }

  // ---------------- after payment ----------------

  /// Cancels one bill before the kitchen starts it. Returns an error message, or null when done.
  Future<String?> cancelStudentBill(int stallOrderId) async {
    try {
      final r = await api.post('/bills/$stallOrderId/cancel');
      _applyBill(r['bill'] as Map<String, dynamic>);
      unawaited(refreshMenu());
      return null;
    } on ApiException catch (e) {
      unawaited(refreshOrders());
      return e.message;
    }
  }

  String _newKey() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _realtime.disconnect();
    super.dispose();
  }
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

// ---------------- formatting, matching what the browser shows ----------------
/// Like JavaScript's number printing: 84 -> "84", 89.25 -> "89.25", 4.5 -> "4.5".
String fmtNum(double v) {
  final r = _round2(v);
  if (r == r.roundToDouble()) return r.toInt().toString();
  var s = r.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "09:35 PM" (toLocaleTimeString with hour: '2-digit', minute: '2-digit')
String formatTime2Digit(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "9:43 pm" (en-IN, hour numeric)
String formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

/// "Nov 4"
String formatShortDate(DateTime t) => '${_months[t.month - 1]} ${t.day}';
