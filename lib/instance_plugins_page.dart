import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/devices/devices_api.dart';
import 'package:hyperion_flutter/devices/devices_service.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';

IconData _instancePluginIcon(String? icon) {
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

class InstancePluginsPage extends StatefulWidget {
  const InstancePluginsPage({
    super.key,
    required this.instanceId,
    required this.instanceName,
    required this.service,
  });

  final String instanceId;
  final String instanceName;
  final DevicesService service;

  @override
  State<InstancePluginsPage> createState() => _InstancePluginsPageState();
}

class _InstancePluginsPageState extends State<InstancePluginsPage> {
  late Future<List<Plugin>> _pluginsFuture;

  /// Confirmed server state overrides. Only written after a successful PATCH.
  final Map<String, bool> _overrides = {};

  /// Plugins with an in-flight PATCH request.
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _pluginsFuture = widget.service.getInstancePlugins(widget.instanceId);
  }

  bool _effectiveEnabled(Plugin p) => _overrides[p.id] ?? p.enabled;

  Future<void> _toggle(Plugin plugin, bool value) async {
    if (_pending.contains(plugin.id)) return;
    setState(() => _pending.add(plugin.id));
    try {
      await widget.service.patchPluginEnabled(
        widget.instanceId,
        plugin.id,
        value,
      );
      AppLogger.log(
        '[InstancePluginsPage] ${value ? "Enabled" : "Disabled"} "${plugin.name}" on ${widget.instanceName}',
      );
      if (!mounted) return;
      setState(() => _overrides[plugin.id] = value);
    } catch (e) {
      AppLogger.log('[InstancePluginsPage] Failed to toggle "${plugin.name}": $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update "${plugin.name}": $e'),
          backgroundColor: AppTheme.snackbarErrorBackground,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(plugin.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: Text(
          widget.instanceName,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
        ),
      ),
      body: FutureBuilder<List<Plugin>>(
        future: _pluginsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            AppLogger.log(
              '[InstancePluginsPage] Failed to load plugins for ${widget.instanceId}: ${snapshot.error}',
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _overrides.clear();
                        _pluginsFuture =
                            widget.service.getInstancePlugins(widget.instanceId);
                      }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.textSecondary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: plugins.length,
            itemBuilder: (_, i) {
              final plugin = plugins[i];
              final enabled = _effectiveEnabled(plugin);
              final isPending = _pending.contains(plugin.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PluginTile(
                  icon: _instancePluginIcon(plugin.icon),
                  name: plugin.name,
                  description: plugin.description,
                  enabled: enabled,
                  isPending: isPending,
                  onChanged: (v) => _toggle(plugin, v),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PluginTile extends StatelessWidget {
  const _PluginTile({
    required this.icon,
    required this.name,
    required this.enabled,
    required this.isPending,
    required this.onChanged,
    this.description,
  });

  final IconData icon;
  final String name;
  final String? description;
  final bool enabled;
  final bool isPending;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dotColor = isPending
        ? AppTheme.textSecondary.withValues(alpha: 0.45)
        : (enabled ? AppTheme.pluginsEnabled : AppTheme.pluginsDisabledDot);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.pluginsItem,
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textPrimary, size: 24),
          const SizedBox(width: 14),
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
                  isPending
                      ? 'Updating...'
                      : (description != null && description!.isNotEmpty
                          ? description!
                          : (enabled ? 'Enabled' : 'Disabled')),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _StatusSwitch(
            enabled: enabled,
            isPending: isPending,
            onChanged: onChanged,
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSwitch extends StatelessWidget {
  const _StatusSwitch({
    required this.enabled,
    required this.isPending,
    required this.onChanged,
  });

  final bool enabled;
  final bool isPending;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final trackColor = isPending
        ? AppTheme.textSecondary.withValues(alpha: 0.4)
        : (enabled ? AppTheme.pluginsEnabled : AppTheme.pluginsToggleOff);

    final alignment = isPending
        ? Alignment.center
        : (enabled ? Alignment.centerRight : Alignment.centerLeft);

    return GestureDetector(
      onTap: isPending ? null : () => onChanged(!enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: alignment,
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
            child: isPending
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
