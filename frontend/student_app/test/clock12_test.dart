import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy/state/models.dart';

void main() {
  test('canteen hours show in 12-hour time', () {
    expect(clock12('07:30'), '7:30 AM');
    expect(clock12('22:00:00'), '10:00 PM');
    expect(clock12('12:00'), '12:00 PM');
    expect(clock12('00:15'), '12:15 AM');
    expect(clock12('oops'), 'oops');
    final c = Canteen(id: 1, name: 'Main', openingTime: '07:30', closingTime: '22:00', status: 'open', distanceMeters: 0);
    expect(c.hours, '7:30 AM - 10:00 PM');
  });
}
