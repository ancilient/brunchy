import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/vendor.dart';
import '../../data/models/canteen.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/local_storage_service.dart';
import '../../core/errors/app_exception.dart';
import '../../data/remote/google_auth.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final LocalStorageService _storage;

  AuthCubit(this._authRepository, this._storage) : super(const AuthInitial());

  /// Which sign-in buttons the server offers (Google, development login). Throws AppException when offline.
  Future<({bool google, String? googleClientId, bool devLogin})> loadLoginOptions() => _authRepository.loginOptions();

  /// Sign in with Google. The server checks the account and says which stall it belongs to.
  Future<void> signInWithGoogle(String serverClientId) => _signIn(() => _authRepository.signInWithGoogle(serverClientId));

  /// Development only: sign in as the vendor of the demo stall without Google.
  Future<void> devLogin() => _signIn(() => _authRepository.devLogin());

  Future<void> _signIn(Future<({Vendor vendor, String token, String stallId, String stallName})> Function() signIn) async {
    emit(const AuthLoading());
    try {
      final result = await signIn();
      await _authRepository.saveVendorLocally(result.vendor, result.token);
      await _storage.saveStallInfo(result.stallId, result.stallName);
      emit(AuthSuccess(result.vendor));
    } on GoogleAuthCancelled {
      emit(const AuthInitial()); // the vendor closed Google's account picker
    } on AppException catch (e) {
      emit(AuthError(e.message));
    } catch (_) {
      emit(const AuthError('Google sign-in did not work on this phone. Check the Google Cloud setup (see README).'));
    }
  }

  Future<void> updateCanteen(String canteenId) async {
    emit(const AuthLoading());
    try {
      // [API-022] PATCH /vendor/profile
      final vendor = await _authRepository.updateProfile(canteenId: canteenId);
      await _storage.saveVendor(vendor, _storage.getToken() ?? '');
      emit(AuthSuccess(vendor));
    } on AppException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Failed to update canteen. Please try again.'));
    }
  }

  Future<List<Canteen>> loadCanteens() async {
    try {
      // [API-002] GET /canteens
      return await _authRepository.getCanteens();
    } catch (_) {
      return [];
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    emit(const AuthInitial());
  }

  Vendor? get storedVendor => _authRepository.getStoredVendor();
}

