import 'dart:math' as math;
import 'dart:ui';

import 'package:hyperion_flutter/app_theme.dart';
import 'package:flutter/material.dart';

/// Base page with gradient background and no other elements. All tab pages inherit from this.
/// Справа вверху отображается «падающий» свет (градиент + размытие по спецификации из Figma).
class BasePage extends StatelessWidget {
  /// Content to display over the gradient.
  final Widget child;

  /// Gradient for the background. If null, [AppTheme.defaultPageGradient] is used.
  final Gradient? gradient;

  const BasePage({
    super.key,
    required this.child,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    // Both visual layers (gradient backdrop and rotated blurred falling
    // light) are entirely static. Wrapping each in its own RepaintBoundary
    // lets Flutter's raster cache promote them to textures after the first
    // few frames — subsequent paints (page-content updates, navbar
    // animations, etc.) just composite the cached layer instead of
    // re-running the sigma-63 gaussian blur on every paint.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient ?? AppTheme.defaultPageGradient,
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          width: AppTheme.fallingLightWidth,
          height: AppTheme.fallingLightHeight,
          child: RepaintBoundary(
            child: IgnorePointer(
              child: Transform.rotate(
                angle: AppTheme.fallingLightRotationDeg * math.pi / 180,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: AppTheme.fallingLightBlurSigma,
                    sigmaY: AppTheme.fallingLightBlurSigma,
                  ),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.fallingLightGradient,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: child,
        ),
      ],
    );
  }
}
