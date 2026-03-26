import 'package:clietn_server_application/app_theme.dart';
import 'package:clietn_server_application/auth/auth_api.dart';
import 'package:clietn_server_application/auth/auth_scope.dart';
import 'package:clietn_server_application/config/api_config.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String authLogoAsset = 'lib/auth_logo.png';

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

  static List<String> _passwordErrors(String password) {
    final p = password.trim();
    final errs = <String>[];
    if (p.length < 8) errs.add('At least 8 characters');
    if (!RegExp(r'[A-Z]').hasMatch(p)) errs.add('One uppercase letter');
    if (!RegExp(r'[a-z]').hasMatch(p)) errs.add('One lowercase letter');
    if (!RegExp(r'\d').hasMatch(p)) errs.add('One digit');
    return errs;
  }

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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthScope.of(context),
      builder: (context, _) {
        final notifier = AuthScope.of(context);
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
      errorBuilder: (_, __, ___) => Icon(
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
                builder: (_, __) {
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
                        hintStyle: TextStyle(color: AppTheme.inputText.withOpacity(0.7)),
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
                        hintStyle: TextStyle(color: AppTheme.inputText.withOpacity(0.7)),
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
                        hintStyle: TextStyle(color: AppTheme.inputText.withOpacity(0.7)),
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
        hintStyle: TextStyle(color: AppTheme.inputText.withOpacity(0.7)),
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
        hintStyle: TextStyle(color: AppTheme.inputText.withOpacity(0.7)),
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
            : () => notifier.signIn(
                  _emailController.text.trim(),
                  _passwordController.text.trim(),
                ),
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
    final client = http.Client();
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final codeCtrl = TextEditingController();
    final pwCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (sheetCtx) {
        var step = 0; // 0=email, 1=code, 2=newPassword
        var loading = false;
        String? error;
        String? resetToken;
        var obscurePw = true;

        return StatefulBuilder(
          builder: (sheetCtx, setS) {
            Future<void> sendCode() async {
              setS(() { loading = true; error = null; });
              try {
                await postForgotPassword(
                  client,
                  ApiConfig.authBaseUrl,
                  emailCtrl.text.trim(),
                  fallbackBaseUrl: ApiConfig.authFallbackUrl,
                );
                setS(() { step = 1; loading = false; });
              } on AuthApiException catch (e) {
                setS(() { error = e.message; loading = false; });
              } catch (_) {
                setS(() { error = 'Connection failed. Check your network.'; loading = false; });
              }
            }

            Future<void> verifyCode() async {
              setS(() { loading = true; error = null; });
              try {
                resetToken = await postVerifyResetCode(
                  client,
                  ApiConfig.authBaseUrl,
                  emailCtrl.text.trim(),
                  codeCtrl.text.trim(),
                  fallbackBaseUrl: ApiConfig.authFallbackUrl,
                );
                setS(() { step = 2; loading = false; });
              } on AuthApiException catch (e) {
                setS(() { error = e.message; loading = false; });
              } catch (_) {
                setS(() { error = 'Connection failed. Check your network.'; loading = false; });
              }
            }

            Future<void> resetPassword() async {
              final token = resetToken;
              if (token == null) return;
              setS(() { loading = true; error = null; });
              try {
                await postResetPassword(
                  client,
                  ApiConfig.authBaseUrl,
                  token,
                  pwCtrl.text,
                  fallbackBaseUrl: ApiConfig.authFallbackUrl,
                );
                if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      'Password reset successfully. Please sign in.',
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                    backgroundColor: AppTheme.statusOnline.withOpacity(0.8),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 4),
                  ));
                }
              } on AuthApiException catch (e) {
                setS(() { error = e.message; loading = false; });
              } catch (_) {
                setS(() { error = 'Connection failed. Check your network.'; loading = false; });
              }
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

            final titles = ['Reset Password', 'Enter Code', 'New Password'];
            final subtitles = [
              'Enter your account email to receive a reset code.',
              'We sent a 6-digit code to ${emailCtrl.text.trim()}.',
              'Choose a strong new password for your account.',
            ];
            final pwErrors = step == 2 ? _passwordErrors(pwCtrl.text) : <String>[];

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
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
                        value: (step + 1) / 3,
                        backgroundColor: AppTheme.inputBorder.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentLink),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      titles[step],
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitles[step],
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // --- Step 0: Email ---
                    if (step == 0) ...[
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setS(() {}),
                        style: TextStyle(color: AppTheme.inputText, fontSize: 16),
                        decoration: inputDecoration.copyWith(
                          hintText: 'Email address',
                          hintStyle: TextStyle(color: AppTheme.inputText.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.mail_outline, color: AppTheme.inputText, size: 22),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _forgotButton(
                        label: 'Send Code',
                        loading: loading,
                        onPressed: emailCtrl.text.trim().isNotEmpty && !loading ? sendCode : null,
                      ),

                    // --- Step 1: Code ---
                    ] else if (step == 1) ...[
                      TextField(
                        controller: codeCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        onChanged: (_) => setS(() {}),
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
                            color: AppTheme.inputText.withOpacity(0.3),
                            fontSize: 30,
                            letterSpacing: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _forgotButton(
                        label: 'Verify Code',
                        loading: loading,
                        onPressed: codeCtrl.text.trim().length == 6 && !loading ? verifyCode : null,
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: loading ? null : () async {
                          setS(() { loading = true; error = null; });
                          try {
                            await postForgotPassword(
                              client,
                              ApiConfig.authBaseUrl,
                              emailCtrl.text.trim(),
                              fallbackBaseUrl: ApiConfig.authFallbackUrl,
                            );
                          } finally {
                            setS(() => loading = false);
                          }
                        },
                        child: Text(
                          'Resend code',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.accentLink, fontSize: 14),
                        ),
                      ),

                    // --- Step 2: New password ---
                    ] else if (step == 2) ...[
                      TextField(
                        controller: pwCtrl,
                        obscureText: obscurePw,
                        onChanged: (_) => setS(() {}),
                        style: TextStyle(color: AppTheme.inputText, fontSize: 16),
                        decoration: inputDecoration.copyWith(
                          hintText: 'New password',
                          hintStyle: TextStyle(color: AppTheme.inputText.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.lock_outline, color: AppTheme.inputText, size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePw ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.inputText,
                              size: 22,
                            ),
                            onPressed: () => setS(() => obscurePw = !obscurePw),
                          ),
                        ),
                      ),
                      if (pwCtrl.text.isNotEmpty && pwErrors.isNotEmpty) ...[
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
                      _forgotButton(
                        label: 'Reset Password',
                        loading: loading,
                        onPressed: pwCtrl.text.isNotEmpty && pwErrors.isEmpty && !loading
                            ? resetPassword
                            : null,
                      ),
                    ],

                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.statusOffline, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        emailCtrl.dispose();
        codeCtrl.dispose();
        pwCtrl.dispose();
        client.close();
      });
    });
  }

  Widget _forgotButton({
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
          disabledBackgroundColor: AppTheme.buttonPrimary.withOpacity(0.5),
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
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                    Uri.parse(ApiConfig.privacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
