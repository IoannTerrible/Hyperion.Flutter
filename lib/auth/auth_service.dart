import 'package:clietn_server_application/auth/auth_state.dart';

/// Contract for auth: login, register, demo, signOut, restoreSession.
abstract class AuthService {
  /// Sign in with username or email and password.
  Future<void> signIn(String usernameOrEmail, String password);

  /// Register new user.
  Future<void> register(String username, String email, String password);

  /// Sign in as demo user (no HTTP, no token).
  void signInAsDemo();

  /// Sign out and clear storage.
  Future<void> signOut();

  /// Restore session from stored token (validate-token, optionally /me).
  Future<void> restoreSession();

  /// Get current token for API calls (null for demo).
  Future<String?> getToken();
}
