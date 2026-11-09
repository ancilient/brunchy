// Turns the backend's JSON (docs/api/openapi.yaml: camelCase, string ids) into the app's existing model classes,
// so the screens did not need to change. Server bill statuses are translated to the names the screens already use.
import '../state/app_state.dart' show formatTime2Digit;
import '../state/models.dart';

int _id(Object? v) => v is int ? v : int.parse(v as String);
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime? _time(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

Canteen canteenFromApi(Map<String, dynamic> j, {int distanceMeters = 0}) => Canteen(
      id: _id(j['id']),
      name: j['name'] as String,
      openingTime: j['openingTime'] as String,
      closingTime: j['closingTime'] as String,
      // "open" only while the canteen actually takes orders (hours and last-order time included).
      status: (j['takingOrders'] as bool? ?? false) ? 'open' : 'closed',
      distanceMeters: distanceMeters,
    );

Stall stallFromApi(Map<String, dynamic> j, int canteenId) => Stall(
      id: _id(j['id']),
      canteenId: canteenId,
      name: j['name'] as String,
      billPrefix: j['billPrefix'] as String,
      gstRate: _num(j['gstRate']),
      status: j['status'] as String,
      accentColor: (j['accentColor'] as String?) ?? '#E63E11',
      avgPrepMins: (j['avgPrepMinutes'] as num?)?.toInt() ?? 5,
    );

Product productFromApi(Map<String, dynamic> j, int canteenId) => Product(
      id: _id(j['id']),
      stallId: _id(j['stallId']),
      canteenId: canteenId,
      name: j['name'] as String,
      category: (j['category'] as String?) ?? '',
      price: _num(j['price']),
      stock: (j['stockQuantity'] as num).toInt(),
      approvalStatus: 'published', // the menu endpoint only returns published items
      isActive: true,
    );

/// Server status -> the status names the screens use.
String _billStatus(String s) => switch (s) {
      'new' => 'waiting_for_acceptance',
      'collected' => 'completed',
      'cancelled' => 'refunded', // a cancelled paid bill is refunded
      _ => s, // awaiting_payment, accepted, preparing, ready, rejected, expired, refunded
    };

const _reasonText = {
  'CANCELLED_BY_USER': 'Cancelled by you',
  'OUT_OF_STOCK': 'Out of stock',
  'ITEM_UNAVAILABLE': 'Item unavailable',
  'KITCHEN_ISSUE': 'Kitchen issue',
  'STALL_EMERGENCY': 'Stall emergency',
  'STALL_REJECTED': 'Stall could not take the order',
};

StallBill billFromApi(Map<String, dynamic> j) {
  final created = _time(j['createdAt']) ?? DateTime.now();
  final accepted = _time(j['acceptedAt']);
  final eta = _time(j['estimatedReadyAt']);
  final status = _billStatus(j['status'] as String);
  final billNo = (j['billNo'] as String?) ?? '';
  return StallBill(
    stallOrderId: _id(j['id']),
    orderId: _id(j['orderId']),
    stallId: _id(j['stallId']),
    canteenId: _id(j['canteenId']),
    stallName: j['stallName'] as String,
    billPrefix: billNo.contains('-') ? billNo.split('-').first : '',
    billNo: billNo,
    pickupCode: (j['pickupCode'] as String?) ?? '',
    subtotal: _num(j['subtotal']),
    tax: _num(j['tax']),
    total: _num(j['total']),
    status: status,
    estimatedTimeMins: (accepted != null && eta != null) ? eta.difference(accepted).inMinutes.clamp(1, 120) : 5,
    estimatedReadyTime: eta == null ? null : formatTime2Digit(eta),
    createdAt: created,
    cancelReason: _reasonText[j['cancelReason']] ?? j['cancelReason'] as String?,
    isBlurredSealed: status == 'completed',
    items: (j['items'] as List)
        .map((e) => e as Map<String, dynamic>)
        .map((i) => BillItem(
              itemId: _id(i['id']),
              productId: _id(i['productId']),
              productName: i['name'] as String,
              price: _num(i['price']),
              gstRate: _num(i['gstRate']),
              quantity: (i['quantity'] as num).toInt(),
              itemStatus: (i['status'] as String?) ?? 'active',
            ))
        .toList(),
  );
}

Order orderFromApi(Map<String, dynamic> j, {String pickupSlot = 'now'}) => Order(
      orderId: _id(j['id']),
      userId: _id(j['userId']),
      canteenId: _id(j['canteenId']),
      canteenName: j['canteenName'] as String,
      subtotal: _num(j['subtotal']),
      tax: _num(j['tax']),
      convenienceFee: _num(j['convenienceFee']),
      total: _num(j['total']),
      pickupSlot: pickupSlot,
      status: j['status'] as String,
      createdAt: _time(j['createdAt']) ?? DateTime.now(),
      bills: (j['bills'] as List).map((b) => billFromApi(b as Map<String, dynamic>)).toList(),
    );

UserProfile userFromApi(Map<String, dynamic> j) => UserProfile(
      userId: _id(j['id']),
      name: j['name'] as String,
      phone: (j['phone'] as String?) ?? '',
      registerNo: (j['registerNo'] as String?) ?? '',
      isLoggedIn: true,
    );
