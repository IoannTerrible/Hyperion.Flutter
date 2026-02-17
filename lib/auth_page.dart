import 'package:clietn_server_application/app_theme.dart';
import 'package:clietn_server_application/auth/auth_scope.dart';
import 'package:flutter/material.dart';

const String authLogoAsset = 'lib/auth_logo.png';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _obscurePassword = true;
  final _emailController = TextEditingController(text: 'admin@hyperion.local');
  final _passwordController = TextEditingController();

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
                    if (lastError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        lastError,
                        style: TextStyle(
                          color: AppTheme.statusOffline,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildSignInButton(isLoading),
                    const SizedBox(height: 16),
                    _buildDemoLink(isLoading),
                    const SizedBox(height: 40),
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
    final notifier = AuthScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: ListenableBuilder(
            listenable: notifier,
            builder: (_, __) {
              final loading = notifier.isLoading;
              final err = notifier.lastError;
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
                    if (err != null) ...[
                      const SizedBox(height: 12),
                      Text(err, style: TextStyle(color: AppTheme.statusOffline, fontSize: 14)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: loading
                          ? null
                          : () async {
                              await notifier.register(
                                usernameController.text.trim(),
                                emailController.text.trim(),
                                passwordController.text.trim(),
                              );
                              if (sheetContext.mounted && notifier.lastError == null) {
                                Navigator.of(sheetContext).pop();
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
    ).whenComplete(() {
      usernameController.dispose();
      emailController.dispose();
      passwordController.dispose();
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
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading
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
            : const Text('Sign in'),
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
}
