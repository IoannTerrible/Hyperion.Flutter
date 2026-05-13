import 'package:hyperion_flutter/auth/auth_api.dart';

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

  /// Start a Google sign-in. Returns the server's three-state response.
  /// Caller decides whether to follow up with [linkGoogleAccount] or [completeGoogleRegistration].
  Future<GoogleSignInResult> googleSignIn();

  /// Finish a Google sign-in for an existing password account.
  Future<GoogleSignInResult> linkGoogleAccount(String continuationToken, String password);

  /// Finish a new Google registration with a user-chosen username.
  Future<GoogleSignInResult> completeGoogleRegistration(String continuationToken, String username);

  /// Start a GitHub sign-in. Returns the server's three-state response.
  /// Caller decides whether to follow up with [linkGitHubAccount] or [completeGitHubRegistration].
  Future<GitHubSignInResult> githubSignIn();

  /// Finish a GitHub sign-in for an existing password account.
  Future<GitHubSignInResult> linkGitHubAccount(String continuationToken, String password);

  /// Finish a new GitHub registration with a user-chosen username.
  Future<GitHubSignInResult> completeGitHubRegistration(String continuationToken, String username);
}
