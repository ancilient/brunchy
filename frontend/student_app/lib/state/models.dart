// Data types, same fields and status names as the React app (src/types/canteen.ts).

class Canteen {
  Canteen({required this.id, required this.name, required this.openingTime, required this.closingTime, required this.status, required this.distanceMeters});
  final int id;
  final String name;
  final String openingTime;
  final String closingTime;
  String status; // 'open' | 'closed'
  final int distanceMeters;

  factory Canteen.fromJson(Map<String, dynamic> j) => Canteen(
        id: j['canteen_id'] as int,
        name: j['canteen_name'] as String,
        openingTime: j['opening_time'] as String,
        closingTime: j['closing_time'] as String,
        status: j['status'] as String,
        distanceMeters: j['distance_meters'] as int,
      );
}

class Stall {
  Stall({required this.id, required this.canteenId, required this.name, required this.billPrefix, required this.gstRate, required this.status, required this.accentColor, required this.avgPrepMins});
  final int id;
  final int canteenId;
  final String name;
  final String billPrefix;
  final double gstRate;
  String status; // 'open' | 'paused' | 'closed'
  final String accentColor; // '#RRGGBB'
  final int avgPrepMins;

  factory Stall.fromJson(Map<String, dynamic> j) => Stall(
        id: j['stall_id'] as int,
        canteenId: j['canteen_id'] as int,
        name: j['stall_name'] as String,
        billPrefix: j['bill_prefix'] as String,
        gstRate: (j['gst_rate'] as num).toDouble(),
        status: j['status'] as String,
        accentColor: j['accent_color'] as String,
        avgPrepMins: (j['avg_prep_time_mins'] as num?)?.toInt() ?? 5,
      );
}

class Product {
  Product({required this.id, required this.stallId, required this.canteenId, required this.name, required this.category, required this.price, required this.stock, required this.approvalStatus, required this.isActive});
  final int id;
  final int stallId;
  final int canteenId;
  final String name;
  final String category;
  final double price;
  int stock;
  final String approvalStatus;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['product_id'] as int,
        stallId: j['stall_id'] as int,
        canteenId: j['canteen_id'] as int,
        name: j['product_name'] as String,
        category: j['category'] as String,
        price: (j['price'] as num).toDouble(),
        stock: (j['stock_quantity'] as num).toInt(),
        approvalStatus: j['approval_status'] as String,
        isActive: j['is_active'] as bool,
      );
}

class CartLine {
  CartLine({required this.productId, required this.quantity});
  final int productId;
  int quantity;
  Map<String, dynamic> toJson() => {'product_id': productId, 'quantity': quantity};
  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(productId: j['product_id'] as int, quantity: j['quantity'] as int);
}

class BillItem {
  BillItem({required this.itemId, required this.productId, required this.productName, required this.price, required this.gstRate, required this.quantity, this.itemStatus = 'active'});
  final int itemId;
  final int productId;
  final String productName;
  final double price;
  final double gstRate;
  final int quantity;
  final String itemStatus; // 'active' | 'unavailable_refunded'

  Map<String, dynamic> toJson() => {
        'item_id': itemId, 'product_id': productId, 'product_name': productName, 'price': price,
        'gst_rate': gstRate, 'quantity': quantity, 'item_status': itemStatus,
      };
  factory BillItem.fromJson(Map<String, dynamic> j) => BillItem(
        itemId: j['item_id'] as int,
        productId: j['product_id'] as int,
        productName: j['product_name'] as String,
        price: (j['price'] as num).toDouble(),
        gstRate: (j['gst_rate'] as num).toDouble(),
        quantity: j['quantity'] as int,
        itemStatus: (j['item_status'] as String?) ?? 'active',
      );
}

class StallBill {
  StallBill({
    required this.stallOrderId, required this.orderId, required this.stallId, required this.canteenId,
    required this.stallName, required this.billPrefix, this.billNo = '', this.pickupCode = '',
    required this.subtotal, required this.tax, required this.total, required this.status,
    required this.estimatedTimeMins, this.estimatedReadyTime, required this.createdAt,
    this.cancelReason, this.isBlurredSealed = false, required this.items,
  });
  final int stallOrderId;
  final int orderId;
  final int stallId;
  final int canteenId;
  final String stallName;
  final String billPrefix;
  String billNo;
  String pickupCode;
  final double subtotal;
  final double tax;
  final double total;
  /// 'awaiting_payment' | 'waiting_for_acceptance' | 'accepted' | 'preparing' | 'ready' | 'completed' | 'collected' | 'refunded' | 'rejected' | 'expired'
  String status;
  int estimatedTimeMins;
  String? estimatedReadyTime;
  DateTime createdAt;
  String? cancelReason;
  bool isBlurredSealed;
  final List<BillItem> items;

