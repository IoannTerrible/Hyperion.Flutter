/// Platform-agnostic contract for obtaining a GitHub OAuth authorization code.
///
/// Unlike Google sign-in, the Flutter client never receives an id_token from
/// GitHub directly. Instead, it obtains a short-lived authorization code via
/// the OAuth flow (loopback HTTP server on desktop, custom-scheme intent on
/// mobile) and ships it to the Hyperion backend, which performs the
/// code→token exchange and user-info fetch server-side. As a result, the
/// Flutter side does NOT need the GitHub OAuth App's client_secret.
abstract class GitHubCodeProvider {
  /// True when the platform has a working GitHub client id configured.
  bool get isAvailable;

  /// Returns a GitHub authorization code (single-use, ~10 min validity), or
  /// null if the user cancelled or the redirect never arrived.
  Future<String?> obtainCode();
}
