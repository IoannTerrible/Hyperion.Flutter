/// Platform-agnostic contract for obtaining a Google id_token.
///
/// On Android we use the native google_sign_in plugin which returns an
/// id_token directly. On Windows / Linux / macOS desktop, where the plugin
/// is not natively supported, we fall back to a loopback OAuth flow with
/// PKCE that exchanges the auth code for an id_token via Google's token
/// endpoint.
abstract class GoogleIdTokenProvider {
  /// True when the platform has a working Google client id configured.
  bool get isAvailable;

  /// Returns a Google id_token, or null if the user cancelled.
  /// Throws on configuration / network errors.
  Future<String?> obtainIdToken();
}
