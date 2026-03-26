import 'package:clietn_server_application/plugins/plugin_settings.dart';
import 'package:flutter/widgets.dart';

/// Provides [PluginSettings] to the widget tree.
class PluginScope extends InheritedNotifier<PluginSettings> {
  const PluginScope({
    super.key,
    required PluginSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static PluginSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PluginScope>();
    assert(scope != null, 'PluginScope not found in widget tree');
    return scope!.notifier!;
  }
}
