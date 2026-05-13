import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_api.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';

class GitHubUsernamePage extends StatefulWidget {
  final String continuationToken;
  final String email;
  final String suggestedName;

  const GitHubUsernamePage({
    super.key,
    required this.continuationToken,
    required this.email,
    required this.suggestedName,
  });

  @override
  State<GitHubUsernamePage> createState() => _GitHubUsernamePageState();
}

class _GitHubUsernamePageState extends State<GitHubUsernamePage> {
  late final TextEditingController _usernameController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.suggestedName);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = AuthScope.of(context);
      final result = await notifier.completeGitHubRegistration(widget.continuationToken, username);
      if (result.status == GitHubSignInStatus.success) {
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        setState(() => _error = result.errorMessage ?? 'Could not finish registration');
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
      appBar: AppBar(title: const Text('Choose your username')),
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
                  'Almost done! Pick a username for your new account (${widget.email}).',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: '3–100 characters, must be unique',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _busy ? null : _create,
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
