import 'package:brunchy_vendor/data/models/canteen.dart';
import 'package:brunchy_vendor/data/models/stall.dart';
import 'package:brunchy_vendor/data/models/vendor.dart';

/// Abstract repository for authentication and session management.
/// Concrete implementations: [MockAuthRepository] (dev) and a future DioAuthRepository (prod).
abstract class AuthRepository {
  /// [API-001] Authenticates a vendor with the backend.
  /// Returns a named record containing the [Vendor] and a [token].
  Future<({Vendor vendor, String token})> login({
    required String name,
    required String phone,
    required String canteenId,
  });

  /// Persists [vendor] and [token] to local storage.
  Future<void> saveVendorLocally(Vendor vendor, String token);

  /// Returns the locally stored [Vendor], or null if none exists.
  Vendor? getStoredVendor();

  /// Returns the locally stored auth token, or null if none exists.
  String? getStoredToken();

  /// Persists a stall session for the given [date] (YYYY-MM-DD).
  Future<void> saveStallSession({
    required String stallId,
    required String date,
  });

  /// Returns the stall ID stored for [date], or null if no session exists.
  String? getStoredStallId(String date);

  /// Clears all stall sessions from local storage.
  Future<void> clearStallSession();

  /// Clears all locally stored auth and session data.
  Future<void> clearAll();

  /// Returns false if any required field is null, empty, or corrupt.
  /// Used by the splash screen to guard against corrupted local state (R-19).
  bool validateStoredState();

  /// [API-002] Fetches the list of all canteens.
  Future<List<Canteen>> getCanteens();

  /// [API-003] Fetches all stalls for a given [canteenId].
  Future<List<Stall>> getStalls(String canteenId);

  /// [API-004] Claims a stall for the current date.
  /// If the stall is already claimed on another device, the server returns 409
  /// (STALL_ALREADY_CLAIMED). Pass [forceTakeover] = true to override.
  Future<void> selectStall({
    required String stallId,
    required String date,
    bool forceTakeover = false,
  });

  /// [API-022] Updates the vendor's profile (e.g. switches canteen).
  Future<Vendor> updateProfile({String? canteenId});
}

