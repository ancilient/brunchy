import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/data/models/inventory_item.dart';
import 'package:brunchy_vendor/data/models/adjustment_reason.dart';

void main() {
  group('InventoryItem Unit Tests', () {
    test('soldToday calculates openingStock - currentStock correctly', () {
      final item = InventoryItem(
        id: 'inv_1',
        stallId: 'stall_1',
        menuItemId: 'item_1',
        menuItemName: 'Veg Burger',
        date: '2026-11-06',
        openingStock: 50,
        currentStock: 35,
        reason: AdjustmentReason.sale,
      );

      expect(item.soldToday, equals(15));
    });

    test('soldToday is 0 when openingStock equals currentStock', () {
      final item = InventoryItem(
        id: 'inv_2',
        stallId: 'stall_1',
        menuItemId: 'item_2',
        menuItemName: 'Cold Coffee',
        date: '2026-11-06',
        openingStock: 40,
        currentStock: 40,
      );

      expect(item.soldToday, equals(0));
    });

    test('copyWith updates fields as expected', () {
      final item = InventoryItem(
        id: 'inv_3',
        stallId: 'stall_1',
        menuItemId: 'item_3',
        menuItemName: 'Fries',
        date: '2026-11-06',
        openingStock: 30,
        currentStock: 25,
      );

      final updated = item.copyWith(currentStock: 20, reason: AdjustmentReason.spoilage);
      expect(updated.currentStock, equals(20));
      expect(updated.reason, equals(AdjustmentReason.spoilage));
      expect(updated.openingStock, equals(30));
    });
  });
}
