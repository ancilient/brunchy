// lib/data/models/order.dart
import 'order_item.dart';
import 'order_status.dart';

class Order {
  final String id;
  final String billNumber;
  final String counterCode; // 3-digit counter code (100–999)
  final String studentFirstName;
  final String stallId;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final DateTime placedAt; // server timestamp
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? collectedAt;
  final bool isPaid;
  final int otpAttempts;
  final DateTime? otpLockedUntil;
  final bool isCodeUsed;

  Order({
    required this.id,
    required this.billNumber,
    this.counterCode = '100',
    this.studentFirstName = 'Student',
    required this.stallId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.placedAt,
    this.acceptedAt,
    this.readyAt,
    this.collectedAt,
    this.isPaid = true,
    this.otpAttempts = 0,
    this.otpLockedUntil,
    this.isCodeUsed = false,
  }) : assert(_isValidCounterCode(counterCode));

  static bool _isValidCounterCode(String value) {
    final parsed = int.tryParse(value);
    return parsed != null && parsed >= 100 && parsed <= 999 && value.length == 3;
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        billNumber: json['billNumber'] as String,
        counterCode: (json['counterCode'] as String?) ?? '100',
        studentFirstName: (json['studentFirstName'] as String?) ?? 'Student',
        stallId: json['stallId'] as String,
        items: (json['items'] as List).map((e) => OrderItem.fromJson(e)).toList(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        status: OrderStatusLabel.fromString(json['status'] as String),
        placedAt: DateTime.parse(json['placedAt'] as String),
        acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt'] as String) : null,
        readyAt: json['readyAt'] != null ? DateTime.parse(json['readyAt'] as String) : null,
        collectedAt: json['collectedAt'] != null ? DateTime.parse(json['collectedAt'] as String) : null,
        isPaid: (json['isPaid'] as bool?) ?? true,
        otpAttempts: (json['otpAttempts'] as int?) ?? 0,
        otpLockedUntil: json['otpLockedUntil'] != null ? DateTime.parse(json['otpLockedUntil'] as String) : null,
        isCodeUsed: (json['isCodeUsed'] as bool?) ?? (json['status'] == 'collected'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'billNumber': billNumber,
        'counterCode': counterCode,
        'studentFirstName': studentFirstName,
        'stallId': stallId,
        'items': items.map((e) => e.toJson()).toList(),
        'totalAmount': totalAmount,
        'status': status.name,
        'placedAt': placedAt.toIso8601String(),
        'acceptedAt': acceptedAt?.toIso8601String(),
        'readyAt': readyAt?.toIso8601String(),
        'collectedAt': collectedAt?.toIso8601String(),
        'isPaid': isPaid,
        'otpAttempts': otpAttempts,
        'otpLockedUntil': otpLockedUntil?.toIso8601String(),
        'isCodeUsed': isCodeUsed,
      };

  Order copyWith({
    String? id,
    String? billNumber,
    String? counterCode,
    String? studentFirstName,
    String? stallId,
    List<OrderItem>? items,
    double? totalAmount,
    OrderStatus? status,
    DateTime? placedAt,
    DateTime? acceptedAt,
    DateTime? readyAt,
    DateTime? collectedAt,
    bool? isPaid,
    int? otpAttempts,
    DateTime? otpLockedUntil,
    bool? isCodeUsed,
  }) =>
      Order(
        id: id ?? this.id,
        billNumber: billNumber ?? this.billNumber,
        counterCode: counterCode ?? this.counterCode,
        studentFirstName: studentFirstName ?? this.studentFirstName,
        stallId: stallId ?? this.stallId,
        items: items ?? this.items,
        totalAmount: totalAmount ?? this.totalAmount,
        status: status ?? this.status,
        placedAt: placedAt ?? this.placedAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        readyAt: readyAt ?? this.readyAt,
        collectedAt: collectedAt ?? this.collectedAt,
        isPaid: isPaid ?? this.isPaid,
        otpAttempts: otpAttempts ?? this.otpAttempts,
        otpLockedUntil: otpLockedUntil ?? this.otpLockedUntil,
        isCodeUsed: isCodeUsed ?? this.isCodeUsed,
      );

  int get secondsUntilAutoCancel {
    const autoCancel = 180;
    final elapsed = DateTime.now().difference(placedAt).inSeconds;
    return (autoCancel - elapsed).clamp(0, autoCancel);
  }

  bool get isAutoCancelUrgent => secondsUntilAutoCancel <= 60 && status == OrderStatus.placed;

  String get itemsSummary {
    final parts = items.map((i) => '${i.name} ×${i.quantity}').toList();
    if (parts.length <= 2) return parts.join(', ');
    return '${parts.take(2).join(', ')} +${parts.length - 2} more';
  }
}
