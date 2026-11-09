// Talks to the Brunchy backend (backend/, contract in docs/api/openapi.yaml).
//
// Server address: set when building/running the app, e.g.
//   flutter run --dart-define=API_URL=http://192.168.1.10:4000/api/v1
// Default http://localhost:4000/api/v1 works on a phone connected by USB after `adb reverse tcp:4000 tcp:4000`.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000/api/v1');

/// An error the server returned on purpose ({ error: { code, message } }) or a network problem (code NETWORK).
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.details]);
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic>? details;
  @override
  String toString() => 'ApiException($status $code: $message)';
}

class ApiClient {
  ApiClient(this._prefs) {
    accessToken = _prefs.getString(_accessKey);
    refreshToken = _prefs.getString(_refreshKey);
  }

  static const _accessKey = 'brunchy_access_token';
  static const _refreshKey = 'brunchy_refresh_token';

  final SharedPreferences _prefs;
  final http.Client _http = http.Client();
  String? accessToken;
  String? refreshToken;

  /// Server clock minus phone clock. Countdowns use the server's time, never the phone's (build guide).
  Duration serverOffset = Duration.zero;

  /// Called when the session cannot be refreshed any more (the student must log in again).
  void Function()? onSessionExpired;

  bool get hasSession => refreshToken != null;

  /// Base address without /api/v1, for Socket.IO.
  String get origin => Uri.parse(kApiUrl).replace(path: '').toString().replaceAll(RegExp(r'/$'), '');

  DateTime serverNow() => DateTime.now().add(serverOffset);

  Future<void> saveSession(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    // TODO(release): move tokens to flutter_secure_storage before the Play Store build.
    await _prefs.setString(_accessKey, access);
    await _prefs.setString(_refreshKey, refresh);
  }

  Future<void> clearSession() async {
    accessToken = null;
    refreshToken = null;
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body ?? const {});

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body, bool retried = false]) async {
    final headers = <String, String>{
      'content-type': 'application/json',
      if (accessToken != null) 'authorization': 'Bearer $accessToken',
    };
    http.Response res;
    try {
      final req = http.Request(method, Uri.parse('$kApiUrl$path'))..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 15)));
    } on TimeoutException {
      throw ApiException(0, 'NETWORK', 'The server is taking too long. Check your internet and try again.');
    } catch (_) {
      throw ApiException(0, 'NETWORK', 'Cannot reach Brunchy. Check your internet and try again.');
    }
    _trackServerClock(res);

    // Access tokens last 15 minutes: refresh once and repeat the call.
    if (res.statusCode == 401 && !retried && !path.startsWith('/auth/') && refreshToken != null) {
      if (await refreshSession()) return _send(method, path, body, true);
    }

    final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    final json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    if (res.statusCode >= 400) {
      final err = (json['error'] as Map<String, dynamic>?) ?? const {};
      throw ApiException(
        res.statusCode,
        (err['code'] as String?) ?? 'HTTP_${res.statusCode}',
        (err['message'] as String?) ?? 'Something went wrong. Please try again.',
        err['details'] is Map<String, dynamic> ? err['details'] as Map<String, dynamic> : null,
      );
    }
    return json;
  }

  Future<bool>? _refreshing;

  /// Swaps the refresh token for a new pair. Several calls at once share one refresh.
  Future<bool> refreshSession() {
    return _refreshing ??= () async {
      try {
        final rt = refreshToken;
        if (rt == null) return false;
        final r = await _send('POST', '/auth/refresh', {'refreshToken': rt}, true);
        await saveSession(r['accessToken'] as String, r['refreshToken'] as String);
        return true;
      } on ApiException catch (e) {
        if (e.status == 401) {
          await clearSession();
          onSessionExpired?.call();
        }
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  void _trackServerClock(http.Response res) {
    final date = res.headers['date'];
    if (date == null) return;
    try {
      serverOffset = HttpDateParser.parse(date).difference(DateTime.now());
    } catch (_) {}
  }
}

/// Parses the HTTP Date header ("Sun, 09 Nov 2026 12:14:22 GMT").
class HttpDateParser {
  static const _months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
  static DateTime parse(String s) {
    final p = s.split(RegExp(r'[ :,]+'));
    // [Sun, 09, Nov, 2026, 12, 14, 22, GMT]
    return DateTime.utc(int.parse(p[3]), _months[p[2]]!, int.parse(p[1]), int.parse(p[4]), int.parse(p[5]), int.parse(p[6]));
  }
}
