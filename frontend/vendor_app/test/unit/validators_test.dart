import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/core/utils/validators.dart';

void main() {
  group('Validators Unit Tests', () {
    test('validateName accepts valid names and rejects short names', () {
      expect(Validators.validateName('Rajesh'), isNull);
      expect(Validators.validateName('R'), isNotNull);
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName(null), isNotNull);
    });

    test('validatePhone requires 10-digit numeric', () {
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('98765'), isNotNull);
      expect(Validators.validatePhone('98765432101'), isNotNull);
      expect(Validators.validatePhone('987654321a'), isNotNull);
      expect(Validators.validatePhone(null), isNotNull);
    });

    test('validateItemName checks length and presence', () {
      expect(Validators.validateItemName('Masala Dosa'), isNull);
      expect(Validators.validateItemName(''), isNotNull);
      expect(Validators.validateItemName(null), isNotNull);
      expect(Validators.validateItemName('a' * 101), isNotNull);
    });

    test('validatePrice accepts positive valid numbers <= 9999', () {
      expect(Validators.validatePrice('80'), isNull);
      expect(Validators.validatePrice('150.50'), isNull);
      expect(Validators.validatePrice('0'), isNotNull);
      expect(Validators.validatePrice('-10'), isNotNull);
      expect(Validators.validatePrice('10000'), isNotNull);
      expect(Validators.validatePrice('abc'), isNotNull);
    });

    test('validateOtpDigit accepts single digits', () {
      expect(Validators.validateOtpDigit('5'), isNull);
      expect(Validators.validateOtpDigit('a'), equals(''));
      expect(Validators.validateOtpDigit(''), equals(''));
    });
  });
}
