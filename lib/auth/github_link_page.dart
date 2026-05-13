import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_api.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';

class GitHubLinkPage extends StatefulWidget {
  final String continuationToken;
  final String email;

  const GitHubLinkPage({super.key, required this.continuationToken, required this.email});

  @override
  State<GitHubLinkPage> createState() => _GitHubLinkPageState();
}

class _GitHubLinkPageState extends State<GitHubLinkPage> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = AuthScope.of(context);
      final result = await notifier.linkGitHubAccount(
        widget.continuationToken,
        _passwordController.text,
      );
      if (result.status == GitHubSignInStatus.success) {
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        setState(() => _error = result.errorMessage ?? 'Could not link account');
      }
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account already exists')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.defaultPageGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'An account with ${widget.email} already exists.\nEnter your password to link GitHub.',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _busy ? null : _link,
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Link GitHub'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
