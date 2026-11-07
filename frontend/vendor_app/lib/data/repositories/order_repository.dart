import 'package:brunchy_vendor/data/models/cancel_reason.dart';
import 'package:brunchy_vendor/data/models/order.dart';

/// Abstract repository for order operations and real-time order streaming.
/// Concrete implementations: [MockOrderRepository] (dev) and a future DioOrderRepository (prod).
abstract class OrderRepository {
  /// [API-005] Fetches a paginated list of orders for the given [stallId].
  /// Optionally filtered by [date] (YYYY-MM-DD) and/or [status] string.
  Future<List<Order>> getOrders({
    required String stallId,
    String? date,
    String? status,
    int page = 1,
    int limit = 50,
  });

  /// [API-006] Opens a WebSocket stream that emits order events.
  /// Each event is a named record with an [event] string
  /// ('new_order' | 'order_updated' | 'order_cancelled') and the affected [order].
  Stream<({String event, Order order})> watchOrders(String stallId);

  /// [API-007] Marks the order as accepted (Preparing).
  /// Throws [AppException.orderAlreadyCancelled] if the order was auto-cancelled.
  Future<Order> acceptOrder(String orderId);

  /// [API-008] Rejects (refunds) the order with an optional [reason].
  /// Throws [AppException] if the order is already cancelled.
  Future<Order> rejectOrder(String orderId, {CancelReason? reason});

  /// [API-009] Marks the order as ready for pickup.
  /// The student notification is delayed 5 seconds server-side (undo window).
  Future<Order> markReady(String orderId);

  /// [API-010] Collects the order after the vendor verifies the student's [otp].
  /// Throws [AppException.otpWrong] on mismatch.
  /// Throws [AppException.otpLocked] after 4 failed attempts.
  /// Throws [AppException.alreadyCollected] if already collected.
  Future<Order> collectOrder({
    required String orderId,
    required String otp,
  });

  /// [API-011] Finds an active or recent order by its 3-digit counter code (100–999).
  Future<Order?> findOrderByCounterCode({
    required String stallId,
    required String code,
  });

  /// [API-012] Completes order handover using the 3-digit counter code. Marks code used and sets status to collected.
  Future<Order> handoverOrder({
    required String stallId,
    required String orderId,
  });

  /// [API-020] Cancels (refunds) the order for the given [reason].
  /// Only valid when status is in [placed, accepted]. Ready orders remain collectable.
  Future<Order> cancelOrder({
    required String orderId,
    required CancelReason reason,
  });

  /// [API-021] Reverts a ready order back to accepted (undo mark-ready).
  /// Throws [AppException.undoWindowExpired] if called after the 5-second window.
  Future<Order> unreadyOrder(String orderId);
}
