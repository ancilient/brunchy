import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/data/models/order.dart';
import 'package:brunchy_vendor/data/models/order_status.dart';
import 'package:brunchy_vendor/data/models/order_item.dart';

void main() {
  group('Order Model Tests', () {
    test('Order totalAmount and items summary', () {
      final order = Order(
        id: 'o_1',
        billNumber: '101',
        stallId: 'stall_1',
        status: OrderStatus.placed,
        totalAmount: 210.0,
        placedAt: DateTime.now(),
        items: const [
          OrderItem(menuItemId: 'm1', name: 'Veg Burger', price: 80, quantity: 2),
          OrderItem(menuItemId: 'm2', name: 'Cold Coffee', price: 50, quantity: 1),
        ],
      );

      expect(order.totalAmount, equals(210.0));
      expect(order.items.length, equals(2));
      expect(order.isAutoCancelUrgent, isFalse);
    });

    test('Order autoCancelUrgent flags when under 60 seconds remain', () {
      final oldOrder = Order(
        id: 'o_2',
        billNumber: '102',
        stallId: 'stall_1',
        status: OrderStatus.placed,
        totalAmount: 80.0,
        placedAt: DateTime.now().subtract(const Duration(seconds: 150)),
        items: const [
          OrderItem(menuItemId: 'm1', name: 'Veg Burger', price: 80, quantity: 1),
        ],
      );

      expect(oldOrder.secondsUntilAutoCancel, lessThanOrEqualTo(60));
      expect(oldOrder.isAutoCancelUrgent, isTrue);
    });

    test('Order rejects pickup codes outside 100 through 999', () {
      expect(
        () => Order(
          id: 'o_invalid', billNumber: 'B1', counterCode: '099', stallId: 'stall_1',
          items: const [], totalAmount: 0, status: OrderStatus.placed, placedAt: DateTime.now(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
