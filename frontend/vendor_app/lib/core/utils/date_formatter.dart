import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static const _istOffset = Duration(hours: 5, minutes: 30);

  static DateTime _toIst(DateTime dt) => dt.toUtc().add(_istOffset);

  static final _dateFmt = DateFormat('yyyy-MM-dd');
  static final _displayDate = DateFormat('d MMM yyyy');
  static final _displayTime = DateFormat('h:mm a');
  static final _displayDateTime = DateFormat('d MMM, h:mm a');

  /// Today's date as YYYY-MM-DD (used for stall session key)
  static String todayKey() => _dateFmt.format(_toIst(DateTime.now()));

  /// Date key for a UTC instant, expressed in the vendor's IST business day.
  static String dateKey(DateTime dt) => _dateFmt.format(_toIst(dt));

  /// Format date for display: "5 Nov 2026"
  static String displayDate(DateTime dt) => _displayDate.format(_toIst(dt));

  /// Format time for display: "10:30 AM"
  static String displayTime(DateTime dt) => _displayTime.format(_toIst(dt));

  /// Format datetime for display: "5 Nov, 10:30 AM"
  static String displayDateTime(DateTime dt) => _displayDateTime.format(_toIst(dt));

  /// Seconds since a given DateTime (for countdown timers)
  static int secondsSince(DateTime dt) => DateTime.now().difference(dt).inSeconds;

  /// Countdown string from a future DateTime: "28s" or "1m 30s"
  static String countdown(DateTime until) {
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) return '0s';
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

