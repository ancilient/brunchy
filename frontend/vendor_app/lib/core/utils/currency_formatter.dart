import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _inrFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _inrFmtDec = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  /// Formats amount as ₹1,000 (no decimals)
  static String format(double amount) => _inrFmt.format(amount);

  /// Formats amount as ₹1,000.50 (with decimals)
  static String formatWithDecimals(double amount) => _inrFmtDec.format(amount);

  /// Formats change percentage: returns "+12%", "-5%", "New", or "—"
  static String formatChangePct({
    required double pct,
    required bool isNew,
    required bool isNone,
  }) {
    if (isNone) return '—';
    if (isNew) return 'New';
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }
}

