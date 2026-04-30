import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_api.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';
import 'package:hyperion_flutter/biometric/biometric_scope.dart';
import 'package:hyperion_flutter/config/api_config.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String authLogoAsset = 'lib/auth_logo.png';

List<String> _passwordErrors(String password) {
  final p = password.trim();
  final errs = <String>[];
  if (p.length < 8) errs.add('At least 8 characters');
  if (!RegExp(r'[A-Z]').hasMatch(p)) errs.add('One uppercase letter');
  if (!RegExp(r'[a-z]').hasMatch(p)) errs.add('One lowercase letter');
  if (!RegExp(r'\d').hasMatch(p)) errs.add('One digit');
  return errs;
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _obscurePassword = true;
  String? _lastShownError;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TapGestureRecognizer _privacyPolicyTapRecognizer;

  void _showErrorSnackBarIfNeeded(String? lastError) {
    if (lastError == null) {
      _lastShownError = null;
      return;
    }
    if (lastError == _lastShownError) return;
    _lastShownError = lastError;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lastError,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          backgroundColor: AppTheme.snackbarErrorBackground,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.all(16),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _privacyPolicyTapRecognizer = TapGestureRecognizer()
      ..onTap = () => launchUrl(
            Uri.parse(ApiConfig.privacyPolicyUrl),
            mode: LaunchMode.externalApplication,
          );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _privacyPolicyTapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = AuthScope.of(context);
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final isLoading = notifier.isLoading;
        final lastError = notifier.lastError;
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppTheme.defaultPageGradient,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildLogo(),
                    const SizedBox(height: 32),
                    Text(
                      'Sign in to your Account',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    _buildSignUpPrompt(context),
                    const SizedBox(height: 32),
                    _buildEmailField(),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    Builder(
                      builder: (_) {
                        _showErrorSnackBarIfNeeded(lastError);
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildForgotPasswordLink(context),
                    const SizedBox(height: 20),
                    _buildSignInButton(isLoading),
                    _buildBiometricButton(isLoading),
                    const SizedBox(height: 16),
                    _buildDemoLink(isLoading),
                    const SizedBox(height: 24),
                    _buildPrivacyPolicyLink(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      authLogoAsset,
      height: 80,
      width: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        Icons.account_circle,
        size: 80,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildSignUpPrompt(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () => _showRegisterSheet(context),
          child: Text(
            'Sign Up',
            style: TextStyle(
              color: AppTheme.accentLink,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showRegisterSheet(BuildContext context) {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool privacyAccepted = false;
    final notifier = AuthScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: ListenableBuilder(
                listenable: notifier,
                builder: (_, _) {
                  final loading = notifier.isLoading;
                  final err = notifier.lastError;
                  final pwErrors = _passwordErrors(passwordController.text);
                  final canSubmit = !loading &&
                      usernameController.text.trim().isNotEmpty &&
                      emailController.text.trim().isNotEmpty &&
                      pwErrors.isEmpty &&
                      privacyAccepted;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: usernameController,
                      onChanged: (_) => setSheetState(() {}),
                      style: TextStyle(color: AppTheme.inputText, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Username',
                        hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha:0.7)),
                        prefixIcon: Icon(Icons.person_outline, color: AppTheme.inputText, size: 22),
                        filled: true,
                        fillColor: AppTheme.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setSheetState(() {}),
                      style: TextStyle(color: AppTheme.inputText, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha:0.7)),
                        prefixIcon: Icon(Icons.mail_outline, color: AppTheme.inputText, size: 22),
                        filled: true,
                        fillColor: AppTheme.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: TextStyle(color: AppTheme.inputText, fontSize: 16),
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha:0.7)),
                        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.inputText, size: 22),
                        filled: true,
                        fillColor: AppTheme.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                      ),
                    ),
                    if (pwErrors.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final e in pwErrors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• $e',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ),
                    ],
                    if (err != null) ...[
                      const SizedBox(height: 12),
                      Text(err, style: TextStyle(color: AppTheme.statusOffline, fontSize: 14)),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: privacyAccepted,
                          onChanged: loading
                              ? null
                              : (v) => setSheetState(() => privacyAccepted = v ?? false),
                          activeColor: AppTheme.buttonPrimary,
                          side: BorderSide(color: AppTheme.textSecondary),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              children: [
                                const TextSpan(text: 'I accept the '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                    color: AppTheme.accentLink,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => launchUrl(
                                          Uri.parse(ApiConfig.privacyPolicyUrl),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: canSubmit
                          ? () async {
                              await notifier.register(
                                usernameController.text.trim(),
                                emailController.text.trim(),
                                passwordController.text.trim(),
                              );
                              if (sheetContext.mounted && notifier.lastError == null) {
                                Navigator.of(sheetContext).pop();
                              }
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.buttonPrimary,
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
                            )
                          : const Text('Register'),
                    ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        usernameController.dispose();
        emailController.dispose();
        passwordController.dispose();
      });
    });
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      style: TextStyle(color: AppTheme.inputText, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'admin@hyperion.local',
        hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha:0.7)),
        prefixIcon: Icon(Icons.mail_outline, color: AppTheme.inputText, size: 22),
        filled: true,
        fillColor: AppTheme.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          borderSide: const BorderSide(color: AppTheme.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          borderSide: const BorderSide(color: AppTheme.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          borderSide: BorderSide(color: AppTheme.accentLink, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: AppTheme.inputText, fontSize: 16),
      decoration: InputDecoration(
        hintText: '••••••',
        hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha:0.7)),
        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.inputText, size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: AppTheme.inputText,
            size: 22,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: AppTheme.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          borderSide: const BorderSide(color: AppTheme.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          borderSide: const BorderSide(color: AppTheme.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          borderSide: BorderSide(color: AppTheme.accentLink, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSignInButton(bool isLoading) {
    final notifier = AuthScope.of(context);
    final lock = notifier.lockoutRemaining;
    final locked = lock != null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading || locked
            ? null
            : () async {
                final email = _emailController.text.trim();
                final pw = _passwordController.text.trim();
                await notifier.signIn(email, pw);
                if (!mounted) return;
                // Save credentials so the user can sign in with biometrics next time.
                final bio = BiometricScope.maybeOf(context);
                if (bio != null && bio.isAvailable && notifier.lastError == null) {
                  await bio.saveCredentials(email, pw);
                }
              },
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.buttonPrimary,
          foregroundColor: AppTheme.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
              )
            : Text(
                locked
                    ? 'Try again in ${lock.inMinutes > 0 ? '${lock.inMinutes} min' : '${lock.inSeconds}s'}'
                    : 'Sign in',
              ),
      ),
    );
  }

  Widget _buildForgotPasswordLink(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => _showForgotPasswordSheet(context),
        child: Text(
          'Forgot password?',
          style: TextStyle(color: AppTheme.accentLink, fontSize: 14),
        ),
      ),
    );
  }

  void _showForgotPasswordSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (_) => _ResetPasswordSheet(
        initialEmail: _emailController.text.trim(),
      ),
    );
  }

  Widget _buildBiometricButton(bool isLoading) {
    final bio = BiometricScope.maybeOf(context);
    if (bio == null || !bio.canSignInWithBiometrics) return const SizedBox.shrink();

    final busy = isLoading || bio.isBiometricSigningIn;
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          width: 64,
          height: 64,
          child: OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    // If multiple accounts are stored the UI layer should show
                    // an account picker and call authenticateAndGetCredentials
                    // with the chosen account. For now we use the most recently
                    // added account (last in list).
                    final account = bio.savedAccounts.last;
                    final creds =
                        await bio.authenticateAndGetCredentials(account);
                    if (!mounted || creds == null) return;
                    await AuthScope.of(context).signIn(
                      creds.usernameOrEmail,
                      creds.password,
                    );
                  },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              side: BorderSide(color: AppTheme.inputBorder, width: 1.5),
            ),
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textPrimary,
                    ),
                  )
                : Image.asset(
                    'lib/HandFace.png',
                    width: 36,
                    height: 36,
                    color: AppTheme.textPrimary,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoLink(bool isLoading) {
    final notifier = AuthScope.of(context);
    return GestureDetector(
      onTap: isLoading ? null : () => notifier.signInAsDemo(),
      child: Text(
        'Continue as demo',
        style: TextStyle(
          color: isLoading ? AppTheme.textSecondary : AppTheme.accentLink,
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyLink() {
    return Text.rich(
      TextSpan(
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        children: [
          const TextSpan(text: 'By using this app you agree to our '),
          TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
              color: AppTheme.accentLink,
              decoration: TextDecoration.underline,
            ),
            recognizer: _privacyPolicyTapRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Reset-password bottom sheet — persists step to secure storage so users
// who switch to their email app and return land on the right step.
// ---------------------------------------------------------------------------

class _ResetPasswordSheet extends StatefulWidget {
  final String initialEmail;
  const _ResetPasswordSheet({required this.initialEmail});

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyStep  = 'rp_step';
  static const _keyEmail = 'rp_email';
  static const _keyToken = 'rp_token';

  late final http.Client              _client;
  late final TextEditingController    _emailCtrl;
  late final TextEditingController    _codeCtrl;
  late final TextEditingController    _pwCtrl;

  int     _step      = 0;
  bool    _loading   = false;
  bool    _restoring = true; // true while reading storage on first open
  String? _error;
  String? _resetToken;
  bool    _obscurePw = true;

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _client    = http.Client();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _codeCtrl  = TextEditingController();
    _pwCtrl    = TextEditingController();
    _loadSavedState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _client.close();
    super.dispose();
  }

  // ── storage helpers ───────────────────────────────────────────────────────

  Future<void> _loadSavedState() async {
    final stepStr = await _storage.read(key: _keyStep);
    if (stepStr == null) {
      if (mounted) setState(() => _restoring = false);
      return;
    }
    final savedStep  = int.tryParse(stepStr) ?? 0;
    final savedEmail = await _storage.read(key: _keyEmail);
    final savedToken = await _storage.read(key: _keyToken);
    if (!mounted) return;
    setState(() {
      _step = savedStep;
      if (savedEmail != null && savedEmail.isNotEmpty) _emailCtrl.text = savedEmail;
      _resetToken = savedToken;
      _restoring  = false;
    });
  }

  Future<void> _saveState() async {
    await _storage.write(key: _keyStep,  value: _step.toString());
    await _storage.write(key: _keyEmail, value: _emailCtrl.text.trim());
    if (_resetToken != null) {
      await _storage.write(key: _keyToken, value: _resetToken!);
    }
  }

  Future<void> _clearState() async {
    await Future.wait([
      _storage.delete(key: _keyStep),
      _storage.delete(key: _keyEmail),
      _storage.delete(key: _keyToken),
    ]);
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _sendCode() async {
    setState(() { _loading = true; _error = null; });
    try {
      await postForgotPassword(
        _client,
        ApiConfig.authBaseUrl,
        _emailCtrl.text.trim(),
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      setState(() { _step = 1; _loading = false; });
      await _saveState();
    } on AuthApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Connection failed. Check your network.'; _loading = false; });
    }
  }

  Future<void> _verifyCode() async {
    setState(() { _loading = true; _error = null; });
    try {
      _resetToken = await postVerifyResetCode(
        _client,
        ApiConfig.authBaseUrl,
        _emailCtrl.text.trim(),
        _codeCtrl.text.trim(),
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      setState(() { _step = 2; _loading = false; });
      await _saveState();
    } on AuthApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Connection failed. Check your network.'; _loading = false; });
    }
  }

  Future<void> _resetPassword() async {
    final token = _resetToken;
    if (token == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      await postResetPassword(
        _client,
        ApiConfig.authBaseUrl,
        token,
        _pwCtrl.text,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      await _clearState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'Password reset successfully. Please sign in.',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.statusOnline.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ));
      Navigator.of(context).pop();
    } on AuthApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Connection failed. Check your network.'; _loading = false; });
    }
  }

  Future<void> _startOver() async {
    await _clearState();
    setState(() {
      _step       = 0;
      _error      = null;
      _resetToken = null;
      _codeCtrl.clear();
      _pwCtrl.clear();
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  Widget _actionButton({
    required String label,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.buttonPrimary,
          foregroundColor: AppTheme.textPrimary,
          disabledBackgroundColor: AppTheme.buttonPrimary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show a brief spinner while reading storage on first open.
    if (_restoring) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: AppTheme.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
        borderSide: const BorderSide(color: AppTheme.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
        borderSide: const BorderSide(color: AppTheme.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
        borderSide: BorderSide(color: AppTheme.accentLink, width: 1.5),
      ),
    );

    final titles    = ['Reset Password', 'Enter Code', 'New Password'];
    final subtitles = [
      'Enter your account email to receive a reset code.',
      'We sent a 6-digit code to ${_emailCtrl.text.trim()}.',
      'Choose a strong new password for your account.',
    ];
    final pwErrors = _step == 2 ? _passwordErrors(_pwCtrl.text) : <String>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_step + 1) / 3,
                backgroundColor: AppTheme.inputBorder.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentLink),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 20),
            // Title row — show "Start over" when mid-flow so users aren't
            // stuck if they return after a token has expired.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    titles[_step],
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_step > 0)
                  TextButton(
                    onPressed: _loading ? null : _startOver,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Start over', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitles[_step],
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // --- Step 0: Email ---
            if (_step == 0) ...[
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: AppTheme.inputText, fontSize: 16),
                decoration: inputDecoration.copyWith(
                  hintText: 'Email address',
                  hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.mail_outline, color: AppTheme.inputText, size: 22),
                ),
              ),
              const SizedBox(height: 20),
              _actionButton(
                label: 'Send Code',
                loading: _loading,
                onPressed: _emailCtrl.text.trim().isNotEmpty && !_loading ? _sendCode : null,
              ),

            // --- Step 1: Code ---
            ] else if (_step == 1) ...[
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: AppTheme.inputText,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
                decoration: inputDecoration.copyWith(
                  counterText: '',
                  hintText: '------',
                  hintStyle: TextStyle(
                    color: AppTheme.inputText.withValues(alpha: 0.3),
                    fontSize: 30,
                    letterSpacing: 10,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _actionButton(
                label: 'Verify Code',
                loading: _loading,
                onPressed: _codeCtrl.text.trim().length == 6 && !_loading ? _verifyCode : null,
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _loading ? null : () async {
                  setState(() { _loading = true; _error = null; });
                  try {
                    await postForgotPassword(
                      _client,
                      ApiConfig.authBaseUrl,
                      _emailCtrl.text.trim(),
                      fallbackBaseUrl: ApiConfig.authFallbackUrl,
                    );
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: Text(
                  'Resend code',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.accentLink, fontSize: 14),
                ),
              ),

            // --- Step 2: New password ---
            ] else if (_step == 2) ...[
              TextField(
                controller: _pwCtrl,
                obscureText: _obscurePw,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: AppTheme.inputText, fontSize: 16),
                decoration: inputDecoration.copyWith(
                  hintText: 'New password',
                  hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.inputText, size: 22),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePw ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.inputText,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _obscurePw = !_obscurePw),
                  ),
                ),
              ),
              if (_pwCtrl.text.isNotEmpty && pwErrors.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final e in pwErrors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• $e',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              _actionButton(
                label: 'Reset Password',
                loading: _loading,
                onPressed: _pwCtrl.text.isNotEmpty && pwErrors.isEmpty && !_loading
                    ? _resetPassword
                    : null,
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.statusOffline, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
