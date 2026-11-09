import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/date_formatter.dart';
import '../models/canteen.dart';
import '../models/stall.dart';
import '../models/vendor.dart';
import '../repositories/auth_repository.dart';
import 'vendor_api.dart';

/// Login and stall session against the backend. A vendor phone number belongs to exactly one stall,
/// so after the OTP check the stall comes from the server instead of being picked on the phone.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api, this._prefs);
  final VendorApi _api;
  final SharedPreferences _prefs;

  @override
  Future<String?> requestOtp(String phone) async {
    final r = await _api.post('/auth/otp', {'phone': phone});
    return r['devCode'] as String?;
  }

  @override
  Future<({Vendor vendor, String token, String stallId, String stallName})> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final r = await _api.post('/auth/verify', {'phone': phone, 'code': code});
    final user = r['user'] as Map<String, dynamic>;
    if (user['role'] != 'vendor' || user['stallId'] == null) {
      throw const AppException(
        message: 'This number is not registered to a stall. Ask the canteen manager to add it.',
        code: 'NOT_A_VENDOR',
      );
    }
    await _api.saveSession(r['accessToken'] as String, r['refreshToken'] as String);
    final stall = (await _api.get('/vendor/stall'))['stall'] as Map<String, dynamic>;
    await _prefs.setString('canteen_id', stall['canteenId'] as String);
    await _prefs.setString('canteen_name', stall['canteenName'] as String);
    final vendor = Vendor(
      id: user['id'] as String,
      name: user['name'] as String,
      phone: (user['phone'] as String?) ?? phone,
      canteenId: stall['canteenId'] as String,
    );
    return (vendor: vendor, token: r['accessToken'] as String, stallId: stall['id'] as String, stallName: stall['name'] as String);
  }

  @override
  Future<void> saveVendorLocally(Vendor vendor, String token) async {
    await _prefs.setString('vendor_json', jsonEncode(vendor.toJson()));
    // the access token itself is stored by VendorApi.saveSession under the same key
  }

  @override
  Vendor? getStoredVendor() {
    try {
      final json = _prefs.getString('vendor_json');
      return json == null ? null : Vendor.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  String? getStoredToken() => _api.accessToken;

  @override
  Future<void> saveStallSession({required String stallId, required String date}) async {
    await _prefs.setString('stall_$date', stallId);
  }

  @override
  String? getStoredStallId(String date) => _prefs.getString('stall_$date');

  @override
  Future<void> clearStallSession() async => _prefs.remove('stall_${DateFormatter.todayKey()}');

  @override
  Future<void> clearAll() async {
    final rt = _api.refreshToken;
    if (rt != null) {
      try {
        await _api.post('/auth/logout', {'refreshToken': rt});
      } catch (_) {}
    }
    await _prefs.clear();
  }

  @override
  bool validateStoredState() {
    final vendor = getStoredVendor();
    return vendor != null && vendor.id.isNotEmpty && vendor.phone.isNotEmpty && _api.refreshToken != null;
  }

  @override
  Future<List<Canteen>> getCanteens() async {
    final r = await _api.get('/canteens');
    return (r['canteens'] as List).cast<Map<String, dynamic>>().map((c) => Canteen(id: c['id'] as String, name: c['name'] as String)).toList();
  }

  @override
  Future<List<Stall>> getStalls(String canteenId) async {
    // A vendor works at one stall: that is the only one offered.
    final s = (await _api.get('/vendor/stall'))['stall'] as Map<String, dynamic>;
    if (s['canteenId'] != canteenId) return const [];
    return [Stall(id: s['id'] as String, canteenId: s['canteenId'] as String, name: s['name'] as String, iconEmoji: '🍽️')];
  }

  @override
  Future<void> selectStall({required String stallId, required String date, bool forceTakeover = false}) async {
    final s = (await _api.get('/vendor/stall'))['stall'] as Map<String, dynamic>;
    if (s['id'] != stallId) {
      throw AppException(message: 'This phone number works at ${s['name']}.', code: 'WRONG_STALL');
    }
  }

  @override
  Future<Vendor> updateProfile({String? canteenId}) async {
    // The canteen is fixed by the vendor's stall on the server.
    final current = getStoredVendor();
    if (current == null) throw const AppException(message: 'Please log in again.', code: 'UNAUTHORIZED');
    return current;
  }
}
