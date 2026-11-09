// HTTP client for the Brunchy backend (backend/, contract in docs/api/openapi.yaml).
//
// Server address, set when building/running the app:
//   flutter run --dart-define=API_URL=http://192.168.1.10:4000/api/v1
// The default http://localhost:4000/api/v1 works on a USB-connected phone after `adb reverse tcp:4000 tcp:4000`.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/app_exception.dart';

const String kApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000/api/v1');

class VendorApi {
  VendorApi(this._prefs) {
    _dio = Dio(BaseOptions(
      baseUrl: kApiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ));
  }

  // 'auth_token' is the key LocalStorageService already uses for "logged in".
  static const _accessKey = 'auth_token';
  static const _refreshKey = 'refresh_token';

  final SharedPreferences _prefs;
  late final Dio _dio;

  /// Called when the session cannot be refreshed any more (the vendor must log in again).
  void Function()? onSessionExpired;

  String? get accessToken => _prefs.getString(_accessKey);
  String? get refreshToken => _prefs.getString(_refreshKey);

  /// Base address without /api/v1, for Socket.IO.
  String get origin => Uri.parse(kApiUrl).replace(path: '').toString().replaceAll(RegExp(r'/$'), '');

  Future<void> saveSession(String access, String refresh) async {
    // TODO(release): keep tokens in flutter_secure_storage before the Play Store build.
    await _prefs.setString(_accessKey, access);
    await _prefs.setString(_refreshKey, refresh);
  }

  Future<void> clearSession() async {
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body: body ?? const {});
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) => _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body, Map<String, dynamic>? query, bool retried = false}) async {
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: {if (accessToken != null) 'authorization': 'Bearer $accessToken'}),
      );
      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == null) throw AppException.network();
      // Access tokens last 15 minutes: refresh once and repeat the call.
      if (status == 401 && !retried && !path.startsWith('/auth/') && refreshToken != null) {
        if (await refreshSession()) return _send(method, path, body: body, query: query, retried: true);
      }
      throw _toAppException(status, e.response?.data);
    }
  }

  Future<bool>? _refreshing;

  /// Swaps the refresh token for a new pair; several callers at once share one refresh.
  Future<bool> refreshSession() {
    return _refreshing ??= () async {
      try {
        final rt = refreshToken;
        if (rt == null) return false;
        final r = await _send('POST', '/auth/refresh', body: {'refreshToken': rt}, retried: true);
        await saveSession(r['accessToken'] as String, r['refreshToken'] as String);
        return true;
      } on AppException catch (e) {
        if (e.statusCode == 401) {
          await clearSession();
          onSessionExpired?.call();
        }
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  /// Server errors -> the AppException codes the screens already understand.
  AppException _toAppException(int status, dynamic data) {
    final err = data is Map<String, dynamic> && data['error'] is Map<String, dynamic> ? data['error'] as Map<String, dynamic> : const {};
    final code = err['code'] as String?;
    final message = (err['message'] as String?) ?? 'Server error ($status)';
    final details = err['details'] is Map<String, dynamic> ? err['details'] as Map<String, dynamic> : const <String, dynamic>{};
    switch (code) {
      case 'CODE_WRONG':
        return AppException.otpWrong((details['attemptsLeft'] as num?)?.toInt() ?? 0);
      case 'CODE_LOCKED':
        final until = DateTime.tryParse('${details['lockedUntil']}') ?? DateTime.now().add(const Duration(minutes: 5));
        return AppException.otpLocked(until.toLocal());
      case 'ALREADY_COLLECTED':
        return AppException.alreadyCollected();
      case 'INVALID_TRANSITION':
        if (const ['rejected', 'cancelled', 'refunded', 'expired'].contains(details['status'])) return AppException.orderAlreadyCancelled();
        return AppException(message: message, code: code, statusCode: status);
      default:
        return AppException(message: message, code: code, statusCode: status);
    }
  }
}
