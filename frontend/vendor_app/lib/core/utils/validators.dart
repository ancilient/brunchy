// lib/core/utils/validators.dart
class Validators {
  Validators._();

  static String? validateName(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'Please enter your full name (at least 2 characters)';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().length != 10) {
      return 'Enter a valid 10-digit phone number';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
      return 'Phone number must contain only digits';
    }
    return null;
  }

  static String? validateItemName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Item name is required';
    if (value.trim().length > 100) return 'Name must be 100 characters or fewer';
    return null;
  }

  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return 'Price is required';
    final price = double.tryParse(value.trim());
    if (price == null || price <= 0) return 'Enter a valid price greater than 0';
    if (price > 9999) return 'Price cannot exceed ₹9,999';
    return null;
  }

  static String? validateCounterCode(String? value) {
    if (value == null || value.trim().length != 3) {
      return 'Enter a 3-digit counter code (100–999)';
    }
    if (!RegExp(r'^\d{3}$').hasMatch(value.trim())) {
      return 'Code must contain exactly 3 digits';
    }
    final num = int.tryParse(value.trim());
    if (num == null || num < 100 || num > 999) {
      return 'Code must be between 100 and 999';
    }
    return null;
  }

  static String? validateDigit(String? value) {
    if (value == null || value.isEmpty) return '';
    if (!RegExp(r'^\d$').hasMatch(value)) return '';
    return null;
  }

  static String? validateOtpDigit(String? value) => validateDigit(value);
}
