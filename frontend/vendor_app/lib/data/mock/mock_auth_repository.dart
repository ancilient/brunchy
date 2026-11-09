import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/vendor.dart';
import '../../data/models/canteen.dart';
import '../../data/models/stall.dart';
import '../../data/repositories/auth_repository.dart';
import '../mock/mock_data.dart';

class MockAuthRepository implements AuthRepository {
  final SharedPreferences _prefs;

  MockAuthRepository(this._prefs);

  @override
  Future<String?> requestOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return '123456'; // mock mode: any 6 digits work
  }

  @override
  Future<({Vendor vendor, String token, String stallId, String stallName})> verifyOtp({
    required String phone,
    required String code,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final vendor = MockData.mockVendor.copyWith(phone: phone);
    final stall = MockData.stalls.first;
    return (vendor: vendor, token: MockData.mockToken, stallId: stall.id, stallName: stall.name);
  }

  @override
  Future<void> saveVendorLocally(Vendor vendor, String token) async {
    await _prefs.setString('vendor_json', jsonEncode(vendor.toJson()));
    await _prefs.setString('auth_token', token);
  }

  @override
  Vendor? getStoredVendor() {
    try {
      final json = _prefs.getString('vendor_json');
      if (json == null) return null;
      return Vendor.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  String? getStoredToken() => _prefs.getString('auth_token');

  @override
  Future<void> saveStallSession({required String stallId, required String date}) async {
    await _prefs.setString('stall_$date', stallId);
  }

  @override
  String? getStoredStallId(String date) => _prefs.getString('stall_$date');

  @override
  Future<void> clearStallSession() async {
    final today = DateTime.now();
    final key = 'stall_${today.year.toString().padLeft(4,'0')}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    await _prefs.remove(key);
  }

  @override
  Future<void> clearAll() async => await _prefs.clear();

  @override
  bool validateStoredState() {
    final vendor = getStoredVendor();
    if (vendor == null) return false;
    if (vendor.id.isEmpty || vendor.name.isEmpty || vendor.phone.isEmpty) return false;
    return true;
  }

  @override
  Future<List<Canteen>> getCanteens() async {
    // TODO(BACKEND-API): API-002 GET /canteens
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.canteens;
  }

  @override
  Future<List<Stall>> getStalls(String canteenId) async {
    // TODO(BACKEND-API): API-003 GET /canteens/{canteenId}/stalls
    await Future.delayed(const Duration(milliseconds: 600));
    return MockData.stalls.where((s) => s.canteenId == canteenId).toList();
  }

  @override
  Future<void> selectStall({
    required String stallId, required String date, bool forceTakeover = false,
  }) async {
    // TODO(BACKEND-API): API-004 POST /vendor/session/stall
    await Future.delayed(const Duration(milliseconds: 400));
    // Mock: always succeeds (no conflict simulation)
  }

  @override
  Future<Vendor> updateProfile({String? canteenId}) async {
    // [API-024] PATCH /vendor/profile
    await Future.delayed(const Duration(milliseconds: 400));
    final current = getStoredVendor() ?? MockData.mockVendor;
    final updated = current.copyWith(canteenId: canteenId ?? current.canteenId);
    await saveVendorLocally(updated, getStoredToken() ?? MockData.mockToken);
    return updated;
  }
}

