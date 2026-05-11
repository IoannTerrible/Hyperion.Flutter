import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:hyperion_flutter/auth/google/google_id_token_provider.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Desktop (Windows/Linux/macOS) Google sign-in via loopback OAuth + PKCE.
///
/// Flow:
///   1. Start a local HTTP server on `127.0.0.1:<random_port>`
///   2. Generate PKCE verifier/challenge + state
///   3. Open the system browser at Google's authorization endpoint
///   4. After the user signs in, Google redirects to our loopback URL with `code`
///   5. Exchange the auth code for `id_token` against `https://oauth2.googleapis.com/token`
///   6. Return the id_token
///
/// Requires a "Desktop application" OAuth client in Google Cloud Console.
class DesktopGoogleIdTokenProvider implements GoogleIdTokenProvider {
  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _redirectPort = 0; // ask OS for a free port

  final String clientId;
  final String? clientSecret;

  DesktopGoogleIdTokenProvider(this.clientId, {this.clientSecret});

  @override
  bool get isAvailable => clientId.isNotEmpty;

  @override
  Future<String?> obtainIdToken() async {
    if (clientId.isEmpty) {
      AppLogger.log('[GoogleAuth] No desktop client id configured');
      return null;
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _redirectPort);
    final redirectUri = 'http://127.0.0.1:${server.port}';
    AppLogger.log('[GoogleAuth] Loopback listening on $redirectUri');

    final verifier = _randomBase64Url(32);
    final challenge = base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
    final state = _randomBase64Url(16);

    final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'openid email profile',
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
    });

    final completer = Completer<String?>();
    var callbackHandled = false;

    final sub = server.listen((HttpRequest req) async {
      try {
        final path = req.uri.path;
        final params = req.uri.queryParameters;
        final hasOauthParams = params.containsKey('code') ||
            params.containsKey('error') ||
            params.containsKey('state');

        // Ignore everything that isn't the OAuth callback (favicon.ico, /robots.txt,
        // browser-side prefetches, etc.). Returning 204 is cheap and won't race
        // against the real callback for the completer.
        if (path != '/' || !hasOauthParams) {
          req.response.statusCode = HttpStatus.noContent;
          await req.response.close();
          return;
        }

        // Guard against duplicate OAuth callbacks (some browsers retry on slow networks).
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
          AppLogger.log('[GoogleAuth] Google returned error: $error');
          req.response.write(_pageHtml('Sign-in failed', 'Google reported: $error'));
          await req.response.close();
          completer.complete(null);
          return;
        }
        if (returnedState != state) {
          AppLogger.log('[GoogleAuth] State mismatch '
              '(expected $state, got $returnedState)');
          req.response.write(_pageHtml('State mismatch',
              'Possible CSRF — please try sign-in again.'));
          await req.response.close();
          completer.complete(null);
          return;
        }
        if (code == null || code.isEmpty) {
          AppLogger.log('[GoogleAuth] No code in callback');
          req.response.write(_pageHtml('No code returned',
              'Google did not return an authorization code.'));
          await req.response.close();
          completer.complete(null);
          return;
        }

        // Exchange code → tokens BEFORE telling the user we're done, so that any
        // failure (invalid_grant, network blip, etc.) surfaces in the browser tab
        // instead of confusingly showing "Sign-in complete" with no token.
        AppLogger.log('[GoogleAuth] Got code, exchanging for tokens...');
        http.Response tokenResponse;
        try {
          tokenResponse = await http
              .post(
                Uri.parse(_tokenEndpoint),
                headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
                body: {
                  'grant_type': 'authorization_code',
                  'client_id': clientId,
                  if (clientSecret != null && clientSecret!.isNotEmpty)
                    'client_secret': clientSecret!,
                  'code': code,
                  'code_verifier': verifier,
                  'redirect_uri': redirectUri,
                },
              )
              .timeout(const Duration(seconds: 30));
        } catch (e) {
          AppLogger.log('[GoogleAuth] Network error during token exchange: $e');
          req.response.write(_pageHtml('Sign-in failed',
              'Could not reach Google to exchange the authorization code.'));
          await req.response.close();
          completer.complete(null);
          return;
        }

        if (tokenResponse.statusCode != 200) {
          AppLogger.log('[GoogleAuth] Token exchange failed '
              '(${tokenResponse.statusCode}): ${tokenResponse.body}');
          req.response.write(_pageHtml('Sign-in failed',
              'Google rejected the token exchange. Check the app log for details.'));
          await req.response.close();
          completer.complete(null);
          return;
        }

        final map = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
        final idToken = map['id_token'] as String?;
        if (idToken == null || idToken.isEmpty) {
          AppLogger.log('[GoogleAuth] Token response had no id_token: '
              '${tokenResponse.body}');
          req.response.write(_pageHtml('Sign-in failed',
              'No id_token returned from Google.'));
          await req.response.close();
          completer.complete(null);
          return;
        }

        req.response.write(_pageHtml('Sign-in complete',
            'You can close this tab and return to Hyperion.'));
        await req.response.close();
        AppLogger.log('[GoogleAuth] Got id_token, completing flow');
        completer.complete(idToken);
      } catch (e, st) {
        AppLogger.log('[GoogleAuth] Error during loopback callback: $e\n$st');
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
      throw Exception('Could not open browser for Google sign-in');
    }

    try {
      return await completer.future
          .timeout(const Duration(minutes: 5), onTimeout: () {
        AppLogger.log('[GoogleAuth] Loopback callback timed out after 5 min');
        return null;
      });
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  }

  static String _randomBase64Url(int byteLen) {
    final rng = Random.secure();
    final bytes = List<int>.generate(byteLen, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _pageHtml(String title, String message) => '''
<!doctype html>
<html><head><meta charset="utf-8"><title>$title</title>
<style>body{font-family:system-ui,sans-serif;background:#1a1a1a;color:#eee;display:flex;height:100vh;margin:0;align-items:center;justify-content:center;}
.box{text-align:center;padding:2rem;border:1px solid #333;border-radius:8px;max-width:480px;}
h1{margin:0 0 .5rem;}</style></head>
<body><div class="box"><h1>$title</h1><p>$message</p></div></body></html>''';
}
