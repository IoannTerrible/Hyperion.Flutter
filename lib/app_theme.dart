import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ----- Dimensions (Figma: corner radius) -----
  static const double radiusCard = 15.0;
  static const double radiusItem = 10.0;
  static const double radiusButton = 15.0;
  static const double radiusPluginsCard = 15.0;

  // ----- Единый фон и поверхности (Hex со скрина) -----
  /// Основной фон приложения. Figma/скрин: #0D0D1B. Используется на всех страницах.
  static const Color background = Color(0xFF0D0D1B);
  /// Карточки, список, нижний бар, невыбранные табы. Figma/скрин: #6C6C73.
  static const Color surface = Color(0xFF6C6C73);
  /// Вариант поверхности (карточки/ряды при необходимости). Figma/скрин: #6B6A7C.
  static const Color surfaceVariant = Color(0xFF6B6A7C);
  /// Выбранный таб в навигации. Figma/скрин: #ACAECC.
  static const Color surfaceSelected = Color(0xFFACAECC);
  /// Фон элемента в списке (Activity sessions и др.) — светлее карточки. Figma: list item bg.
  static const Color sessionItemBackground = Color(0xFF7A7A82);
  /// Круг аватара в профиле (нейтральный серый, как на макете). Figma: avatar bg.
  static const Color profileAvatarBg = Color(0xFF8C8C94);

  // ----- Текст (общие) -----
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);

  // ----- Семантика: статусы и действия -----
  /// Online, Running, включённый тумблер. Figma: semantic/success.
  static const Color statusOnline = Color(0xFF4CAF50);
  static const Color statusRunning = Color(0xFF4CAF50);
  /// Offline. Figma: semantic/error.
  static const Color statusOffline = Color(0xFFF44336);
  /// Stopped, точка Disabled. Figma: semantic/warning.
  static const Color statusStopped = Color(0xFFFFC107);
  /// Включённое состояние плагинов (тумблер). Figma: Plugins / Enabled.
  static const Color pluginsEnabled = Color(0xFF5EEB5B);
  /// Точка статуса «Disabled» у плагинов.
  static const Color pluginsDisabledDot = Color(0xFFFFB700);
  /// Кнопка Logout. Figma: semantic/destructive.
  static const Color profileAccentRed = Color(0xFFE74C3C);
  /// Иконка внутри аватара.
  static const Color profileAvatarIcon = Color(0xFFE0E0E0);

  // ----- Обратная совместимость: все экраны используют background/surface -----
  static const Color profileBackground = background;
  static const Color profileCard = surface;
  static const Color profileSurface = surface;
  static const Color pluginsBackground = background;
  static const Color pluginsCard = surface;
  static const Color pluginsItem = surface;
  static const Color pluginsToggleOff = Color(0xFF5A5A62);
  static const Color devicesBackground = background;
  static const Color devicesCard = surface;
  static const Color darkBar = surface;

  // ----- Единый градиент фона (на базе #0D0D1B) -----
  static const LinearGradient defaultPageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D0D1B), Color(0xFF1A1A28)],
  );

  // ----- Falling light -----
  static const LinearGradient fallingLightGradient = LinearGradient(
    begin: Alignment(-0.9, -0.9),
    end: Alignment(1.0, 1.0),
    colors: [Color(0x00FFFFFF), Color(0x26FFFFFF)],
  );
  static const double fallingLightRotationDeg = -28.28;
  static const double fallingLightBlurSigma = 63.7;
  static const double fallingLightWidth = 313.0;
  static const double fallingLightHeight = 322.6;
}
