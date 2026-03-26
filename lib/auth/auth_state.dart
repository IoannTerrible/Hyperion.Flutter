/// Immutable auth state: either unauthenticated or authenticated (real or demo).
sealed class AuthState {
  const AuthState();
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class Authenticated extends AuthState {
  final String email;
  final String? userId;
  final String? username;
  final bool emailVerified;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isDemo;
  /// Stable local device ID generated once per device install.
  final String? deviceId;

  const Authenticated({
    required this.email,
    this.userId,
    this.username,
    this.emailVerified = true,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.isDemo = false,
    this.deviceId,
  });

  /// Factory for UI to distinguish demo from real login.
  factory Authenticated.authenticated(
    String email, [
    String? userId,
    String? username,
    bool isDemo = false,
  ]) =>
      Authenticated(
        email: email,
        userId: userId,
        username: username,
        isDemo: isDemo,
      );
}
