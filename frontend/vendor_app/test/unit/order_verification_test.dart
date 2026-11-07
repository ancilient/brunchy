import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/core/utils/validators.dart';
import 'package:brunchy_vendor/data/models/order_status.dart';
import 'package:brunchy_vendor/data/mock/mock_order_repository.dart';

void main() {
  group('3-Digit Handover Tests', () {
    test('Validators.validateCounterCode enforces 3-digit range (100–999)', () {
      expect(Validators.validateCounterCode('104'), isNull);
      expect(Validators.validateCounterCode('999'), isNull);
      expect(Validators.validateCounterCode('100'), isNull);
      expect(Validators.validateCounterCode('099'), isNotNull);
      expect(Validators.validateCounterCode('12'), isNotNull);
      expect(Validators.validateCounterCode('1234'), isNotNull);
      expect(Validators.validateCounterCode('abc'), isNotNull);
      expect(Validators.validateCounterCode(null), isNotNull);
    });

    test('MockOrderRepository finds order by 3-digit counter code', () async {
      final repo = MockOrderRepository();

      // o_004 has counterCode 104 and status ready
      final order =
          await repo.findOrderByCounterCode(stallId: 'stall_001', code: '104');
      expect(order, isNotNull);
      expect(order!.id, equals('o_004'));
      expect(order.counterCode, equals('104'));
      expect(order.status, equals(OrderStatus.ready));
      expect(order.studentFirstName, equals('Sneha'));

      // Non-existent code returns null
      final missing =
          await repo.findOrderByCounterCode(stallId: 'stall_001', code: '991');
      expect(missing, isNull);
    });

    test('handoverOrder marks status collected and code used', () async {
      final repo = MockOrderRepository();

      final orderBefore =
          await repo.findOrderByCounterCode(stallId: 'stall_001', code: '104');
      expect(orderBefore!.status, equals(OrderStatus.ready));
      expect(orderBefore.isCodeUsed, isFalse);

      final completed =
          await repo.handoverOrder(stallId: 'stall_001', orderId: 'o_004');
      expect(completed.status, equals(OrderStatus.collected));
      expect(completed.isCodeUsed, isTrue);
      expect(completed.collectedAt, isNotNull);

      // A repeated submit is rejected; it must never hand the order over twice.
      expect(
        () => repo.handoverOrder(stallId: 'stall_001', orderId: 'o_004'),
        throwsA(anything),
      );
    });

    test('handoverOrder throws error if order is not ready yet', () async {
      final repo = MockOrderRepository();

      // o_003 is accepted (preparing), not ready
      expect(() => repo.handoverOrder(stallId: 'stall_001', orderId: 'o_003'),
          throwsA(anything));
    });
  });
}
