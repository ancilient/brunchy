import 'package:brunchy_vendor/core/errors/app_exception.dart';
import 'package:brunchy_vendor/data/remote/remote_auth_repository.dart';
import 'package:brunchy_vendor/data/remote/vendor_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends Mock implements VendorApi {}

const _missing = AppException(message: 'No such endpoint', code: 'NOT_FOUND', statusCode: 404);
const _ownStall = {
  'stall': {'id': '1', 'name': 'Burger Hub', 'canteenId': '1', 'canteenName': 'Main Canteen'}
};

void main() {
  late _Api api;
  late SharedPreferences prefs;
  late RemoteAuthRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = _Api();
    repo = RemoteAuthRepository(api, prefs);
    when(() => api.saveSession(any(), any())).thenAnswer((_) async {});
  });

  group('new backend', () {
    test('getStalls lists the stalls of the chosen canteen', () async {
      when(() => api.get('/canteens/2/stalls')).thenAnswer((_) async => {
            'stalls': [
              {'id': '7', 'canteenId': '2', 'name': 'Juice Bar', 'iconEmoji': '🥤'}
            ]
          });
      final stalls = await repo.getStalls('2');
      expect(stalls.single.id, '7');
      expect(stalls.single.name, 'Juice Bar');
    });

    test('selectStall saves the stall-scoped tokens and the stall', () async {
      when(() => api.post('/vendor/session/stall', any())).thenAnswer((_) async => {
            'accessToken': 'a2',
            'refreshToken': 'r2',
            'stall': {'id': '7', 'name': 'Juice Bar', 'canteenId': '2', 'canteenName': 'North Wing'}
          });
      await repo.selectStall(stallId: '7', date: '2026-11-22');
      verify(() => api.saveSession('a2', 'r2')).called(1);
      expect(prefs.getString('stall_id'), '7');
      expect(prefs.getString('canteen_name'), 'North Wing');
    });

    test('a refusal (e.g. no access) is passed to the screen, not swallowed', () async {
      when(() => api.post('/vendor/session/stall', any())).thenThrow(
          const AppException(message: 'Not your stall', code: 'STALL_NOT_ALLOWED', statusCode: 403));
      expect(() => repo.selectStall(stallId: '9', date: '2026-11-22'), throwsA(isA<AppException>()));
    });
  });

  group('backend without the new endpoints', () {
    setUp(() {
      when(() => api.get('/canteens/1/stalls')).thenThrow(_missing);
      when(() => api.get('/canteens/2/stalls')).thenThrow(_missing);
      when(() => api.post('/vendor/session/stall', any())).thenThrow(_missing);
      when(() => api.get('/vendor/stall')).thenAnswer((_) async => _ownStall);
    });

    test('getStalls falls back to the account stall', () async {
      expect((await repo.getStalls('1')).single.name, 'Burger Hub');
      expect(await repo.getStalls('2'), isEmpty);
    });

    test('selectStall accepts only the account stall', () async {
      await repo.selectStall(stallId: '1', date: '2026-11-22');
      expect(() => repo.selectStall(stallId: '7', date: '2026-11-22'), throwsA(isA<AppException>()));
    });
  });
}
