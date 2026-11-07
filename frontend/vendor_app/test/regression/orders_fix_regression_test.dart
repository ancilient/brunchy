import 'package:flutter_test/flutter_test.dart';

/// Stage-1 reproduction tests. They deliberately fail until the Orders fixes land.
void main() {
  testWidgets('B1 Reject leaves the Orders screen visible', (tester) async {
    expect(false, isTrue, reason: 'Reject dialog has no result-owned navigator contract yet.');
  });

  test('B2 Fire Batch reports capacity-full or starts the available orders', () {
    expect(false, isTrue, reason: 'fireBatch silently returns at full capacity.');
  });

  test('B3 Ready All completes its batch and reports its result', () {
    expect(false, isTrue, reason: 'readyBatch suppresses action failures and returns no result.');
  });

  test('B4 deadline auto-starts an order at zero even over capacity', () {
    expect(false, isTrue, reason: 'no repository deadline/ticker exists.');
  });

  test('B5 accepting-orders state persists per stall and refuses arrivals', () {
    expect(false, isTrue, reason: 'accepting-orders state does not exist.');
  });
}
