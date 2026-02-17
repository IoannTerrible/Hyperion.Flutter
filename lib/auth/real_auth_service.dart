import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _keyToken = 'auth_token';
const _keyUserId = 'auth_user_id';
const _keyEmail = 'auth_email';
const _keyUsername = 'auth_username';

/// Real auth implementation: HTTP + secure storage, demo without HTTP.
class RealAuthService implements AuthService {
  final String baseUrl;
  final void Function(AuthState) onStateChanged;
  final http.Client _client = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  RealAuthService({
    required this.baseUrl,
    required this.onStateChanged,
  });

  void _saveAuth(AuthenticationResult result) {
    final token = result.token;
    if (token != null && token.isNotEmpty) {
      _storage.write(key: _keyToken, value: token);
      if (result.userId != null) _storage.write(key: _keyUserId, value: result.userId);
      if (result.email != null) _storage.write(key: _keyEmail, value: result.email);
      if (result.username != null) _storage.write(key: _keyUsername, value: result.username);
    }
  }

  void _notifyAuthenticated({
    required String email,
    String? userId,
    String? username,
    bool isDemo = false,
  }) {
    onStateChanged(Authenticated.authenticated(email, userId, username, isDemo));
  }

  @override
  Future<void> signIn(String usernameOrEmail, String password) async {
    final result = await postLogin(
      _client,
      baseUrl,
      LoginRequest(usernameOrEmail: usernameOrEmail, password: password),
    );
    if (!result.isValid || result.token == null) {
      throw AuthApiException(result.errorMessage ?? 'Invalid credentials');
    }
    _saveAuth(result);
    final email = result.email ?? result.user?.email ?? '';
    _notifyAuthenticated(
      email: email.isNotEmpty ? email : 'user',
      userId: result.userId ?? result.user?.id,
      username: result.username ?? result.user?.username,
      isDemo: false,
    );
  }

  @override
  Future<void> register(String username, String email, String password) async {
    final result = await postRegister(
      _client,
      baseUrl,
      RegisterRequest(username: username, email: email, password: password),
    );
    if (!result.isValid || result.token == null) {
      throw AuthApiException(result.errorMessage ?? 'Registration failed');
    }
    _saveAuth(result);
    final resolvedEmail = result.email ?? result.user?.email ?? email;
    _notifyAuthenticated(
      email: resolvedEmail,
      userId: result.userId ?? result.user?.id,
      username: result.username ?? result.user?.username ?? username,
      isDemo: false,
    );
  }

  @override
  void signInAsDemo() {
    onStateChanged(Authenticated.authenticated(
      'demo@local',
      null,
      'demo',
      true,
    ));
  }

  @override
  Future<void> signOut() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyUsername);
    onStateChanged(const Unauthenticated());
  }

  @override
  Future<void> restoreSession() async {
    final token = await _storage.read(key: _keyToken);
    if (token == null || token.isEmpty) return;

    try {
      final result = await postValidateToken(
        _client,
        baseUrl,
        ValidateTokenRequest(token: token),
      );
      if (!result.isValid) {
        await signOut();
        return;
      }
      final email = result.email ?? result.user?.email ?? await _storage.read(key: _keyEmail) ?? '';
      final userId = result.userId ?? result.user?.id ?? await _storage.read(key: _keyUserId);
      final username = result.username ?? result.user?.username ?? await _storage.read(key: _keyUsername);
      _notifyAuthenticated(
        email: email.isNotEmpty ? email : 'user',
        userId: userId,
        username: username,
        isDemo: false,
      );
    } catch (_) {
      await _storage.delete(key: _keyToken);
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyUsername);
    }
  }

  @override
  Future<String?> getToken() async {
    return _storage.read(key: _keyToken);
  }
}
