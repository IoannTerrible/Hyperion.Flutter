import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:hyperion_flutter/auth/github/github_auth_config.dart';
import 'package:hyperion_flutter/auth/github/github_code_provider.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mobile implementation: open the GitHub authorize page in the system
/// browser via `url_launcher`, then listen for the redirect back to the
/// app's custom-scheme URL via `app_links`.
///
/// Flow:
///   1. Build `https://github.com/login/oauth/authorize?client_id=…&redirect_uri=hyperion://oauth/github&state=…`
///   2. Open in the system browser (so user's existing GitHub session is reused).
///   3. After consent, GitHub 302s to `hyperion://oauth/github?code=…&state=…`,
///      which Android dispatches to MainActivity via the registered intent
///      filter; `app_links` surfaces it as a `Uri`.
///   4. Validate `state`, return `code`.
class AndroidGitHubCodeProvider implements GitHubCodeProvider {
  final GitHubAuthConfig _config;
  final AppLinks _appLinks;

  AndroidGitHubCodeProvider(this._config) : _appLinks = AppLinks();

  @override
  bool get isAvailable => _config.isConfigured;

  @override
  Future<String?> obtainCode() async {
    if (!_config.isConfigured) {
      AppLogger.log('[GitHubAuth] No client id configured for mobile');
      return null;
    }

    final state = DateTime.now().microsecondsSinceEpoch.toString();
    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': _config.clientId,
      'redirect_uri': _config.mobileRedirectUri,
      'scope': 'read:user user:email',
      'state': state,
    });

    final completer = Completer<String?>();
    late StreamSubscription<Uri> sub;
    sub = _appLinks.uriLinkStream.listen((uri) {
      if (!uri.toString().startsWith(_config.mobileRedirectUri)) return;
      final receivedState = uri.queryParameters['state'];
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];
      if (completer.isCompleted) return;
      if (error != null) {
        AppLogger.log('[GitHubAuth] OAuth returned error: $error');
        completer.complete(null);
      } else if (receivedState != state) {
        AppLogger.log('[GitHubAuth] State mismatch '
            '(expected $state, got $receivedState)');
        completer.complete(null);
      } else {
        completer.complete(code);
      }
      sub.cancel();
    });

    try {
      final launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        await sub.cancel();
        return null;
      }
    } catch (e) {
      AppLogger.log('[GitHubAuth] Failed to launch browser: $e');
      await sub.cancel();
      return null;
    }

    // Hard timeout — if the user cancels or the redirect never arrives,
    // free the future so the UI does not hang.
    return completer.future.timeout(const Duration(minutes: 5), onTimeout: () {
      AppLogger.log('[GitHubAuth] Custom-scheme redirect timed out after 5 min');
      sub.cancel();
      return null;
    });
  }
}
