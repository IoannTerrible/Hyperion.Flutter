import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_flutter/auth/github/android_github_code_provider.dart';
import 'package:hyperion_flutter/auth/github/github_auth_config.dart';
import 'package:hyperion_flutter/auth/github/github_code_provider.dart';
import 'package:hyperion_flutter/auth/github/github_code_provider_factory.dart';
import 'package:hyperion_flutter/auth/github/desktop_github_code_provider.dart';

void main() {
  group('GitHubAuthConfig', () {
    test('isConfigured is false when clientId is empty', () {
      const config = GitHubAuthConfig(clientId: '');
      expect(config.isConfigured, isFalse);
    });

    test('isConfigured is true when clientId is non-empty', () {
      const config = GitHubAuthConfig(clientId: 'Iv1.abc123');
      expect(config.isConfigured, isTrue);
    });

    test('defaults to hyperion://oauth/github mobile redirect', () {
      const config = GitHubAuthConfig(clientId: 'Iv1.abc123');
      expect(config.mobileRedirectUri, 'hyperion://oauth/github');
    });
  });

  group('createGitHubCodeProvider', () {
    test('returns provider whose isAvailable is false when clientId is empty', () {
      const config = GitHubAuthConfig(clientId: '');
      final provider = createGitHubCodeProvider(config);
      expect(provider.isAvailable, isFalse);
    });

    test('returns a real provider when clientId is non-empty', () {
      const config = GitHubAuthConfig(clientId: 'Iv1.abc123');
      final provider = createGitHubCodeProvider(config);
      expect(provider, isA<GitHubCodeProvider>());
      expect(provider.isAvailable, isTrue);
    });
  });

  group('AndroidGitHubCodeProvider', () {
    test('isAvailable mirrors clientId presence', () {
      final empty = AndroidGitHubCodeProvider(const GitHubAuthConfig(clientId: ''));
      expect(empty.isAvailable, isFalse);

      final configured = AndroidGitHubCodeProvider(const GitHubAuthConfig(clientId: 'Iv1.abc'));
      expect(configured.isAvailable, isTrue);
    });

    test('obtainCode returns null immediately when not configured', () async {
      final provider = AndroidGitHubCodeProvider(const GitHubAuthConfig(clientId: ''));
      expect(await provider.obtainCode(), isNull);
    });
  });

  group('DesktopGitHubCodeProvider', () {
    test('isAvailable mirrors clientId presence', () {
      final empty = DesktopGitHubCodeProvider(const GitHubAuthConfig(clientId: ''));
      expect(empty.isAvailable, isFalse);

      final configured = DesktopGitHubCodeProvider(const GitHubAuthConfig(clientId: 'Iv1.abc'));
      expect(configured.isAvailable, isTrue);
    });

    test('obtainCode returns null immediately when not configured', () async {
      final provider = DesktopGitHubCodeProvider(const GitHubAuthConfig(clientId: ''));
      expect(await provider.obtainCode(), isNull);
    });
  });
}
