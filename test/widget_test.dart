// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hyperion_flutter/auth/auth_notifier.dart';
import 'package:hyperion_flutter/auth/auth_service.dart';
import 'package:hyperion_flutter/config/api_config.dart';
import 'package:hyperion_flutter/devices/devices_service.dart';
import 'package:hyperion_flutter/main.dart';
import 'package:hyperion_flutter/plugins/plugin_settings.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<void> register(String username, String email, String password) async {}

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> signIn(String usernameOrEmail, String password) async {}

  @override
  void signInAsDemo() {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> tryRefreshSession() async => false;
}

void main() {
  testWidgets('App shows auth page when unauthenticated', (WidgetTester tester) async {
    final authNotifier = AuthNotifier(_FakeAuthService());
    final devicesService = DevicesService(
      baseUrl: ApiConfig.devicesBaseUrl,
      fallbackBaseUrl: ApiConfig.devicesFallbackUrl,
      pluginBaseUrl: ApiConfig.pluginBaseUrl,
      pluginFallbackUrl: ApiConfig.pluginFallbackUrl,
      authNotifier: authNotifier,
    );

    await tester.pumpWidget(MyApp(
      authNotifier: authNotifier,
      devicesService: devicesService,
      pluginSettings: PluginSettings(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your Account'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
