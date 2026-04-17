import 'package:hyperion_flutter/biometric/biometric_notifier.dart';
import 'package:flutter/material.dart';

/// Provides [BiometricNotifier] to the widget tree via [InheritedNotifier].
///
/// Place above [MaterialApp] in main.dart. Example:
/// ```dart
/// BiometricScope(
///   notifier: biometricNotifier,
///   child: MyApp(...),
/// )
/// ```
class BiometricScope extends InheritedNotifier<BiometricNotifier> {
  const BiometricScope({
    super.key,
    required BiometricNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static BiometricNotifier of(BuildContext context) {
    final n =
        context.dependOnInheritedWidgetOfExactType<BiometricScope>()?.notifier;
    assert(n != null, 'BiometricScope not found in widget tree');
    return n!;
  }

  /// Returns null when [BiometricScope] is not present in the tree.
  static BiometricNotifier? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BiometricScope>()?.notifier;
}
