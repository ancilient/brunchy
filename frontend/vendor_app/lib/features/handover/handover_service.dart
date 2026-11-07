import '../../core/errors/app_exception.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/order.dart';
import '../../data/models/order_status.dart';
import '../../data/repositories/order_repository.dart';
import 'handover_result.dart';

class HandoverService {
  final OrderRepository _orders;
  HandoverService(this._orders);

  Future<HandoverResult> handOver({required String stallId, required Order order, required String code}) async {
    if (code != order.counterCode) return const HandoverResult(HandoverOutcome.wrongCode, message: 'Wrong code. Ask the student again.');
    if (order.status == OrderStatus.collected || order.isCodeUsed) {
      final when = DateFormatter.displayTime(order.collectedAt ?? DateTime.now());
      return HandoverResult(HandoverOutcome.alreadyCollected, order: order, message: 'Already collected at $when');
    }
    if (order.status == OrderStatus.cancelled || order.status == OrderStatus.refunded) {
      return HandoverResult(HandoverOutcome.cancelled, order: order, message: 'Order has been cancelled / refunded');
    }
    if (order.status != OrderStatus.ready) return const HandoverResult(HandoverOutcome.notReady, message: 'Not ready yet. Food is still being prepared.');
    try {
      final updated = await _orders.handoverOrder(stallId: stallId, orderId: order.id);
      return HandoverResult(HandoverOutcome.success, order: updated);
    } on AppException catch (e) {
      if (e.code == 'ORDER_ALREADY_COLLECTED') {
        return HandoverResult(HandoverOutcome.alreadyCollected, order: order, message: e.message);
      }
      if (e.code == 'ORDER_NOT_READY') return HandoverResult(HandoverOutcome.notReady, order: order, message: e.message);
      return HandoverResult(HandoverOutcome.error, order: order, message: e.message);
    } catch (_) {
      return const HandoverResult(HandoverOutcome.offlineQueued, message: 'Offline. Handover will sync when connected.');
    }
  }
}
