import 'package:brunchy_vendor/features/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google accounts show the email without a phone prefix', () {
    expect(contactLabel('burger.vendor@example.com'), 'burger.vendor@example.com');
  });

  test('a 10-digit Indian mobile number gets +91', () {
    expect(contactLabel('9000000001'), '+91 9000000001');
    expect(contactLabel(' 9876543210 '), '+91 9876543210');
  });

  test('anything else is shown unchanged', () {
    expect(contactLabel('-'), '-');
    expect(contactLabel('12345'), '12345');
  });
}
