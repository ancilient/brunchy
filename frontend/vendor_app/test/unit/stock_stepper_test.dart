import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/data/models/menu_item.dart';

void main() {
  group('Stock Stepper & Thresholds Unit Tests', () {
    test('MenuItem stock status indicators behave as expected', () {
      const inStock = MenuItem(
        id: 'm1',
        stallId: 's1',
        name: 'Veg Burger',
        price: 60,
        isAvailable: true,
        stock: 12,
      );
      expect(inStock.isSoldOut, isFalse);
      expect(inStock.isLowStock, isFalse);

      const lowStock = MenuItem(
        id: 'm2',
        stallId: 's1',
        name: 'Chicken Roll',
        price: 75,
        isAvailable: true,
        stock: 4, // <= 5
      );
      expect(lowStock.isSoldOut, isFalse);
      expect(lowStock.isLowStock, isTrue);

      const zeroStock = MenuItem(
        id: 'm3',
        stallId: 's1',
        name: 'Mango Shake',
        price: 60,
        isAvailable: true,
        stock: 0,
      );
      expect(zeroStock.isSoldOut, isTrue);
      expect(zeroStock.isLowStock, isFalse);

      const unavailable = MenuItem(
        id: 'm4',
        stallId: 's1',
        name: 'Cold Coffee',
        price: 50,
        isAvailable: false,
        stock: 10,
      );
      expect(unavailable.isSoldOut, isTrue);
    });

    test('Stepper adjustments clamp and reflect availability changes', () {
      var item = const MenuItem(
        id: 'm1',
        stallId: 's1',
        name: 'French Fries',
        price: 40,
        isAvailable: true,
        stock: 1,
      );

      // Decrement to 0
      final decremented = item.copyWith(
        stock: item.stock - 1,
        isAvailable: (item.stock - 1) > 0,
      );
      expect(decremented.stock, equals(0));
      expect(decremented.isAvailable, isFalse);
      expect(decremented.isSoldOut, isTrue);

      // Quick restock +10
      final restocked = decremented.copyWith(
        stock: decremented.stock + 10,
        isAvailable: true,
      );
      expect(restocked.stock, equals(10));
      expect(restocked.isAvailable, isTrue);
      expect(restocked.isSoldOut, isFalse);
      expect(restocked.isLowStock, isFalse);
    });
  });
}

