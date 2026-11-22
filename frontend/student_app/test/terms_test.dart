import 'package:brunchy/state/terms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Terms & Conditions are between 50 and 100 words', () {
    final words = termsWordCount();
    expect(words, greaterThanOrEqualTo(50));
    expect(words, lessThanOrEqualTo(100));
  });

  test('the terms mention the fees, the free first orders and refunds', () {
    final text = [termsIntro, ...termsPoints, termsOutro].join(' ');
    expect(text, contains('platform and convenience fees'));
    expect(text, contains('first two orders'));
    expect(text, contains('Refunds'));
  });
}
