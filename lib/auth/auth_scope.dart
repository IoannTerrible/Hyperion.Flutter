import 'package:hyperion_flutter/auth/auth_notifier.dart';
import 'package:hyperion_flutter/auth/auth_state.dart';
import 'package:hyperion_flutter/auth_page.dart';
import 'package:hyperion_flutter/verify_email_page.dart';
import 'package:hyperion_flutter/devices/devices_scope.dart';
import 'package:hyperion_flutter/devices/devices_service.dart';
import 'package:flutter/material.dart';

class AuthScope extends InheritedNotifier<AuthNotifier> {
  const AuthScope({
    super.key,
    required AuthNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AuthNotifier of(BuildContext context) {
    final n = context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
    assert(n != null, 'AuthScope not found');
    return n!;
  }
}

/// Shows AuthPage when unauthenticated, [authenticatedChild] when authenticated.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authenticatedChild,
    required this.devicesService,
  });

  final Widget authenticatedChild;
  final DevicesService devicesService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthScope.of(context),
      builder: (context, _) {
        final state = AuthScope.of(context).state;

        // ValueKeys ensure AnimatedSwitcher detects changes between states
        // that share the same widget type (e.g. two DevicesScope variants).
        final Widget child = switch (state) {
          Unauthenticated() => const AuthPage(key: ValueKey('auth')),
          Authenticated() when state.isDemo => DevicesScope(
              key: const ValueKey('home'),
              service: devicesService,
              child: authenticatedChild,
            ),
          Authenticated() when !state.emailVerified => VerifyEmailPage(
              key: const ValueKey('verify'),
              email: state.email,
            ),
          Authenticated() => DevicesScope(
              key: const ValueKey('home'),
              service: devicesService,
              child: authenticatedChild,
            ),
        };

        // Fade instead of an instant cut — eliminates the white flash that
        // appeared when the widget tree replaced AuthPage with MyHomePage.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: child,
        );
      },
    );
  }
}
