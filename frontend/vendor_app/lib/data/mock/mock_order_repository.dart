// lib/data/mock/mock_order_repository.dart
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import '../../data/models/order.dart';
import '../../data/models/order_status.dart';
import '../../data/models/cancel_reason.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_formatter.dart';
import '../mock/mock_data.dart';

class MockOrderRepository implements OrderRepository {
  final List<Order> _orders = MockData.buildOrders();
  final _controller =
      StreamController<({String event, Order order})>.broadcast();
  bool Function(String stallId) isStallOpen = (_) => true;
  bool Function(String stallId) isAcceptingOrders = (_) => true;
  // TODO(BACKEND-API): API-032 PUT /vendor/stall/accepting

  @override
  Future<List<Order>> getOrders({
    required String stallId,
    String? date,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    // TODO(BACKEND-API): API-005 GET /stalls/{stallId}/orders
    await Future.delayed(const Duration(milliseconds: 300));
    var result = _orders.where((o) => o.stallId == stallId).toList();
    if (date != null) {
      result = result.where((o) => DateFormatter.dateKey(o.placedAt) == date).toList();
    }
    if (status != null) {
      result = result.where((o) => o.status.name == status).toList();
    }
    result.sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final start = (page - 1).clamp(0, result.length);
    final end = (start + limit).clamp(start, result.length);
    return result.sublist(start, end);
  }

  @override
  Stream<({String event, Order order})> watchOrders(String stallId) {
    // TODO(BACKEND-API): API-006 WS /ws/stalls/{stallId}/orders
    return _controller.stream;
  }

  void _emit(String event, Order order) {
    _controller.add((event: event, order: order));
  }

  /// Atomic mock equivalent of API-024: refund only not-started orders.
  List<String> emergencyStopAndRefundPlaced(String stallId) {
    final ids = <String>[];
    for (var i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (order.stallId == stallId && order.status == OrderStatus.placed) {
        final updated = order.copyWith(status: OrderStatus.refunded);
        _orders[i] = updated;
        ids.add(updated.id);
        _emit('order_updated', updated);
      }
    }
    return ids;
  }

  List<String> preparingIds(String stallId) => _orders
      .where((o) => o.stallId == stallId && o.status == OrderStatus.accepted)
      .map((o) => o.id)
      .toList();

  @override
  Future<Order> acceptOrder(String orderId) async {
    // TODO(BACKEND-API): API-007 PATCH /orders/{orderId}/accept
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw AppException.network();
    final order = _orders[idx];
    if (!isStallOpen(order.stallId))
      throw const AppException(
          message: 'Stall is not accepting new orders', code: 'STALL_NOT_OPEN');
    if (order.status != OrderStatus.placed)
      throw const AppException(
          message: 'Only queued orders can start preparing',
          code: 'ORDER_NOT_QUEUED');
    final updated = order.copyWith(
        status: OrderStatus.accepted, acceptedAt: DateTime.now());
    _orders[idx] = updated;
    _emit('order_updated', updated);
    return updated;
  }

  @override
  Future<Order> rejectOrder(String orderId, {CancelReason? reason}) async {
    // TODO(BACKEND-API): API-008 PATCH /orders/{orderId}/reject
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw AppException.network();
    final order = _orders[idx];
    if (!isStallOpen(order.stallId)) {
      throw const AppException(
          message: 'Stall is not accepting order changes', code: 'STALL_NOT_OPEN');
    }
    if (order.status != OrderStatus.placed)
      throw AppException.orderAlreadyCancelled();
    final updated = order.copyWith(status: OrderStatus.refunded);
    _orders[idx] = updated;
    _emit('order_updated', updated);
    return updated;
  }

  @override
  Future<Order> markReady(String orderId) async {
    // TODO(BACKEND-API): API-009 PATCH /orders/{orderId}/ready
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw AppException.network();
    final order = _orders[idx];
    if (order.status != OrderStatus.accepted)
      throw const AppException(
          message: 'Only preparing orders can be marked ready',
          code: 'ORDER_NOT_PREPARING');
    final updated =
        order.copyWith(status: OrderStatus.ready, readyAt: DateTime.now());
    _orders[idx] = updated;
    _emit('order_updated', updated);
    return updated;
  }

  @override
  Future<Order?> findOrderByCounterCode(
      {required String stallId, required String code}) async {
    // TODO(BACKEND-API): API-011 GET /orders/lookup?stallId={stallId}&code={code}
    await Future.delayed(const Duration(milliseconds: 150));
    final trimmed = code.trim();
    try {
      return _orders
          .firstWhere((o) => o.stallId == stallId && o.counterCode == trimmed);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Order> handoverOrder(
      {required String stallId, required String orderId}) async {
    // TODO(BACKEND-API): API-012 POST /orders/{orderId}/handover
    await Future.delayed(const Duration(milliseconds: 250));
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw AppException.network();
    final order = _orders[idx];
    if (order.stallId != stallId) {
      throw const AppException(
          message: 'Order belongs to another stall', code: 'WRONG_STALL');
    }

    if (order.status == OrderStatus.collected || order.isCodeUsed) {
      throw AppException.alreadyCollected();
    }
    if (order.status != OrderStatus.ready) {
      throw const AppException(
          message: 'Order is not ready yet', code: 'ORDER_NOT_READY');
    }

    final updated = order.copyWith(
      status: OrderStatus.collected,
      collectedAt: DateTime.now(),
      isCodeUsed: true,
    );
    _orders[idx] = updated;
    _emit('order_updated', updated);
    return updated;
  }

  @override
  Future<Order> collectOrder(
      {required String orderId, required String otp}) async {
    // Backwards-compatible delegator to handoverOrder
    final order = _orders.firstWhere((item) => item.id == orderId);
    return handoverOrder(stallId: order.stallId, orderId: orderId);
  }

  @override
  Future<Order> cancelOrder(
      {required String orderId, required CancelReason reason}) async {
    // TODO(BACKEND-API): API-020 POST /orders/{orderId}/cancel-refund
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw AppException.network();
    final order = _orders[idx];
    if (!isStallOpen(order.stallId)) {
      throw const AppException(
          message: 'Stall is not accepting order changes', code: 'STALL_NOT_OPEN');
    }
    if (order.status != OrderStatus.placed &&
        order.status != OrderStatus.accepted) {
      throw AppException(
          message: 'Cannot cancel an order that is ${order.status.name}',
          code: 'CANNOT_CANCEL_IN_STATE');
    }
    final updated = order.copyWith(status: OrderStatus.refunded);
    _orders[idx] = updated;
    _emit('order_updated', updated);
    return updated;
  }

  @override
  Future<Order> unreadyOrder(String orderId) async {
    // TODO(BACKEND-API): API-021 POST /orders/{orderId}/unready
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) throw AppException.network();
    final order = _orders[idx];
    if (order.status != OrderStatus.ready) {
      throw const AppException(
          message: 'Order is not in ready state',
          code: 'ORDER_NOT_IN_READY_STATE');
    }
    final readyAt = order.readyAt;
    if (readyAt != null && DateTime.now().difference(readyAt).inSeconds > 5) {
      throw AppException.undoWindowExpired();
    }
    final updated = order.copyWith(status: OrderStatus.accepted);
    _orders[idx] = updated;
    _emit('order_updated', updated);
    return updated;
  }

  void dispose() {
    _controller.close();
  }

  void stopWatching() {}
}
