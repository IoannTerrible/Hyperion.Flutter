import 'dart:math';

import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _keyToken = 'auth_token';
const _keyRefreshToken = 'auth_refresh_token';
const _keyUserId = 'auth_user_id';
const _keyEmail = 'auth_email';
const _keyUsername = 'auth_username';
const _keyDeviceId = 'local_device_id';

String _generateUuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

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

  Future<String> _getOrCreateDeviceId() async {
    var id = await _storage.read(key: _keyDeviceId);
    if (id == null || id.isEmpty) {
      id = _generateUuid();
      await _storage.write(key: _keyDeviceId, value: id);
    }
    return id;
  }

  Future<void> _saveAuth(AuthenticationResult result) async {
    final token = result.token;
    if (token != null && token.isNotEmpty) await _storage.write(key: _keyToken, value: token);

    final refreshToken = result.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }

    if (result.userId != null) await _storage.write(key: _keyUserId, value: result.userId);
    if (result.email != null) await _storage.write(key: _keyEmail, value: result.email);
    if (result.username != null) await _storage.write(key: _keyUsername, value: result.username);
  }

  void _notifyAuthenticated({
    required String email,
    String? userId,
    String? username,
    bool emailVerified = true,
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool isDemo = false,
    String? deviceId,
  }) {
    onStateChanged(Authenticated(
      email: email,
      userId: userId,
      username: username,
      emailVerified: emailVerified,
      displayName: displayName,
      avatarUrl: avatarUrl,
      bio: bio,
      isDemo: isDemo,
      deviceId: deviceId,
    ));
  }

  Future<UserResponse?> _fetchMeBestEffort(String token) async {
    try {
      try {
        return await getMe(_client, baseUrl, token);
      } catch (e) {
        if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
          return await getMe(_client, fallbackBaseUrl, token);
        }
        rethrow;
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> refreshProfile() async {
    final token = await _storage.read(key: _keyToken);
    if (token == null || token.isEmpty) return;
    final me = await _fetchMeBestEffort(token);
    if (me == null) return;
    final deviceId = await _storage.read(key: _keyDeviceId);
    final email = (me.email ?? await _storage.read(key: _keyEmail) ?? '').trim();
    final userId = me.id ?? await _storage.read(key: _keyUserId);
    final username = me.username ?? await _storage.read(key: _keyUsername);
    _notifyAuthenticated(
      email: email.isNotEmpty ? email : 'user',
      userId: userId,
      username: username,
      emailVerified: me.emailVerified ?? true,
      displayName: me.displayName,
      avatarUrl: me.avatarUrl,
      bio: me.bio,
      isDemo: false,
      deviceId: deviceId,
    );
  }

  Future<void> _notifyFromResult(AuthenticationResult result) async {
    final token = result.token;
    final me = token != null && token.isNotEmpty ? await _fetchMeBestEffort(token) : null;
    final deviceId = await _storage.read(key: _keyDeviceId);
    final resolvedEmail =
        (me?.email ?? result.email ?? result.user?.email ?? await _storage.read(key: _keyEmail) ?? '').trim();
    final resolvedUserId = me?.id ?? result.userId ?? result.user?.id ?? await _storage.read(key: _keyUserId);
    final resolvedUsername =
        me?.username ?? result.username ?? result.user?.username ?? await _storage.read(key: _keyUsername);
    final emailVerified = me?.emailVerified ?? result.user?.emailVerified ?? true;
    _notifyAuthenticated(
      email: resolvedEmail.isNotEmpty ? resolvedEmail : 'user',
      userId: resolvedUserId,
      username: resolvedUsername,
      emailVerified: emailVerified,
      displayName: me?.displayName ?? result.user?.displayName,
      avatarUrl: me?.avatarUrl ?? result.user?.avatarUrl,
      bio: me?.bio ?? result.user?.bio,
      isDemo: false,
      deviceId: deviceId,
    );
  }

  @override
  Future<void> signIn(String usernameOrEmail, String password) async {
    final deviceId = await _getOrCreateDeviceId();
    final request = LoginRequest(usernameOrEmail: usernameOrEmail, password: password, deviceId: deviceId);
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
    await _notifyFromResult(result);
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
    await _notifyFromResult(result);
  }

  @override
  Future<bool> tryRefreshSession() async {
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty) return false;

    AuthenticationResult result;
    try {
      final req = RefreshTokenRequest(refreshToken: refreshToken);
      try {
        result = await postRefreshToken(_client, baseUrl, req);
      } catch (e) {
        if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
          result = await postRefreshToken(_client, fallbackBaseUrl, req);
        } else {
          rethrow;
        }
      }
    } catch (_) {
      return false;
    }

    if (!result.isValid || result.token == null || result.token!.isEmpty) return false;
    await _saveAuth(result);
    await _notifyFromResult(result);
    return true;
  }

  @override
  void signInAsDemo() {
    onStateChanged(const Authenticated(
      email: 'demo@local',
      userId: null,
      username: 'demo',
      emailVerified: true,
      isDemo: true,
    ));
  }

  @override
  Future<void> signOut() async {
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final req = LogoutRequest(refreshToken: refreshToken);
        try {
          await postLogout(_client, baseUrl, req);
        } catch (e) {
          if (_isConnectionOrTlsError(e) && fallbackBaseUrl != baseUrl) {
            await postLogout(_client, fallbackBaseUrl, req);
          } else {
            rethrow;
          }
        }
      } catch (_) {
        // Best-effort: still clear local state.
      }
    }
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyUsername);
    onStateChanged(const Unauthenticated());
  }

  @override
  Future<void> restoreSession() async {
    await _getOrCreateDeviceId(); // ensure UUID exists before any auth flow
    final token = await _storage.read(key: _keyToken);
    if (token == null || token.isEmpty) {
      // If access token is missing, try to refresh using refresh token.
      final ok = await tryRefreshSession();
      if (!ok) await signOut();
      return;
    }

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
        final ok = await tryRefreshSession();
        if (!ok) await signOut();
        return;
      }
      await _notifyFromResult(result);
    } catch (_) {
      await _storage.delete(key: _keyToken);
      await _storage.delete(key: _keyRefreshToken);
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
