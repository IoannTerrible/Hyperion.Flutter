import 'package:clietn_server_application/app_theme.dart';
import 'package:clietn_server_application/base_page.dart';
import 'package:clietn_server_application/logging/app_logger.dart';
import 'package:clietn_server_application/devices/devices_api.dart';
import 'package:clietn_server_application/devices/devices_scope.dart';
import 'package:clietn_server_application/plugins/plugin_scope.dart';
import 'package:clietn_server_application/plugins/plugin_settings.dart';
import 'package:clietn_server_application/widgets/error_with_retry.dart';
import 'package:flutter/material.dart';

IconData _pluginIcon(String? icon) {
  switch (icon) {
    case 'tv':
      return Icons.tv;
    case 'music_note':
      return Icons.music_note;
    case 'videocam':
      return Icons.videocam;
    case 'brush':
      return Icons.brush;
    case 'power_settings_new':
      return Icons.power_settings_new;
    case 'volume_up':
      return Icons.volume_up;
    case 'bug_report':
      return Icons.bug_report;
    case 'view_compact':
      return Icons.view_compact;
    default:
      return Icons.extension;
  }
}

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  Future<List<Plugin>>? _catalogFuture;

  // Local overrides for non-system plugins (not persisted).
  final Map<String, bool> _localOverrides = {};

  bool _isSystemPlugin(String id) =>
      id == kPluginDebugInfoId || id == kPluginCompactUiId;

  bool _enabled(Plugin plugin, PluginSettings settings) {
    if (plugin.id == kPluginDebugInfoId) return settings.debugInfo;
    if (plugin.id == kPluginCompactUiId) return settings.compactUi;
    return _localOverrides[plugin.id] ?? plugin.enabled;
  }

  Future<void> _toggle(Plugin plugin, bool value, PluginSettings settings) async {
    if (plugin.id == kPluginDebugInfoId) {
      await settings.setDebugInfo(value);
    } else if (plugin.id == kPluginCompactUiId) {
      await settings.setCompactUi(value);
    } else {
      setState(() => _localOverrides[plugin.id] = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = DevicesScope.of(context);
    final settings = PluginScope.of(context);
    final compact = settings.compactUi;
    _catalogFuture ??= service.getPluginCatalog();

    return BasePage(
      child: FutureBuilder<List<Plugin>>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            AppLogger.log('[PluginsPage] Error: ${snapshot.error}');
            return Center(
              child: ErrorWithRetry(
                message: snapshot.error.toString(),
                onRetry: () =>
                    setState(() => _catalogFuture = service.getPluginCatalog()),
              ),
            );
          }

          final plugins = snapshot.data ?? [];

          if (plugins.isEmpty) {
            return Center(
              child: Text(
                'No plugins available',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            );
          }

          // Split into system (Debug Info, Compact UI) and other plugins.
          final systemPlugins = plugins.where((p) => _isSystemPlugin(p.id)).toList();
          final otherPlugins = plugins.where((p) => !_isSystemPlugin(p.id)).toList();

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 20,
              compact ? 8 : 16,
              compact ? 12 : 20,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (systemPlugins.isNotEmpty) ...[
                  _SectionHeader(title: 'App Settings', compact: compact),
                  SizedBox(height: compact ? 8 : 12),
                  for (final plugin in systemPlugins) ...[
                    ListenableBuilder(
                      listenable: settings,
                      builder: (context, _) => _PluginTile(
                        icon: _pluginIcon(plugin.icon),
                        name: plugin.name,
                        enabled: _enabled(plugin, settings),
                        onChanged: (v) => _toggle(plugin, v, settings),
                        compact: compact,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 10),
                  ],
                  if (otherPlugins.isNotEmpty) SizedBox(height: compact ? 12 : 20),
                ],
                if (otherPlugins.isNotEmpty) ...[
                  _SectionHeader(title: 'Available Plugins', compact: compact),
                  SizedBox(height: compact ? 8 : 12),
                  for (final plugin in otherPlugins) ...[
                    _PluginTile(
                      icon: _pluginIcon(plugin.icon),
                      name: plugin.name,
                      enabled: _enabled(plugin, settings),
                      onChanged: (v) => _toggle(plugin, v, settings),
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 6 : 10),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool compact;

  const _SectionHeader({required this.title, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(0, compact ? 4 : 8, 0, compact ? 8 : 12),
          child: Row(
            children: [
              Icon(
                Icons.chevron_right,
                color: AppTheme.textPrimary,
                size: compact ? 22 : 28,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: compact ? 15 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: AppTheme.textSecondary.withOpacity(0.3),
          thickness: 1,
        ),
      ],
    );
  }
}

class _PluginTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool compact;

  const _PluginTile({
    required this.icon,
    required this.name,
    required this.enabled,
    required this.onChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.tilePadding(compact),
      decoration: BoxDecoration(
        color: AppTheme.pluginsItem,
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textPrimary, size: compact ? 20 : 24),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'Enabled' : 'Disabled',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _StatusSwitch(enabled: enabled, onChanged: onChanged),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: enabled
                  ? AppTheme.pluginsEnabled
                  : AppTheme.pluginsDisabledDot,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSwitch extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _StatusSwitch({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.pluginsEnabled
              : AppTheme.pluginsToggleOff,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Align(
          alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
