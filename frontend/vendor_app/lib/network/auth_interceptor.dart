// lib/network/auth_interceptor.dart
import 'package:dio/dio.dart';
import '../services/local_storage_service.dart';

/// Attaches JWT bearer token to outgoing HTTP requests.
class AuthInterceptor extends Interceptor {
  final LocalStorageService _storage;

  AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid
      _storage.clearAuth();
    }
    handler.next(err);
  }
}
