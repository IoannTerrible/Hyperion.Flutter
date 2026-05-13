import 'dart:async';
import 'dart:io';

import 'package:hyperion_flutter/auth/github/github_auth_config.dart';
import 'package:hyperion_flutter/auth/github/github_code_provider.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Desktop (Windows/Linux/macOS) GitHub sign-in via loopback OAuth.
///
/// Unlike the Google desktop flow this does NOT perform the code→token
/// exchange — the backend does it. The Flutter side only needs the
/// authorization code from GitHub's redirect.
///
/// Flow:
///   1. Bind `127.0.0.1:<random_port>` and treat `http://localhost:<port>/callback`
///      as the OAuth redirect_uri (must match a registered URL on the GitHub OAuth App).
///   2. Open the system browser at GitHub's authorize endpoint.
///   3. After consent, GitHub redirects back with `?code=…&state=…`.
///   4. Validate `state`, return `code`.
class DesktopGitHubCodeProvider implements GitHubCodeProvider {
  static const _authEndpoint = 'https://github.com/login/oauth/authorize';
  static const _redirectPort = 0; // ask OS for a free port

  final GitHubAuthConfig _config;

  DesktopGitHubCodeProvider(this._config);

  @override
  bool get isAvailable => _config.isConfigured;

  @override
  Future<String?> obtainCode() async {
    if (!_config.isConfigured) {
      AppLogger.log('[GitHubAuth] No client id configured for desktop');
      return null;
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _redirectPort);
    final redirectUri = 'http://localhost:${server.port}/callback';
    AppLogger.log('[GitHubAuth] Loopback listening on $redirectUri');

    final state = DateTime.now().microsecondsSinceEpoch.toString();
    final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': _config.clientId,
      'redirect_uri': redirectUri,
      'scope': 'read:user user:email',
      'state': state,
    });

    final completer = Completer<String?>();
    var callbackHandled = false;

    final sub = server.listen((HttpRequest req) async {
      try {
        final params = req.uri.queryParameters;
        final hasOauthParams = params.containsKey('code') ||
            params.containsKey('error') ||
            params.containsKey('state');

        if (!hasOauthParams) {
          req.response.statusCode = HttpStatus.noContent;
          await req.response.close();
          return;
        }

        if (callbackHandled) {
          req.response.headers.contentType = ContentType.html;
          req.response.write(_pageHtml('Already handled',
              'This sign-in was already processed. You can close this tab.'));
          await req.response.close();
          return;
        }
        callbackHandled = true;

        final returnedState = params['state'];
        final code = params['code'];
        final error = params['error'];

        req.response.headers.contentType = ContentType.html;

        if (error != null) {
          AppLogger.log('[GitHubAuth] GitHub returned error: $error');
          req.response.write(_pageHtml('Sign-in failed', 'GitHub reported: $error'));
          await req.response.close();
          completer.complete(null);
          return;
        }
        if (returnedState != state) {
          AppLogger.log('[GitHubAuth] State mismatch '
              '(expected $state, got $returnedState)');
          req.response.write(_pageHtml('State mismatch',
              'Possible CSRF — please try sign-in again.'));
          await req.response.close();
          completer.complete(null);
          return;
        }
        if (code == null || code.isEmpty) {
          AppLogger.log('[GitHubAuth] No code in callback');
          req.response.write(_pageHtml('No code returned',
              'GitHub did not return an authorization code.'));
          await req.response.close();
          completer.complete(null);
          return;
        }

        req.response.write(_pageHtml('Sign-in complete',
            'You can close this tab and return to Hyperion.'));
        await req.response.close();
        AppLogger.log('[GitHubAuth] Got code, completing flow');
        completer.complete(code);
      } catch (e, st) {
        AppLogger.log('[GitHubAuth] Error during loopback callback: $e\n$st');
        try {
          req.response.statusCode = HttpStatus.internalServerError;
          await req.response.close();
        } catch (_) {}
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      await sub.cancel();
      await server.close(force: true);
      throw Exception('Could not open browser for GitHub sign-in');
    }

    try {
      return await completer.future
          .timeout(const Duration(minutes: 5), onTimeout: () {
        AppLogger.log('[GitHubAuth] Loopback callback timed out after 5 min');
        return null;
      });
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  }

  static String _pageHtml(String title, String message) => '''
<!doctype html>
<html><head><meta charset="utf-8"><title>$title</title>
<style>body{font-family:system-ui,sans-serif;background:#1a1a1a;color:#eee;display:flex;height:100vh;margin:0;align-items:center;justify-content:center;}
.box{text-align:center;padding:2rem;border:1px solid #333;border-radius:8px;max-width:480px;}
h1{margin:0 0 .5rem;}</style></head>
<body><div class="box"><h1>$title</h1><p>$message</p></div></body></html>''';
}
