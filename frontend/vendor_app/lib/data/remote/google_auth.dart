// "Sign in with Google" on the phone (google_sign_in 7). The app gets an ID token from Google and sends it to the
// backend (POST /auth/google), which checks it with Google and returns Brunchy's own session tokens.
//
// One-time setup in Google Cloud Console (see the README): an OAuth client of type "Web application" (its ID is what
// the backend lists in GOOGLE_CLIENT_IDS and serves here via /auth/options) plus an "Android" client for this app's
// package name and signing-key SHA-1. No google-services.json is needed.
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthCancelled implements Exception {}

class GoogleAuth {
  String? _initializedFor;

  /// Opens Google's account picker and returns the ID token for [serverClientId] (the Web client ID).
  /// Throws [GoogleAuthCancelled] when the user closes the picker.
  Future<String> signIn(String serverClientId) async {
    final g = GoogleSignIn.instance;
    if (_initializedFor != serverClientId) {
      await g.initialize(serverClientId: serverClientId);
      _initializedFor = serverClientId;
    }
    try {
      final account = await g.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('Google returned no ID token');
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw GoogleAuthCancelled();
      rethrow;
    }
  }

  /// Forget the Google account on this phone, so the next sign-in shows the account picker again.
  Future<void> signOut() async {
    if (_initializedFor == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
