import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/vendor.dart';
import '../../data/models/canteen.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/local_storage_service.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_formatter.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final LocalStorageService _storage;

  AuthCubit(this._authRepository, this._storage) : super(const AuthInitial());

  /// Step 1: send a login code to the phone (POST /auth/otp).
  Future<void> sendOtp(String phone) async {
    emit(const AuthLoading());
    try {
      final devCode = await _authRepository.requestOtp(phone);
      emit(AuthOtpSent(phone, devCode));
    } on AppException catch (e) {
      emit(AuthError(e.message));
    } catch (_) {
      emit(const AuthError('Could not send the code. Please try again.'));
    }
  }

  /// Step 2: check the code (POST /auth/verify). The server says which stall this phone works at.
  Future<void> verifyOtp({required String phone, required String code}) async {
    emit(const AuthLoading());
    try {
      final result = await _authRepository.verifyOtp(phone: phone, code: code);
      await _authRepository.saveVendorLocally(result.vendor, result.token);
      await _storage.saveStallInfo(result.stallId, result.stallName);
      await _storage.saveStallSession(result.stallId, DateFormatter.todayKey());
      emit(AuthSuccess(result.vendor));
    } on AppException catch (e) {
      emit(AuthError(e.message));
      emit(AuthOtpSent(phone, null)); // stay on the code step
    } catch (_) {
      emit(const AuthError('Login failed. Please try again.'));
      emit(AuthOtpSent(phone, null));
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

