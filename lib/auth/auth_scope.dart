import 'package:clietn_server_application/auth/auth_notifier.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/auth_page.dart';
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
  const AuthGate({super.key, required this.authenticatedChild});

  final Widget authenticatedChild;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthScope.of(context),
      builder: (context, _) {
        final state = AuthScope.of(context).state;
        return switch (state) {
          Unauthenticated() => const AuthPage(),
          Authenticated() => authenticatedChild,
        };
      },
    );
  }
}
