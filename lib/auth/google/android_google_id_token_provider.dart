import 'package:google_sign_in/google_sign_in.dart';
import 'package:hyperion_flutter/auth/google/google_id_token_provider.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';

/// Native Android implementation backed by `google_sign_in`.
///
/// On Android, the auth flow uses the system-installed Google account picker.
/// The plugin needs a *server* client id (the same Web client id that the
/// backend uses as the JWT audience) — not the Android client id. The Android
/// fingerprint registered in Google Cloud Console is what authorizes the
/// installed app to request tokens for that audience.
class AndroidGoogleIdTokenProvider implements GoogleIdTokenProvider {
  final String serverClientId;

  AndroidGoogleIdTokenProvider(this.serverClientId);

  @override
  bool get isAvailable => serverClientId.isNotEmpty;

  @override
  Future<String?> obtainIdToken() async {
    if (serverClientId.isEmpty) {
      AppLogger.log('[GoogleAuth] No server client id configured for Android');
      return null;
    }

    final googleSignIn = GoogleSignIn(
      serverClientId: serverClientId,
      scopes: const ['email', 'profile', 'openid'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) return null; // user cancelled

    final authentication = await account.authentication;
    return authentication.idToken;
  }
}
