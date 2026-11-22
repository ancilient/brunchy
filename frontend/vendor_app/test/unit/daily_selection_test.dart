import 'package:brunchy_vendor/core/utils/date_formatter.dart';
import 'package:brunchy_vendor/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<LocalStorageService> storageWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LocalStorageService(await SharedPreferences.getInstance());
  }

  test('login stall alone (undated stall_id) is not a selection for today', () async {
    final s = await storageWith({'stall_id': '1'});
    expect(s.hasValidSelectionForToday(), isFalse);
  });

  test('a pick from an earlier day is not valid today', () async {
    final s = await storageWith({'stall_id': '1', 'stall_2000-01-01': '1'});
    expect(s.hasValidSelectionForToday(), isFalse);
  });

  test('save makes today valid; clear and logout forget it', () async {
    final s = await storageWith({'stall_id': '1', 'stall_2000-01-01': '1'});
    await s.saveDailySelection('1');
    expect(s.hasValidSelectionForToday(), isTrue);
    expect(s.getStallId(DateFormatter.todayKey()), '1');

    await s.clearDailySelection();
    expect(s.hasValidSelectionForToday(), isFalse);
    expect(s.getStallIdDirect(), '1', reason: 'the login stall stays for the other screens');

    await s.saveDailySelection('1');
    await s.clearSession(); // logout
    expect(s.hasValidSelectionForToday(), isFalse);
  });
}
