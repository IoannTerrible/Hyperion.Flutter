//import 'dart:nativewrappers/_internal/vm/lib/math_patch.dart';

import 'package:clietn_server_application/app_theme.dart';
import 'package:clietn_server_application/auth/auth_notifier.dart';
import 'package:clietn_server_application/auth/auth_scope.dart';
import 'package:clietn_server_application/auth/real_auth_service.dart';
import 'package:clietn_server_application/device_page.dart';
import 'package:clietn_server_application/plugins_page.dart';
import 'package:clietn_server_application/profile_page.dart';
import 'package:flutter/material.dart';

import 'dart:math';

const String _kAuthBaseUrl = 'https://localhost:7204';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final AuthNotifier authNotifier;
  final authService = RealAuthService(
    baseUrl: _kAuthBaseUrl,
    onStateChanged: (state) => authNotifier.replaceState(state),
  );
  authNotifier = AuthNotifier(authService);
  await authNotifier.restoreSession();
  runApp(MyApp(authNotifier: authNotifier));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authNotifier});

  final AuthNotifier authNotifier;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      notifier: authNotifier,
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        ),
        home: const AuthGate(authenticatedChild: MyHomePage(title: 'Home')),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
   const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;


  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;

  late final List<Widget> _pages = const [
    DevicePage(),
    PluginsPage(),
    ProfilePage(),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        title: Text(
          _currentIndex == 0
              ? 'Devices'
              : (_currentIndex == 1 ? 'Plugins' : 'Profile'),
          style: TextStyle(
            color: _currentIndex == 1
                ? AppTheme.textSecondary
                : AppTheme.textPrimary,
            fontSize: _currentIndex == 1 ? 14 : 20,
            fontWeight: _currentIndex == 1 ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: AppTheme.background,
      body: _pages[_currentIndex],
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: Colors.transparent,
            elevation: 12,
            selectedItemColor: AppTheme.textPrimary,
            unselectedItemColor: AppTheme.textPrimary.withOpacity(0.7),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.devices),
                label: 'Devices',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.cloud_circle),
                label: 'Plugins',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
