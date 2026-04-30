import 'dart:io';

import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_notifier.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';
import 'package:hyperion_flutter/auth/real_auth_service.dart';
import 'package:hyperion_flutter/biometric/biometric_notifier.dart';
import 'package:hyperion_flutter/biometric/biometric_scope.dart';
import 'package:hyperion_flutter/biometric/real_biometric_service.dart';
import 'package:hyperion_flutter/config/api_config.dart';
import 'package:hyperion_flutter/device_page.dart';
import 'package:hyperion_flutter/devices/devices_service.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:hyperion_flutter/plugins/plugin_scope.dart';
import 'package:hyperion_flutter/plugins/plugin_settings.dart';
import 'package:hyperion_flutter/plugins_page.dart';
import 'package:hyperion_flutter/profile_page.dart';
import 'package:hyperion_flutter/sound/sound_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

// ---------------------------------------------------------------------------
// Hooks into the Material ink system so every InkWell / button tap plays a
// click sound. Visual splash is delegated to [_inner] unchanged.
// ---------------------------------------------------------------------------
class _SoundSplashFactory extends InteractiveInkFeatureFactory {
  const _SoundSplashFactory(this._inner);
  final InteractiveInkFeatureFactory _inner;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    SoundService.instance.playClick();
    return _inner.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}

Future<void> _initTray() async {
  if (kIsWeb) return;
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
  try {
    // Icon is resolved from the Flutter asset bundle at runtime.
    // On Windows an ICO file is preferred; PNG works on Linux/macOS.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final iconPath = '$exeDir${sep}data${sep}flutter_assets${sep}lib${sep}auth_logo.png';
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Hyperion');
    await trayManager.setContextMenu(Menu(
      items: [
        MenuItem(key: 'quit', label: 'Quit Hyperion'),
      ],
    ));
  } catch (e) {
    AppLogger.log('[Tray] init failed (non-fatal): $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  await SoundService.instance.init();
  await _initTray();

  // Load persisted plugin preferences before the first frame.
  final pluginSettings = PluginSettings();
  await pluginSettings.loadFromStorage();

  late final AuthNotifier authNotifier;
  final authService = RealAuthService(
    baseUrl: ApiConfig.authBaseUrl,
    fallbackBaseUrl: ApiConfig.authFallbackUrl,
    onStateChanged: (state) => authNotifier.replaceState(state),
  );
  authNotifier = AuthNotifier(authService);
  try {
    await authNotifier.restoreSession();
  } catch (_) {
    // Storage unavailable or keystore locked — start unauthenticated
  }
  final devicesService = DevicesService(
    baseUrl: ApiConfig.devicesBaseUrl,
    fallbackBaseUrl: ApiConfig.devicesFallbackUrl,
    pluginBaseUrl: ApiConfig.pluginBaseUrl,
    pluginFallbackUrl: ApiConfig.pluginFallbackUrl,
    authNotifier: authNotifier,
  );
  final biometricNotifier = BiometricNotifier(RealBiometricService());
  await biometricNotifier.init();
  runApp(MyApp(
    authNotifier: authNotifier,
    devicesService: devicesService,
    pluginSettings: pluginSettings,
    biometricNotifier: biometricNotifier,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authNotifier,
    required this.devicesService,
    required this.pluginSettings,
    required this.biometricNotifier,
  });

  final AuthNotifier authNotifier;
  final DevicesService devicesService;
  final PluginSettings pluginSettings;
  final BiometricNotifier biometricNotifier;

  @override
  Widget build(BuildContext context) {
    return BiometricScope(
      notifier: biometricNotifier,
      child: PluginScope(
        settings: pluginSettings,
        child: AuthScope(
          notifier: authNotifier,
          child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Hyperion',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.pinkAccent,
              brightness: Brightness.dark,
            ),
            // Dark background eliminates the white flash during route
            // push transitions and on the initial frame after auth swap.
            scaffoldBackgroundColor: AppTheme.background,
            // Play click sound on every Material button / InkWell tap.
            splashFactory: const _SoundSplashFactory(InkRipple.splashFactory),
            // Consistent transitions on all platforms; they use
            // scaffoldBackgroundColor so no white flash appears.
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: ZoomPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: ZoomPageTransitionsBuilder(),
                TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
              },
            ),
          ),
          home: AuthGate(
            authenticatedChild: MyHomePage(title: 'Home'),
            devicesService: devicesService,
          ),
        ),
      ),
    ),
  );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TrayListener {
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      trayManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'quit') exit(0);
  }

  final titles = ['Devices', 'Plugins', 'Profile'];
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
          titles[_currentIndex],
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
            unselectedItemColor: AppTheme.textPrimary.withValues(alpha:0.7),
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
