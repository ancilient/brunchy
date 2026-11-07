import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/data/models/order.dart';
import 'package:brunchy_vendor/data/models/order_item.dart';
import 'package:brunchy_vendor/data/models/order_status.dart';
import 'package:brunchy_vendor/data/models/order_filter.dart';
import 'package:brunchy_vendor/features/orders/orders_state.dart';
import 'package:brunchy_vendor/services/realtime_connection_state.dart';

void main() {
  group('Capacity Gate & Overload Unit Tests', () {
    test('OrdersLoaded aggregates makeList across preparing orders', () {
      final order1 = Order(
        id: 'o_1',
        billNumber: 'B1',
        counterCode: '101',
        studentFirstName: 'Aman',
        stallId: 'stall_1',
        status: OrderStatus.accepted,
        totalAmount: 150,
        placedAt: DateTime.now(),
        items: const [
          OrderItem(menuItemId: 'm1', name: 'Chicken Roll', price: 75, quantity: 2),
          OrderItem(menuItemId: 'm2', name: 'French Fries', price: 40, quantity: 1),
        ],
      );

      final order2 = Order(
        id: 'o_2',
        billNumber: 'B2',
        counterCode: '102',
        studentFirstName: 'Priya',
        stallId: 'stall_1',
        status: OrderStatus.accepted,
        totalAmount: 190,
        placedAt: DateTime.now(),
        items: const [
          OrderItem(menuItemId: 'm1', name: 'Chicken Roll', price: 75, quantity: 1),
          OrderItem(menuItemId: 'm3', name: 'Cold Coffee', price: 50, quantity: 2),
        ],
      );

      final state = OrdersLoaded(
        newOrders: const [],
        preparingOrders: [order1, order2],
        readyOrders: const [],
        allOrders: [order1, order2],
        activeFilter: OrderFilter.preparing,
        connectionState: RealtimeConnectionState.connected,
        maxCapacity: 15,
      );

      expect(state.makeList['Chicken Roll'], equals(3));
      expect(state.makeList['French Fries'], equals(1));
      expect(state.makeList['Cold Coffee'], equals(2));
    });

    test('Overload protection levels trigger based on queue count', () {
      List<Order> makeQueue(int count) => List.generate(
            count,
            (i) => Order(
              id: 'q_$i',
              billNumber: 'B$i',
              counterCode: '${100 + i}',
              studentFirstName: 'Student $i',
              stallId: 'stall_1',
              status: OrderStatus.placed,
              totalAmount: 50,
              placedAt: DateTime.now().subtract(Duration(minutes: i)),
              items: const [],
            ),
          );

      final normalState = OrdersLoaded(
        newOrders: makeQueue(5),
        preparingOrders: const [],
        readyOrders: const [],
        allOrders: makeQueue(5),
        activeFilter: OrderFilter.newOrders,
        connectionState: RealtimeConnectionState.connected,
      );
      expect(normalState.overloadLevel, equals(0));

      final throttledState = OrdersLoaded(
        newOrders: makeQueue(16),
        preparingOrders: const [],
        readyOrders: const [],
        allOrders: makeQueue(16),
        activeFilter: OrderFilter.newOrders,
        connectionState: RealtimeConnectionState.connected,
      );
      expect(throttledState.overloadLevel, equals(1));
      expect(throttledState.overloadStatusText, contains('THROTTLED'));

      final menuTrimState = OrdersLoaded(
        newOrders: makeQueue(32),
        preparingOrders: const [],
        readyOrders: const [],
        allOrders: makeQueue(32),
        activeFilter: OrderFilter.newOrders,
        connectionState: RealtimeConnectionState.connected,
      );
      expect(menuTrimState.overloadLevel, equals(2));
      expect(menuTrimState.overloadStatusText, contains('MENU TRIM'));

      final gridlockState = OrdersLoaded(
        newOrders: makeQueue(50),
        preparingOrders: const [],
        readyOrders: const [],
        allOrders: makeQueue(50),
        activeFilter: OrderFilter.newOrders,
        connectionState: RealtimeConnectionState.connected,
      );
      expect(gridlockState.overloadLevel, equals(3));
      expect(gridlockState.overloadStatusText, contains('GRIDLOCK'));

      // Vendor override resets overloadLevel to 0
      final overriddenState = gridlockState.copyWith(isOverrideActive: true);
      expect(overriddenState.overloadLevel, equals(0));
    });

    test('Batch grouping clusters orders within 2 minutes', () {
      final now = DateTime.now();
      final batch1Orders = [
        Order(id: 'b1_1', billNumber: 'B1', counterCode: '101', studentFirstName: 'A', stallId: 's1', status: OrderStatus.placed, totalAmount: 50, placedAt: now, items: const []),
        Order(id: 'b1_2', billNumber: 'B2', counterCode: '102', studentFirstName: 'B', stallId: 's1', status: OrderStatus.placed, totalAmount: 50, placedAt: now.add(const Duration(seconds: 40)), items: const []),
      ];
      final batch2Orders = [
        Order(id: 'b2_1', billNumber: 'B3', counterCode: '103', studentFirstName: 'C', stallId: 's1', status: OrderStatus.placed, totalAmount: 50, placedAt: now.add(const Duration(minutes: 3)), items: const []),
      ];

      final state = OrdersLoaded(
        newOrders: [...batch1Orders, ...batch2Orders],
        preparingOrders: const [],
        readyOrders: const [],
        allOrders: [...batch1Orders, ...batch2Orders],
        activeFilter: OrderFilter.newOrders,
        connectionState: RealtimeConnectionState.connected,
      );

      final batches = state.batches;
      expect(batches.containsKey('Batch A'), isTrue);
      expect(batches.containsKey('Batch B'), isTrue);
      expect(batches['Batch A']!.length, equals(2));
      expect(batches['Batch B']!.length, equals(1));
    });
  });
}

