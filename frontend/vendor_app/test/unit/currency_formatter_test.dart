import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Unit Tests', () {
    test('format adds rupee symbol without decimals', () {
      final formatted = CurrencyFormatter.format(120);
      expect(formatted.contains('₹'), isTrue);
      expect(formatted.contains('120'), isTrue);
    });

    test('formatChangePct handles new, none, positive and negative', () {
      expect(CurrencyFormatter.formatChangePct(pct: 0, isNew: false, isNone: true), equals('—'));
      expect(CurrencyFormatter.formatChangePct(pct: 50, isNew: true, isNone: false), equals('New'));
      expect(CurrencyFormatter.formatChangePct(pct: 12.4, isNew: false, isNone: false), equals('+12.4%'));
      expect(CurrencyFormatter.formatChangePct(pct: -8.5, isNew: false, isNone: false), equals('-8.5%'));
    });
  });
}
