import 'package:brunchy_vendor/features/auth/choose_stall_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) => DateTime(2026, 11, 22, hour, minute);

  test('greeting follows the time of day', () {
    expect(greetingFor(at(7, 30)), 'Good morning');
    expect(greetingFor(at(11, 59)), 'Good morning');
    expect(greetingFor(at(12)), 'Good afternoon');
    expect(greetingFor(at(16, 59)), 'Good afternoon');
    expect(greetingFor(at(17)), 'Good evening');
    expect(greetingFor(at(18, 24)), 'Good evening'); // the case seen on the phone
    expect(greetingFor(at(23, 59)), 'Good evening');
  });
}