  Map<String, dynamic> toJson() => {
        'stall_order_id': stallOrderId, 'order_id': orderId, 'stall_id': stallId, 'canteen_id': canteenId,
        'stall_name': stallName, 'bill_prefix': billPrefix, 'bill_no': billNo, 'pickup_code': pickupCode,
        'subtotal': subtotal, 'tax': tax, 'total': total, 'status': status,
        'estimated_time_mins': estimatedTimeMins, 'estimated_ready_time': estimatedReadyTime,
        'created_at': createdAt.toIso8601String(), 'cancel_reason': cancelReason,
        'is_blurred_sealed': isBlurredSealed, 'items': items.map((i) => i.toJson()).toList(),
      };
  factory StallBill.fromJson(Map<String, dynamic> j) => StallBill(
        stallOrderId: j['stall_order_id'] as int,
        orderId: j['order_id'] as int,
        stallId: j['stall_id'] as int,
        canteenId: j['canteen_id'] as int,
        stallName: j['stall_name'] as String,
        billPrefix: j['bill_prefix'] as String,
        billNo: (j['bill_no'] as String?) ?? '',
        pickupCode: (j['pickup_code'] as String?) ?? '',
        subtotal: (j['subtotal'] as num).toDouble(),
        tax: (j['tax'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
        status: j['status'] as String,
        estimatedTimeMins: (j['estimated_time_mins'] as num?)?.toInt() ?? 5,
        estimatedReadyTime: j['estimated_ready_time'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        cancelReason: j['cancel_reason'] as String?,
        isBlurredSealed: (j['is_blurred_sealed'] as bool?) ?? false,
        items: (j['items'] as List).map((e) => BillItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class Order {
  Order({
    required this.orderId, required this.userId, required this.canteenId, required this.canteenName,
    required this.subtotal, required this.tax, required this.convenienceFee, required this.total,
    required this.pickupSlot, required this.status, required this.createdAt, required this.bills,
  });
  final int orderId;
  final int userId;
  final int canteenId;
  final String canteenName;
  final double subtotal;
  final double tax;
  final double convenienceFee;
  final double total;
  final String pickupSlot;
  String status; // 'pending' | 'paid' | 'expired' | 'cancelled'
  final DateTime createdAt;
  List<StallBill> bills;

  Map<String, dynamic> toJson() => {
        'order_id': orderId, 'user_id': userId, 'canteen_id': canteenId, 'canteen_name': canteenName,
        'subtotal': subtotal, 'tax': tax, 'convenience_fee': convenienceFee, 'total': total,
        'pickup_slot': pickupSlot, 'status': status, 'created_at': createdAt.toIso8601String(),
        'bills': bills.map((b) => b.toJson()).toList(),
      };
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        orderId: j['order_id'] as int,
        userId: j['user_id'] as int,
        canteenId: j['canteen_id'] as int,
        canteenName: j['canteen_name'] as String,
        subtotal: (j['subtotal'] as num).toDouble(),
        tax: (j['tax'] as num).toDouble(),
        convenienceFee: (j['convenience_fee'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
        pickupSlot: j['pickup_slot'] as String,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        bills: (j['bills'] as List).map((e) => StallBill.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class UserProfile {
  UserProfile({required this.userId, required this.name, required this.phone, required this.registerNo, required this.isLoggedIn});
  final int userId;
  final String name;
  final String phone;
  final String registerNo;
  final bool isLoggedIn;

  UserProfile copyWith({bool? isLoggedIn}) =>
      UserProfile(userId: userId, name: name, phone: phone, registerNo: registerNo, isLoggedIn: isLoggedIn ?? this.isLoggedIn);
  Map<String, dynamic> toJson() => {'user_id': userId, 'name': name, 'phone': phone, 'register_no': registerNo, 'is_logged_in': isLoggedIn};
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        userId: j['user_id'] as int,
        name: j['name'] as String,
        phone: j['phone'] as String,
        registerNo: (j['register_no'] as String?) ?? '',
        isLoggedIn: (j['is_logged_in'] as bool?) ?? false,
      );
}

class StockShortage {
  StockShortage({required this.product, required this.requested, required this.available});
  final Product product;
  final int requested;
  final int available;
}

class CheckoutResult {
  const CheckoutResult({required this.success, this.shortage = false, this.message});
  final bool success;
  final bool shortage;
  final String? message;
}
