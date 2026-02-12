import 'dart:math' as math;
import 'dart:ui';

import 'package:clietn_server_application/app_theme.dart';
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient ?? AppTheme.defaultPageGradient,
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          width: AppTheme.fallingLightWidth,
          height: AppTheme.fallingLightHeight,
          child: Transform.rotate(
            angle: AppTheme.fallingLightRotationDeg * math.pi / 180,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: AppTheme.fallingLightBlurSigma,
                sigmaY: AppTheme.fallingLightBlurSigma,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.fallingLightGradient,
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
