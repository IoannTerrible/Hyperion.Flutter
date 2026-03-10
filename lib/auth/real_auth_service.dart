import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _keyToken = 'auth_token';
const _keyUserId = 'auth_user_id';
const _keyEmail = 'auth_email';
const _keyUsername = 'auth_username';

bool _isConnectionOrTlsError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('wrong version') ||
      s.contains('handshake') ||
      s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('connection refused') ||
      s.contains('сетевое подключение');
}

/// Real auth implementation: HTTP + secure storage, demo without HTTP.
class RealAuthService implements AuthService {
  final String baseUrl;
  final String fallbackBaseUrl;
  final void Function(AuthState) onStateChanged;
  final http.Client _client = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  RealAuthService({
    required this.baseUrl,
    required this.fallbackBaseUrl,
    required this.onStateChanged,
  });

  Future<void> _saveAuth(AuthenticationResult result) async {
    final token = result.token;
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: _keyToken, value: token);
      if (result.userId != null) await _storage.write(key: _keyUserId, value: result.userId);
      if (result.email != null) await _storage.write(key: _keyEmail, value: result.email);
      if (result.username != null) await _storage.write(key: _keyUsername, value: result.username);
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
    final request = LoginRequest(usernameOrEmail: usernameOrEmail, password: password);
    AuthenticationResult result;
    try {
      result = await postLogin(_client, baseUrl, request);
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        result = await postLogin(_client, fallbackBaseUrl, request);
      } else {
        rethrow;
      }
    }
    if (!result.isValid || result.token == null) {
      throw AuthApiException(result.errorMessage ?? 'Invalid credentials');
    }
    await _saveAuth(result);
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
    final request = RegisterRequest(username: username, email: email, password: password);
    AuthenticationResult result;
    try {
      result = await postRegister(_client, baseUrl, request);
    } catch (e) {
      if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
        result = await postRegister(_client, fallbackBaseUrl, request);
      } else {
        rethrow;
      }
    }
    if (!result.isValid || result.token == null) {
      throw AuthApiException(result.errorMessage ?? 'Registration failed');
    }
    await _saveAuth(result);
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
      final request = ValidateTokenRequest(token: token);
      AuthenticationResult result;
      try {
        result = await postValidateToken(_client, baseUrl, request);
      } catch (e) {
        if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
          result = await postValidateToken(_client, fallbackBaseUrl, request);
        } else {
          rethrow;
        }
      }
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
