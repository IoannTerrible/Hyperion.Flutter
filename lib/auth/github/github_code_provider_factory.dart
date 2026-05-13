import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hyperion_flutter/auth/github/android_github_code_provider.dart';
import 'package:hyperion_flutter/auth/github/desktop_github_code_provider.dart';
import 'package:hyperion_flutter/auth/github/github_auth_config.dart';
import 'package:hyperion_flutter/auth/github/github_code_provider.dart';

class _NoopGitHubProvider implements GitHubCodeProvider {
  const _NoopGitHubProvider();
  @override
  bool get isAvailable => false;
  @override
  Future<String?> obtainCode() async => null;
}

GitHubCodeProvider createGitHubCodeProvider(GitHubAuthConfig config) {
  if (kIsWeb) return const _NoopGitHubProvider();
  if (Platform.isAndroid || Platform.isIOS) return AndroidGitHubCodeProvider(config);
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return DesktopGitHubCodeProvider(config);
  }
  return const _NoopGitHubProvider();
}
