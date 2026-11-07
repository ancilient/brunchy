import 'package:brunchy_vendor/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renders UTC timestamps in IST', () {
    final utc = DateTime.utc(2026, 11, 6, 20, 0);
    expect(DateFormatter.displayDateTime(utc), '7 Nov, 1:30 AM');
  });
}
