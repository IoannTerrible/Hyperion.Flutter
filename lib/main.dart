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

  static const _titles = ['Devices', 'Plugins', 'Profile'];
  static const List<Widget> _pages = [
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
          _titles[_currentIndex],
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: AppTheme.background,
      // Lazy IndexedStack: each tab is mounted only the first time it is
      // visited and stays alive afterwards. Tab swaps then become a pure
      // visibility toggle — no widget remount, no FutureBuilder re-fire,
      // no first-paint of BasePage's blurred falling-light. This is what
      // eliminates the 100–240ms raster spikes seen on tab switches in
      // the DevTools traces.
      body: _LazyIndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: _LiquidGlassNavBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

/// IndexedStack variant that defers building each child until the first
/// time its index is selected. Once built, a child stays in the tree so
/// its State, scroll positions, and futures survive future tab switches.
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<bool> _activated =
      List<bool>.filled(widget.children.length, false);

  @override
  void initState() {
    super.initState();
    _activated[widget.index] = true;
  }

  @override
  void didUpdateWidget(_LazyIndexedStack old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) {
      _activated[widget.index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: List<Widget>.generate(
        widget.children.length,
        (i) => _activated[i]
            ? widget.children[i]
            : const SizedBox.shrink(),
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

const double _kNavHeight = 70.0;
const double _kBubbleWidthFactor = 0.58;
const double _kBubbleHeightFactor = 0.60;

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

    late final AnimationController _ambientCtrl;
    late final Animation<double> _ambientAnim;
    late final List<AnimationController> _shimmerCtrls;
    late final List<Animation<double>> _shimmerAnim;

    static final ImageFilter _kGlassBlur =
        ImageFilter.blur(sigmaX: 22, sigmaY: 22);

    static final ImageFilter _kBubbleBlur =
        ImageFilter.blur(sigmaX: 18, sigmaY: 18);

  void _onTap(int index) {
    _shimmerCtrls[index]
      ..stop()
      ..forward(from: 0).then((_) {
        if (!mounted) return;
        _shimmerCtrls[index].reverse();
      });

    widget.onTap(index);
  }

  @override
  void initState() {
    super.initState();

    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat();

    _ambientAnim = CurvedAnimation(
      parent: _ambientCtrl,
      curve: Curves.linear,
    );

    _shimmerCtrls = List.generate(
      _kNavItems.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 140),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );

    _shimmerAnim = _shimmerCtrls
        .map(
          (c) => Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: c,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeOutQuad,
            ),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();

    for (final c in _shimmerCtrls) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusCard + 8);
    // Top-level RepaintBoundary keeps page-body repaints from also dirtying
    // the nav-bar layer. Equally important: the blur layer is a static
    // sibling at the bottom of the Stack, isolated by its own RepaintBoundary
    // — animations (bubble, scale, shimmer) on top no longer mark the
    // BackdropFilter dirty, so the gaussian blur is rasterized at most once
    // per tab swap rather than on every animation frame.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
         final tabW = constraints.maxWidth / _kNavItems.length;
          final bubbleW = tabW * _kBubbleWidthFactor;
          final bubbleH = _kNavHeight * _kBubbleHeightFactor;
          final bubbleTop = (_kNavHeight - bubbleH) / 2 - 4;
          final bubbleLeft = widget.currentIndex * tabW + (tabW - bubbleW) / 2;
          final bubbleRadius = BorderRadius.circular(bubbleH / 2);

          return SizedBox(
            height: _kNavHeight,
            child: Stack(
              children: [
                // ── Static glass layer (blur + tint + rim + shadow) ─────
                Positioned.fill(
  child: RepaintBoundary(
    child: ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: _kGlassBlur,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: AppTheme.surface.withValues(alpha: 0.24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                AppTheme.surface.withValues(alpha: 0.24),
                AppTheme.background.withValues(alpha: 0.22),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.17),
              width: 0.85,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: -10,
                offset: const Offset(0, -4),
              ),
              BoxShadow(
                color: AppTheme.background.withValues(alpha: 0.60),
                blurRadius: 28,
                spreadRadius: -8,
                offset: const Offset(0, 12),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
Positioned.fill(
  child: IgnorePointer(
    child: ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.20),
              Colors.white.withValues(alpha: 0.045),
              Colors.black.withValues(alpha: 0.12),
            ],
            stops: const [0.0, 0.44, 1.0],
          ),
        ),
      ),
    ),
  ),
),
Positioned.fill(
  child: IgnorePointer(
    child: ClipRRect(
      borderRadius: radius,
      child: AnimatedBuilder(
        animation: _ambientAnim,
        builder: (context, child) {
          return CustomPaint(
            painter: _LiquidGlassSweepPainter(
              progress: _ambientAnim.value,
              color: Colors.white,
            ),
          );
        },
      ),
    ),
  ),
),
                // ── Sliding selection bubble ───────────────────────────
               AnimatedPositioned(
  duration: const Duration(milliseconds: 410),
  curve: Curves.easeOutBack,
  left: bubbleLeft,
  top: bubbleTop,
  width: bubbleW,
  height: bubbleH,
  child: IgnorePointer(
    child: ClipRRect(
      borderRadius: bubbleRadius,
      child: BackdropFilter(
        filter: _kBubbleBlur,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: bubbleRadius,
            color: AppTheme.surfaceSelected.withValues(alpha: 0.23),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.34),
                AppTheme.surfaceSelected.withValues(alpha: 0.27),
                AppTheme.textPrimary.withValues(alpha: 0.08),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.29),
              width: 0.95,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.14),
                blurRadius: 16,
                spreadRadius: -8,
                offset: const Offset(0, -4),
              ),
              BoxShadow(
                color: AppTheme.textPrimary.withValues(alpha: 0.10),
                blurRadius: 18,
                spreadRadius: -9,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 20,
                spreadRadius: -10,
                offset: const Offset(0, 9),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
                // ── Tab items ──────────────────────────────────────────
                Row(
                  children: List.generate(_kNavItems.length, (i) {
                    final item = _kNavItems[i];
                    final selected = i == widget.currentIndex;
                    return Expanded(
                      child: RepaintBoundary(
                        child: GestureDetector(
                          onTap: () => _onTap(i),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: _kNavHeight,
                            child: Stack(
                              children: [
                                // ── Press-shimmer flash ────────────────
                                AnimatedBuilder(
                                  animation: _shimmerAnim[i],
                                  builder: (_, _) {
                                    final v = _shimmerAnim[i].value;
                                    if (v == 0) return const SizedBox.shrink();
                                    return Positioned(
                                      left: (tabW - bubbleW) / 2,
                                      top: bubbleTop,
                                      width: bubbleW,
                                      height: bubbleH,
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            (bubbleRadius),
                                           gradient: LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Colors.white.withValues(alpha: 0.46 * v),
    Colors.white.withValues(alpha: 0.13 * v),
    Colors.transparent,
  ],
  stops: const [0.0, 0.48, 1.0],
),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // ── Icon + label ───────────────────────
                                Align(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedScale(
                                        scale: selected ? 1.25 : 1.0,
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
  fontSize: selected ? 10.4 : 10,
  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
  letterSpacing: selected ? 0.05 : 0,
  color: AppTheme.textPrimary.withValues(
    alpha: selected ? 0.96 : 0.43,
  ),
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
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LiquidGlassSweepPainter extends CustomPainter {
  const _LiquidGlassSweepPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
      final sweepW = size.width * 0.42;
      final sweepH = size.height * 2.15;
      final dx = -sweepW + (size.width + sweepW * 2) * progress;

      final rect = Rect.fromCenter(
        center: Offset(dx, size.height / 2),
        width: sweepW,
        height: sweepH,
      );

    final sweepPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.00),
          color.withValues(alpha: 0.17),
          color.withValues(alpha: 0.035),
          Colors.transparent,
        ],
        stops: const [0.0, 0.27, 0.5, 0.69, 1.0],
      ).createShader(rect);

    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.5);
    canvas.rotate(-0.32);
    canvas.translate(-size.width * 0.5, -size.height * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      sweepPaint,
    );
    canvas.restore();

    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.19),
          color.withValues(alpha: 0.045),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      topPaint,
    );

    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      bottomPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassSweepPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}