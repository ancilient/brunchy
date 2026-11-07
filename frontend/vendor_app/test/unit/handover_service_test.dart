import 'package:brunchy_vendor/data/mock/mock_order_repository.dart';
import 'package:brunchy_vendor/features/handover/handover_result.dart';
import 'package:brunchy_vendor/features/handover/handover_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success then second submit is already collected', () async {
    final repository = MockOrderRepository();
    final order = (await repository.findOrderByCounterCode(stallId: 'stall_001', code: '104'))!;
    final service = HandoverService(repository);
    final first = await service.handOver(stallId: 'stall_001', order: order, code: '104');
    final second = await service.handOver(stallId: 'stall_001', order: first.order!, code: '104');
    expect(first.outcome, HandoverOutcome.success);
    expect(second.outcome, HandoverOutcome.alreadyCollected);
  });

  test('wrong code is rejected without repository handover', () async {
    final repository = MockOrderRepository();
    final order = (await repository.findOrderByCounterCode(stallId: 'stall_001', code: '104'))!;
    final result = await HandoverService(repository).handOver(stallId: 'stall_001', order: order, code: '999');
    expect(result.outcome, HandoverOutcome.wrongCode);
  });
}
