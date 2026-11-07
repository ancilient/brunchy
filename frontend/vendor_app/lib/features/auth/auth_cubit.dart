import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/vendor.dart';
import '../../data/models/canteen.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/local_storage_service.dart';
import '../../core/errors/app_exception.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final LocalStorageService _storage;

  AuthCubit(this._authRepository, this._storage) : super(const AuthInitial());

  Future<void> login({
    required String name,
    required String phone,
    required String canteenId,
  }) async {
    emit(const AuthLoading());
    try {
      // [API-001] POST /auth/login
      final result = await _authRepository.login(name: name, phone: phone, canteenId: canteenId);
      await _authRepository.saveVendorLocally(result.vendor, result.token);
      emit(AuthSuccess(result.vendor));
    } on AppException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Login failed. Please try again.'));
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

