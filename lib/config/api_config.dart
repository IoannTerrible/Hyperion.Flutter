/// API base URLs. Override at build time with --dart-define:
///   flutter run --dart-define=AUTH_BASE_URL=http://192.168.1.100:7204
///   flutter build apk --dart-define=AUTH_BASE_URL=https://api.example.com
class ApiConfig {
  ApiConfig._();

  static const String _defaultAuthUrl = 'https://localhost:7204';
  static const String _defaultDevicesUrl = 'https://localhost:7264';

  /// Auth API base URL (login, register, validate-token).
  static String get authBaseUrl =>
      const String.fromEnvironment('AUTH_BASE_URL', defaultValue: _defaultAuthUrl);

  /// Devices API base URL (devices, sessions, plugins).
  static String get devicesBaseUrl =>
      const String.fromEnvironment('DEVICES_BASE_URL', defaultValue: _defaultDevicesUrl);

  /// Public Privacy Policy URL (no auth required).
  static const String privacyPolicyUrl = 'https://hyperion.techteastudio.cc/privacy';

  /// HTTP fallback for TLS/connection errors (e.g. local Docker without HTTPS).
  static String get authFallbackUrl => _httpFallback(authBaseUrl);
  static String get devicesFallbackUrl => _httpFallback(devicesBaseUrl);

  static String _httpFallback(String url) =>
      url.startsWith('https:') ? 'http:${url.substring(6)}' : url;
}
