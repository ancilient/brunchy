import 'package:brunchy_vendor/data/mock/mock_order_repository.dart';
import 'package:brunchy_vendor/data/mock/mock_stall_control_repository.dart';
import 'package:brunchy_vendor/data/models/order_status.dart';
import 'package:brunchy_vendor/data/models/stall_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mock stall control', () {
    late MockOrderRepository orders;
    late MockStallControlRepository controls;

    setUp(() {
      orders = MockOrderRepository();
      controls = MockStallControlRepository(orders);
      orders.isStallOpen = controls.isOpenSync;
    });

    test(
        'emergency stop refunds queued orders but preserves preparing and ready',
        () async {
      final before = await orders.getOrders(stallId: 'stall_001');
      final queued = before
          .where((o) => o.status == OrderStatus.placed)
          .map((o) => o.id)
          .toSet();
      final preparing = before
          .where((o) => o.status == OrderStatus.accepted)
          .map((o) => o.id)
          .toSet();
      final ready = before
          .where((o) => o.status == OrderStatus.ready)
          .map((o) => o.id)
          .toSet();

      final result = await controls.emergencyStop(
          stallId: 'stall_001',
          staffId: 'vendor_1',
          reason: EmergencyStopReason.gasCut,
          idempotencyKey: 'one');
      final after = await orders.getOrders(stallId: 'stall_001');

      expect(result.control.mode, StallOperatingMode.emergencyStopped);
      expect(result.refundedOrderIds.toSet(), queued);
      expect(result.preparingOrderIds.toSet(), preparing);
      expect(
          after
              .where((o) => queued.contains(o.id))
              .every((o) => o.status == OrderStatus.refunded),
          isTrue);
      expect(
          after
              .where((o) => ready.contains(o.id))
              .every((o) => o.status == OrderStatus.ready),
          isTrue);
    });

    test(
        'closed stall rejects direct acceptance while allowing a preparing order to finish',
        () async {
      final before = await orders.getOrders(stallId: 'stall_001');
      final queued = before.firstWhere((o) => o.status == OrderStatus.placed);
      final preparing =
          before.firstWhere((o) => o.status == OrderStatus.accepted);
      await controls.closeForDay(stallId: 'stall_001', staffId: 'vendor_1');

      await expectLater(orders.acceptOrder(queued.id), throwsA(isA<Object>()));
      final ready = await orders.markReady(preparing.id);
      expect(ready.status, OrderStatus.ready);
    });
  });
}
