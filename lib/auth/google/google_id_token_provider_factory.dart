import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hyperion_flutter/auth/google/android_google_id_token_provider.dart';
import 'package:hyperion_flutter/auth/google/desktop_google_id_token_provider.dart';
import 'package:hyperion_flutter/auth/google/google_id_token_provider.dart';

class GoogleAuthConfig {
  final String androidServerClientId;
  final String desktopClientId;
  final String? desktopClientSecret;

  const GoogleAuthConfig({
    this.androidServerClientId = '',
    this.desktopClientId = '',
    this.desktopClientSecret,
  });
}

class GoogleIdTokenProviderFactory {
  static GoogleIdTokenProvider create(GoogleAuthConfig config) {
    if (kIsWeb) {
      // Web builds use the JS Google Identity Services (handled by Blazor) — not used in Flutter web build for now.
      return _NoopProvider();
    }
    if (Platform.isAndroid) {
      return AndroidGoogleIdTokenProvider(config.androidServerClientId);
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return DesktopGoogleIdTokenProvider(config.desktopClientId, clientSecret: config.desktopClientSecret);
    }
    // iOS is intentionally not supported in this MVP — see project decision.
    return _NoopProvider();
  }
}

class _NoopProvider implements GoogleIdTokenProvider {
  @override
  bool get isAvailable => false;
  @override
  Future<String?> obtainIdToken() async => null;
}
