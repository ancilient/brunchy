import 'package:equatable/equatable.dart';
import '../../data/models/order.dart';
import '../../data/models/order_filter.dart';
import '../../services/realtime_connection_state.dart';

abstract class OrdersState extends Equatable {
  const OrdersState();
  @override List<Object?> get props => [];
}

class OrdersInitial extends OrdersState { const OrdersInitial(); }
class OrdersLoading extends OrdersState { const OrdersLoading(); }
class OrdersError   extends OrdersState {
  final String message;
  const OrdersError(this.message);
  @override List<Object?> get props => [message];
}

class OrdersLoaded extends OrdersState {
  final List<Order> newOrders; // Queued orders
  final List<Order> preparingOrders; // Accepted / Preparing orders
  final List<Order> readyOrders; // Ready orders
  final List<Order> allOrders;
  final OrderFilter activeFilter;
  final RealtimeConnectionState connectionState;
  final int maxCapacity;
  final bool isOverrideActive;

  const OrdersLoaded({
    required this.newOrders,
    required this.preparingOrders,
    required this.readyOrders,
    required this.allOrders,
    required this.activeFilter,
    required this.connectionState,
    this.maxCapacity = 15,
    this.isOverrideActive = false,
  });

  int get newOrderCount => newOrders.length;
  int get preparingCount => preparingOrders.length;
  int get readyCount => readyOrders.length;

  /// Aggregated Make List across all active Preparing orders
  Map<String, int> get makeList {
    final map = <String, int>{};
    for (final order in preparingOrders) {
      for (final item in order.items) {
        map[item.name] = (map[item.name] ?? 0) + item.quantity;
      }
    }
    return map;
  }

  /// Overload protection levels:
  /// Level 0: Normal
  /// Level 1: queue >= 15 -> THROTTLED with estimated wait
  /// Level 2: queue >= 30 -> Menu Trim (complex items hidden)
  /// Level 3: queue >= 45 -> Gridlock (auto-Pause)
  int get overloadLevel {
    if (isOverrideActive) return 0;
    if (newOrders.length >= 45) return 3;
    if (newOrders.length >= 30) return 2;
    if (newOrders.length >= 15) return 1;
    return 0;
  }

  String get overloadStatusText {
    switch (overloadLevel) {
      case 1:
        return 'THROTTLED • Est. wait ~${newOrders.length * 2} min';
      case 2:
        return 'OVERLOAD: MENU TRIM • Complex items hidden';
      case 3:
        return 'GRIDLOCK • Stall paused to clear rush';
      default:
        return 'Normal flow';
    }
  }

  /// Groups queued orders into 2-minute time batches (FIFO)
  Map<String, List<Order>> get batches {
    final map = <String, List<Order>>{};
    if (newOrders.isEmpty) return map;

    final sorted = List<Order>.from(newOrders)..sort((a, b) => a.placedAt.compareTo(b.placedAt));
    int batchIndex = 0;
    DateTime? windowStart;

    for (final order in sorted) {
      if (windowStart == null || order.placedAt.difference(windowStart).inSeconds > 120) {
        windowStart = order.placedAt;
        batchIndex++;
      }
      final letter = String.fromCharCode(64 + ((batchIndex - 1) % 26 + 1));
      final batchKey = 'Batch $letter';
      map.putIfAbsent(batchKey, () => []).add(order);
    }
    return map;
  }

  OrdersLoaded copyWith({
    List<Order>? newOrders,
    List<Order>? preparingOrders,
    List<Order>? readyOrders,
    List<Order>? allOrders,
    OrderFilter? activeFilter,
    RealtimeConnectionState? connectionState,
    int? maxCapacity,
    bool? isOverrideActive,
  }) => OrdersLoaded(
        newOrders: newOrders ?? this.newOrders,
        preparingOrders: preparingOrders ?? this.preparingOrders,
        readyOrders: readyOrders ?? this.readyOrders,
        allOrders: allOrders ?? this.allOrders,
        activeFilter: activeFilter ?? this.activeFilter,
        connectionState: connectionState ?? this.connectionState,
        maxCapacity: maxCapacity ?? this.maxCapacity,
        isOverrideActive: isOverrideActive ?? this.isOverrideActive,
      );

  @override
  List<Object?> get props => [
    newOrders,
    preparingOrders,
    readyOrders,
    allOrders,
    activeFilter,
    connectionState,
    maxCapacity,
    isOverrideActive,
  ];
}

class OrderActionInProgress extends OrdersState {
  final String orderId;
  final OrdersLoaded base;
  const OrderActionInProgress({required this.orderId, required this.base});
  @override List<Object?> get props => [orderId];
}

class OrderActionError extends OrdersState {
  final String orderId;
  final String message;
  final OrdersLoaded base;
  const OrderActionError({required this.orderId, required this.message, required this.base});
  @override List<Object?> get props => [orderId, message];
}
