import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_api.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';
import 'package:hyperion_flutter/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _appLinks = AppLinks();
  final http.Client _client = http.Client();
  StreamSubscription<Uri>? _sub;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });
    _appLinks.getLatestLink().then((uri) {
      if (!mounted) return;
      if (uri != null) _handleIncomingUri(uri);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    // Expected: hyperion://verify-email?token=...
    final token = uri.queryParameters['token'];
    final isVerify = uri.scheme.toLowerCase() == 'hyperion' &&
        (uri.host == 'verify-email' || uri.path.replaceAll('/', '') == 'verify-email');
    if (!isVerify || token == null || token.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final notifier = AuthScope.of(context);
      final tokenStr = token.trim();
      final authToken = await notifier.getToken();
      if (authToken == null || authToken.isEmpty) {
        setState(() => _message = 'Session expired. Please sign in again.');
        await notifier.signOut();
        return;
      }

      await postVerifyEmail(
        _client,
        ApiConfig.authBaseUrl,
        token: tokenStr,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );

      await notifier.refreshProfile();
      if (!mounted) return;
      setState(() => _message = 'Email verified. You can continue.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final authToken = await AuthScope.of(context).getToken();
      if (!mounted) return;
      if (authToken == null || authToken.isEmpty) {
        setState(() => _message = 'Session expired. Please sign in again.');
        await AuthScope.of(context).signOut();
        return;
      }
      await postResendVerification(
        _client,
        ApiConfig.authBaseUrl,
        token: authToken,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      if (!mounted) return;
      setState(() => _message = 'Verification email sent.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Resend failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkAgain() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await AuthScope.of(context).refreshProfile();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.defaultPageGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Verify your email',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Open the link on this device. If the app doesn’t open, make sure deep links are configured for the scheme "hyperion://".',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_message != null) ...[
                  Text(
                    _message!,
                    style: TextStyle(
                      color: _message!.toLowerCase().contains('failed') ? AppTheme.statusOffline : AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _resend,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.buttonPrimary,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                  ),
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Resend email'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _checkAgain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.textSecondary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                  ),
                  child: const Text('I verified, check again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => AuthScope.of(context).signOut(),
                  child: Text('Sign out', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

