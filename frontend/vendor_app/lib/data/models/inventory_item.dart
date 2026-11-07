import 'adjustment_reason.dart';

class InventoryItem {
  final String id;
  final String stallId;
  final String menuItemId;
  final String menuItemName;
  final String date; // YYYY-MM-DD
  final int openingStock; // readonly — from yesterday's closing
  int currentStock; // editable; floor=0, ceiling=openingStock
  AdjustmentReason reason;

  InventoryItem({
    required this.id,
    required this.stallId,
    required this.menuItemId,
    required this.menuItemName,
    required this.date,
    required this.openingStock,
    required this.currentStock,
    this.reason = AdjustmentReason.sale,
  });

  /// soldToday = openingStock - currentStock (computed)
  /// NOTE: This reflects total stock reduction (sales + waste + spoilage).
  /// It may differ from dashboard order count. See R-18 in DESIGN.md.
  int get soldToday => openingStock - currentStock;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        stallId: json['stallId'] as String,
        menuItemId: json['menuItemId'] as String,
        menuItemName: json['menuItemName'] as String,
        date: json['date'] as String,
        openingStock: json['openingStock'] as int,
        currentStock: json['currentStock'] as int,
        reason: AdjustmentReason.sale,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'stallId': stallId,
        'menuItemId': menuItemId,
        'menuItemName': menuItemName,
        'date': date,
        'openingStock': openingStock,
        'currentStock': currentStock,
        'reason': reason.apiValue,
      };

  InventoryItem copyWith({int? currentStock, AdjustmentReason? reason}) => InventoryItem(
        id: id,
        stallId: stallId,
        menuItemId: menuItemId,
        menuItemName: menuItemName,
        date: date,
        openingStock: openingStock,
        currentStock: currentStock ?? this.currentStock,
        reason: reason ?? this.reason,
      );
}

