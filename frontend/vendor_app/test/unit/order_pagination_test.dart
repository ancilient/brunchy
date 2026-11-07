import 'package:brunchy_vendor/data/mock/mock_order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orders respect page and limit', () async {
    final repo = MockOrderRepository();
    final first = await repo.getOrders(stallId: 'stall_001', page: 1, limit: 1);
    final second = await repo.getOrders(stallId: 'stall_001', page: 2, limit: 1);
    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(first.single.id, isNot(second.single.id));
  });
}
