import '../../data/models/order.dart';

enum HandoverOutcome { success, wrongCode, notReady, alreadyCollected, cancelled, offlineQueued, error }

class HandoverResult {
  final HandoverOutcome outcome;
  final Order? order;
  final String message;
  const HandoverResult(this.outcome, {this.order, this.message = ''});
  bool get isSuccess => outcome == HandoverOutcome.success;
}
