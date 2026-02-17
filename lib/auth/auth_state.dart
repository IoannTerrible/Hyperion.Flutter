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
  final bool isDemo;

  const Authenticated({
    required this.email,
    this.userId,
    this.username,
    this.isDemo = false,
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
