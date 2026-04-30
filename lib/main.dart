import 'dart:io';
import 'dart:ui';

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
        child: _LiquidGlassNavBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liquid-glass bottom navigation bar
// ---------------------------------------------------------------------------

/// Describes a single navigation destination.
class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _kNavItems = [
  _NavItem(Icons.devices,       'Devices'),
  _NavItem(Icons.cloud_circle,  'Plugins'),
  _NavItem(Icons.person_outline,'Profile'),
];

/// Fixed dimensions — keeps layout maths out of the build method.
const double _kNavHeight  = 64.0;
const double _kBubbleW    = 52.0;
const double _kBubbleH    = 34.0;
/// Vertical offset from the top of the bar to the top of the bubble.
/// Chosen so the bubble is centred on the icon row (icon 22 px + label).
const double _kBubbleTop  = 7.0;

class _LiquidGlassNavBar extends StatefulWidget {
  const _LiquidGlassNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<_LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<_LiquidGlassNavBar>
    with TickerProviderStateMixin {
  /// One short-lived controller per tab drives the press-shimmer flash.
  late final List<AnimationController> _shimmerCtrls;
  late final List<Animation<double>> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrls = List.generate(
      _kNavItems.length,
      (_) => AnimationController(
        vsync: this,
        // Total round-trip: 80 ms forward + 120 ms reverse = 200 ms.
        duration: const Duration(milliseconds: 80),
        reverseDuration: const Duration(milliseconds: 120),
      ),
    );
    _shimmerAnim = _shimmerCtrls
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _shimmerCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTap(int index) {
    // Fire shimmer: ramp up, then fade out automatically.
    _shimmerCtrls[index]
      ..stop()
      ..forward(from: 0).then((_) => _shimmerCtrls[index].reverse());
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabW      = constraints.maxWidth / _kNavItems.length;
        final bubbleLeft = widget.currentIndex * tabW + (tabW - _kBubbleW) / 2;

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: _kNavHeight,
              decoration: BoxDecoration(
                // Grey surface tint — same family as the old solid bar, but
                // translucent so the blur shows through.
                color: AppTheme.surface.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(
                  color: AppTheme.textPrimary.withValues(alpha: 0.14),
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.background.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // ── Sliding selection bubble ──────────────────────────────
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    left: bubbleLeft,
                    top: _kBubbleTop,
                    width: _kBubbleW,
                    height: _kBubbleH,
                    child: Container(
                      decoration: BoxDecoration(
                        // Subtle surfaceSelected tint — glass-on-glass, not solid.
                        color: AppTheme.surfaceSelected.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(_kBubbleH / 2),
                        border: Border.all(
                          color: AppTheme.textPrimary.withValues(alpha: 0.18),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // ── Tab items ─────────────────────────────────────────────
                  Row(
                    children: List.generate(_kNavItems.length, (i) {
                      final item     = _kNavItems[i];
                      final selected = i == widget.currentIndex;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onTap(i),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: _kNavHeight,
                            child: Stack(
                              children: [
                                // ── Press-shimmer flash ───────────────────
                                AnimatedBuilder(
                                  animation: _shimmerAnim[i],
                                  builder: (_, _) {
                                    final v = _shimmerAnim[i].value;
                                    if (v == 0) return const SizedBox.shrink();
                                    return Positioned(
                                      left: (tabW - _kBubbleW) / 2,
                                      top:  _kBubbleTop,
                                      width:  _kBubbleW,
                                      height: _kBubbleH,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                              _kBubbleH / 2),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end:   Alignment.bottomRight,
                                            colors: [
                                              AppTheme.textPrimary.withValues(
                                                  alpha: 0.38 * v),
                                              AppTheme.textPrimary.withValues(
                                                  alpha: 0.08 * v),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // ── Icon + label ──────────────────────────
                                Align(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedScale(
                                        scale: selected ? 1.10 : 1.0,
                                        duration:
                                            const Duration(milliseconds: 240),
                                        curve: Curves.easeOutBack,
                                        child: Icon(
                                          item.icon,
                                          size: 22,
                                          color: selected
                                              ? AppTheme.textPrimary
                                              : AppTheme.textPrimary
                                                  .withValues(alpha: 0.45),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedDefaultTextStyle(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: selected
                                              ? AppTheme.textPrimary
                                              : AppTheme.textPrimary
                                                  .withValues(alpha: 0.45),
                                        ),
                                        child: Text(item.label),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
