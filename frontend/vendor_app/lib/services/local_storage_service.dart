// lib/services/local_storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/vendor.dart';

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  Future<void> saveVendor(Vendor vendor, String token) async {
    await _prefs.setString('vendor_json', jsonEncode(vendor.toJson()));
    await _prefs.setString('auth_token', token);
  }

  Vendor? getVendor() {
    try {
      final json = _prefs.getString('vendor_json');
      if (json == null) return null;
      return Vendor.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String? getToken() => _prefs.getString('auth_token');

  bool get isLoggedIn => getToken() != null && getVendor() != null;

  bool isStoredStateCorrupt() {
    final token = getToken();
    final vendor = getVendor();
    if (token == null && vendor == null) return false;
    if (token != null && vendor == null) return true;
    if (vendor != null && (vendor.id.isEmpty || vendor.phone.isEmpty)) return true;
    return false;
  }

  Future<void> saveCanteenInfo(String id, String name) async {
    await _prefs.setString('canteen_id', id);
    await _prefs.setString('canteen_name', name);
  }

  String? getCanteenName() => _prefs.getString('canteen_name') ?? 'Main Canteen';
  String? getCanteenId() => _prefs.getString('canteen_id');

  Future<void> saveStallInfo(String id, String name) async {
    await _prefs.setString('stall_id', id);
    await _prefs.setString('stall_name', name);
  }

  String? getStallName() => _prefs.getString('stall_name') ?? 'Burger Point';
  String? getStallIdDirect() => _prefs.getString('stall_id');

  Future<void> saveStallSession(String stallId, String date) async {
    await _prefs.setString('stall_$date', stallId);
  }

  String? getStallId(String date) => _prefs.getString('stall_$date') ?? getStallIdDirect();

  Future<void> clearStallSession(String date) async {
    await _prefs.remove('stall_$date');
  }

  // Offline queue support
  List<String> getOfflineQueue() => _prefs.getStringList('offline_queue') ?? [];

  // Capacity gate persistence
  int getMaxCapacity() => _prefs.getInt('max_concurrent_orders') ?? 15;
  Future<void> setMaxCapacity(int capacity) => _prefs.setInt('max_concurrent_orders', capacity);

  bool isAcceptingOrders(String stallId) => _prefs.getBool('accepting_orders_$stallId') ?? true;
  Future<void> setAcceptingOrders(String stallId, bool value) =>
      _prefs.setBool('accepting_orders_$stallId', value);

  Future<void> queueOfflineAction(String actionJson) async {
    final list = getOfflineQueue();
    list.add(actionJson);
    await _prefs.setStringList('offline_queue', list);
  }

  Future<void> clearOfflineQueue() async => await _prefs.remove('offline_queue');

  bool get hasPendingOfflineActions => getOfflineQueue().isNotEmpty;

  Future<void> clearSession() async {
    await _prefs.remove('vendor_json');
    await _prefs.remove('auth_token');
    await _prefs.remove('stall_id');
    await _prefs.remove('stall_name');
    await _prefs.remove('canteen_id');
    await _prefs.remove('canteen_name');
    await _prefs.remove('offline_queue');
  }

  Future<void> clearAll() async => await _prefs.clear();

  Future<void> clearAuth() async {
    await _prefs.remove('vendor_json');
    await _prefs.remove('auth_token');
  }

  bool validateStoredState() => !isStoredStateCorrupt();
}
