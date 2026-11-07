// App state and logic, a line-by-line port of the student parts of src/context/CanteenContext.tsx.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'menu_data.dart';
import 'models.dart';

const _stateKey = 'brunchy_state_v1';
const _userKey = 'brunchy_user';
const _demoPhone = '9845012345'; // the seeded demo student (user_id 1) owns the sample order

class AppState extends ChangeNotifier {
  AppState._(this._prefs);
  final SharedPreferences _prefs;

  late List<Canteen> canteens;
  late List<Stall> stalls;
  late List<Product> products;
  late List<Order> orders;
  late UserProfile currentUser;
  List<CartLine> cart = [];
  String pickupSlot = 'now';
  int selectedCanteenId = 1;
  int demoClockMultiplier = 1;
  final double convenienceFee = 5; // Flat ₹5 per order

  List<StockShortage> stockShortages = [];
  Order? activePendingOrder;
  int holdSecondsLeft = 300;
  bool isHoldActive = false;
  int holdExpiredCount = 0;
  int _nextCodeSeed = 346;
  Timer? _holdTimer;
  final _rand = Random();

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppState._(prefs);
    s._init();
    return s;
  }

  void _init() {
    final menu = jsonDecode(kMenuJson) as Map<String, dynamic>;
    canteens = (menu['canteens'] as List).map((e) => Canteen.fromJson(e as Map<String, dynamic>)).toList();
    stalls = (menu['stalls'] as List).map((e) => Stall.fromJson(e as Map<String, dynamic>)).toList();
    products = (menu['products'] as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    orders = [_seedOrder()];

    currentUser = UserProfile(userId: 1, name: 'Priya R.', phone: _demoPhone, registerNo: 'ENG2024-8842', isLoggedIn: true);
    final rawUser = _prefs.getString(_userKey);
    if (rawUser != null) {
      try {
        currentUser = UserProfile.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Everything the student would lose if Android closes the app in the background is kept on the phone.
    final raw = _prefs.getString(_stateKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        orders = (j['orders'] as List).map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
        final stock = (j['stock'] as Map<String, dynamic>);
        for (final p in products) {
          final v = stock['${p.id}'];
          if (v is int) p.stock = v;
        }
        cart = (j['cart'] as List).map((e) => CartLine.fromJson(e as Map<String, dynamic>)).toList();
        cart.removeWhere((l) => productById(l.productId) == null);
        selectedCanteenId = (j['selected_canteen_id'] as int?) ?? 1;
        pickupSlot = (j['pickup_slot'] as String?) ?? 'now';
        _nextCodeSeed = (j['next_code_seed'] as int?) ?? 346;
        // A checkout that was waiting for payment when the app closed can never complete: release its stock.
        for (final o in orders.where((o) => o.status == 'pending')) {
          o.status = 'expired';
          for (final it in o.bills.expand((b) => b.items)) {
            productById(it.productId)?.stock += it.quantity;
          }
        }
      } catch (_) {
        // corrupted save: start from the demo data
      }
    }
  }

  Order _seedOrder() {
    final now = DateTime.now();
    return Order(
      orderId: 1001, userId: 1, canteenId: 1, canteenName: 'Main Canteen',
      subtotal: 140, tax: 7, convenienceFee: 5, total: 152, pickupSlot: 'now', status: 'paid',
      createdAt: now.subtract(const Duration(minutes: 5)),
      bills: [
        StallBill(
          stallOrderId: 2001, orderId: 1001, stallId: 1, canteenId: 1, stallName: 'Burger Hub', billPrefix: 'BH',
          billNo: 'BH-0117', pickupCode: '345', subtotal: 140, tax: 7, total: 147, status: 'accepted',
          estimatedTimeMins: 6, estimatedReadyTime: '1:02 PM', createdAt: now.subtract(const Duration(minutes: 4)),
          items: [
            BillItem(itemId: 3001, productId: 101, productName: 'Cheese Burger', price: 80, gstRate: 5, quantity: 1),
            BillItem(itemId: 3002, productId: 102, productName: 'Veg Burger', price: 60, gstRate: 5, quantity: 1),
          ],
        ),
      ],
    );
  }

  void _save() {
    final state = {
      'orders': orders.map((o) => o.toJson()).toList(),
      'stock': {for (final p in products) '${p.id}': p.stock},
      'cart': cart.map((l) => l.toJson()).toList(),
      'selected_canteen_id': selectedCanteenId,
      'pickup_slot': pickupSlot,
      'next_code_seed': _nextCodeSeed,
    };
    _prefs.setString(_stateKey, jsonEncode(state));
  }

  /// Save and redraw. Every change goes through here.
  void _changed() {
    _save();
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

  bool get hasActiveOrder => orders.any((o) =>
      o.status == 'paid' &&
      o.userId == currentUser.userId &&
      o.bills.any((b) => const ['waiting_for_acceptance', 'accepted', 'preparing', 'ready'].contains(b.status)));

  List<StallBill> getStudentBills() {
    final bills = orders.where((o) => o.status == 'paid' && o.userId == currentUser.userId).expand((o) => o.bills).toList();
    bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bills;
  }

  String getLiveBusyLevel(int canteenId) {
    final open = stalls.where((s) => s.canteenId == canteenId && s.status == 'open').length;
    if (open == 0) return 'Low';
    final active = orders
        .where((o) => o.status == 'paid' && o.canteenId == canteenId)
        .expand((o) => o.bills)
        .where((b) => const ['waiting_for_acceptance', 'accepted', 'preparing', 'ready'].contains(b.status))
        .length;
    final ratio = active / open;
    if (ratio < 4) return 'Low';
    if (ratio < 12) return 'Medium';
    return 'High';
  }

  // ---------------- login ----------------
  void completeStudentLogin(String name, String phone, String regNo) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final id = digits == _demoPhone ? 1 : (int.tryParse(digits.length > 10 ? digits.substring(digits.length - 10) : digits) ?? DateTime.now().millisecondsSinceEpoch);
    currentUser = UserProfile(
      userId: id,
      name: name.isEmpty ? 'Student' : name,
      phone: phone.isEmpty ? '9876543210' : phone,
      registerNo: regNo.isEmpty ? 'CAMPUS-2026' : regNo,
      isLoggedIn: true,
    );
    _prefs.setString(_userKey, jsonEncode(currentUser.toJson()));
    _changed();
  }

  void logoutStudent() {
    currentUser = currentUser.copyWith(isLoggedIn: false);
    cart = [];
    // Remember the signed-out state; removing it would sign the demo student back in on restart.
    _prefs.setString(_userKey, jsonEncode(currentUser.toJson()));
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
    if (isHoldActive) _startHoldTimer();
    notifyListeners();
  }

  // ---------------- cart ----------------
  /// Returns null on success, or the reason it could not be added.
  String? addToCart(Product product, [int quantity = 1]) {
    final canteen = canteenById(product.canteenId);
    if (canteen == null || canteen.status != 'open') return 'This canteen is currently closed.';
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
  CheckoutResult startCheckout() {
    if (cart.isEmpty) return const CheckoutResult(success: false, message: 'Cart is empty');
    for (final line in cart) {
      final p = productById(line.productId)!;
      final stall = stallById(p.stallId);
      if (stall == null || stall.status != 'open') {
        return CheckoutResult(success: false, message: '${stall?.name ?? 'Stall'} is currently ${stall?.status ?? 'closed'}. Please remove their items.');
      }
    }
    final shortages = <StockShortage>[];
    for (final line in cart) {
      final p = productById(line.productId)!;
      if (line.quantity > p.stock) shortages.add(StockShortage(product: p, requested: line.quantity, available: p.stock));
    }
    if (shortages.isNotEmpty) {
      stockShortages = shortages;
      notifyListeners();
      return const CheckoutResult(success: false, shortage: true);
    }

    final orderId = DateTime.now().millisecondsSinceEpoch;
    final canteenId = productById(cart.first.productId)!.canteenId;
    final canteen = canteenById(canteenId)!;
    final byStall = <int, List<CartLine>>{};
    for (final line in cart) {
      byStall.putIfAbsent(productById(line.productId)!.stallId, () => []).add(line);
    }
    final bills = <StallBill>[];
    byStall.forEach((stallId, lines) {
      final stall = stallById(stallId)!;
      final subtotal = lines.fold<double>(0, (s, l) => s + productById(l.productId)!.price * l.quantity);
      final tax = _round2(subtotal * stall.gstRate / 100);
      final stallOrderId = orderId + stallId;
      var i = 0;
      bills.add(StallBill(
        stallOrderId: stallOrderId, orderId: orderId, stallId: stallId, canteenId: canteenId,
        stallName: stall.name, billPrefix: stall.billPrefix, subtotal: subtotal, tax: tax,
        total: _round2(subtotal + tax), status: 'awaiting_payment', estimatedTimeMins: stall.avgPrepMins,
        createdAt: DateTime.now(),
        items: lines.map((l) {
          final p = productById(l.productId)!;
          return BillItem(itemId: stallOrderId * 10 + i++, productId: p.id, productName: p.name, price: p.price, gstRate: stall.gstRate, quantity: l.quantity);
        }).toList(),
      ));
    });
    final sub = bills.fold<double>(0, (s, b) => s + b.subtotal);
    final tax = _round2(bills.fold<double>(0, (s, b) => s + b.tax));
    final order = Order(
      orderId: orderId, userId: currentUser.userId, canteenId: canteenId, canteenName: canteen.name,
      subtotal: sub, tax: tax, convenienceFee: convenienceFee, total: _round2(sub + tax + convenienceFee),
      pickupSlot: pickupSlot, status: 'pending', createdAt: DateTime.now(), bills: bills,
    );
    for (final line in cart) {
      final p = productById(line.productId)!;
      p.stock = max(0, p.stock - line.quantity);
    }
    activePendingOrder = order;
    orders.insert(0, order);
    isHoldActive = true;
    holdSecondsLeft = 300;
    _startHoldTimer();
    _changed();
    return const CheckoutResult(success: true);
  }

  void _startHoldTimer() {
    _holdTimer?.cancel();
    final ms = max(100, (1000 / demoClockMultiplier).floor());
    _holdTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
      if (!isHoldActive) {
        _holdTimer?.cancel();
        return;
      }
      if (holdSecondsLeft <= 1) {
        holdSecondsLeft = 0;
        isHoldActive = false;
        _holdTimer?.cancel();
        holdExpiredCount++;
        final pending = activePendingOrder;
        if (pending != null) {
          pending.status = 'expired';
          _releaseStock(pending);
        }
        activePendingOrder = null;
        _changed();
      } else {
        holdSecondsLeft--;
        notifyListeners();
      }
    });
  }

  void _releaseStock(Order o) {
    for (final it in o.bills.expand((b) => b.items)) {
      productById(it.productId)?.stock += it.quantity;
    }
  }

  void handleShortageChoice(int productId, bool takeAvailable) {
    StockShortage? s;
    for (final x in stockShortages) {
      if (x.product.id == productId) s = x;
    }
    if (s == null) return;
    if (takeAvailable && s.available > 0) {
      for (final l in cart) {
        if (l.productId == productId) l.quantity = s.available;
      }
    } else {
      cart.removeWhere((l) => l.productId == productId);
    }
    stockShortages = stockShortages.where((x) => x.product.id != productId).toList();
    _changed();
  }

  void clearShortages() {
    stockShortages = [];
    notifyListeners();
  }

  void cancelCheckoutHold() {
    final pending = activePendingOrder;
    if (pending != null) {
      _releaseStock(pending);
      pending.status = 'cancelled';
    }
    isHoldActive = false;
    _holdTimer?.cancel();
    activePendingOrder = null;
    _changed();
  }

  /// Simulated payment (same as the React app): no money is charged.
  Future<int?> completeUpiPayment(String method) async {
    final pending = activePendingOrder;
    if (pending == null) return null;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (activePendingOrder != pending) return null; // hold expired or cancelled meanwhile
    var idx = 0;
    for (final b in pending.bills) {
      b.billNo = '${b.billPrefix}-${100 + _rand.nextInt(900)}';
      b.status = 'waiting_for_acceptance';
      b.createdAt = DateTime.now();
      idx++;
    }
    pending.status = 'paid';
    cart = [];
    isHoldActive = false;
    _holdTimer?.cancel();
    activePendingOrder = null;
    _changed();
    return idx > 0 ? pending.orderId : null;
  }

  // ---------------- after payment ----------------
  StallBill? _bill(int stallOrderId) {
    for (final o in orders) {
      for (final b in o.bills) {
        if (b.stallOrderId == stallOrderId) return b;
      }
    }
    return null;
  }

  void cancelStudentBill(int stallOrderId) {
    final b = _bill(stallOrderId);
    if (b == null || !const ['waiting_for_acceptance', 'accepted', 'new'].contains(b.status)) return;
    b.status = 'refunded';
    b.cancelReason = 'Student cancelled';
    for (final it in b.items) {
      productById(it.productId)?.stock += it.quantity;
    }
    _changed();
  }

  /// Demo stand-in for the stall accepting the order: assigns the 3-digit pickup code.
  void vendorAcceptOrder(int stallOrderId, [int prepMins = 6]) {
    final b = _bill(stallOrderId);
    if (b == null) return;
    final code = _nextCodeSeed.toString().padLeft(3, '0');
    _nextCodeSeed = _nextCodeSeed >= 999 ? 100 : _nextCodeSeed + 1;
    b.status = 'accepted';
    b.pickupCode = code;
    b.estimatedTimeMins = prepMins;
    b.estimatedReadyTime = formatTime2Digit(DateTime.now().add(Duration(minutes: prepMins)));
    _changed();
  }

  void handOverBill(int stallOrderId) {
    final b = _bill(stallOrderId);
    if (b == null) return;
    b.status = 'completed';
    b.isBlurredSealed = true;
    _changed();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
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
