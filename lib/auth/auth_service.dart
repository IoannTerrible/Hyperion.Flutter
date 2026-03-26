/// Contract for auth: login, register, demo, signOut, restoreSession.
abstract class AuthService {
  /// Sign in with username or email and password.
  Future<void> signIn(String usernameOrEmail, String password);

  /// Register new user.
  Future<void> register(String username, String email, String password);

  /// Sign in as demo user (no HTTP, no token).
  void signInAsDemo();

  /// Try to refresh access token using stored refresh token.
  /// Returns true if refresh succeeded and tokens were updated.
  Future<bool> tryRefreshSession();

  /// Refresh current user profile fields via GET /me.
  Future<void> refreshProfile();

  /// Sign out and clear storage.
  Future<void> signOut();

  /// Restore session from stored token (validate-token, optionally /me).
  Future<void> restoreSession();

  /// Get current token for API calls (null for demo).
  Future<String?> getToken();
}
