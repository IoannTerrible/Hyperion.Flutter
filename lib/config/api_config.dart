import 'package:flutter/foundation.dart';

/// API base URLs. Override at build time with --dart-define:
///   flutter run --dart-define=AUTH_BASE_URL=http://192.168.1.100:7204
///   flutter build apk --dart-define=AUTH_BASE_URL=https://api.example.com
class ApiConfig {
  ApiConfig._();

  static const String _defaultAuthUrl = 'https://localhost:7204';
  static const String _defaultDevicesUrl = 'https://localhost:7264';
  static const String _defaultPluginUrl = 'https://localhost:7266';

  /// Auth API base URL (login, register, validate-token).
  static String get authBaseUrl =>
      const String.fromEnvironment('AUTH_BASE_URL', defaultValue: _defaultAuthUrl);

  /// Devices API base URL (devices, sessions).
  static String get devicesBaseUrl =>
      const String.fromEnvironment('DEVICES_BASE_URL', defaultValue: _defaultDevicesUrl);

  /// Plugin Service base URL (plugin catalog, instance plugin state).
  static String get pluginBaseUrl =>
      const String.fromEnvironment('PLUGIN_BASE_URL', defaultValue: _defaultPluginUrl);

  /// Public Privacy Policy URL (no auth required).
  static const String privacyPolicyUrl = 'https://hyperion.techteastudio.cc/privacy';

  // ── Google sign-in ───────────────────────────────────────────────────────
  /// Server (Web) client id used as the audience for Android id_tokens.
  static String get googleAndroidServerClientId =>
      const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  /// Desktop OAuth client id (loopback flow). Used on Windows/Linux/macOS.
  static String get googleDesktopClientId =>
      const String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID', defaultValue: '');

  /// Desktop OAuth client secret. Some Google "Desktop application" clients
  /// still require this even though they use PKCE — pass via --dart-define.
  static String get googleDesktopClientSecret =>
      const String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET', defaultValue: '');

  // ── GitHub sign-in ───────────────────────────────────────────────────────
  /// GitHub OAuth App client id. The backend exchanges the auth code for a
  /// token, so the Flutter client does NOT need the client secret.
  static String get githubClientId =>
      const String.fromEnvironment('GITHUB_CLIENT_ID', defaultValue: '');

  /// HTTP fallback for TLS/connection errors (e.g. local Docker without HTTPS).
  /// In release builds the fallback is the same as the base URL (no HTTP downgrade).
  static String get authFallbackUrl =>
      kReleaseMode ? authBaseUrl : _httpFallback(authBaseUrl);
  static String get devicesFallbackUrl =>
      kReleaseMode ? devicesBaseUrl : _httpFallback(devicesBaseUrl);
  static String get pluginFallbackUrl =>
      kReleaseMode ? pluginBaseUrl : _httpFallback(pluginBaseUrl);

  static String _httpFallback(String url) =>
      url.startsWith('https:') ? 'http:${url.substring(6)}' : url;
}
