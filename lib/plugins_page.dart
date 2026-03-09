import 'package:clietn_server_application/app_theme.dart';
import 'package:clietn_server_application/base_page.dart';
import 'package:clietn_server_application/devices/devices_api.dart';
import 'package:clietn_server_application/devices/devices_scope.dart';
import 'package:clietn_server_application/widgets/error_with_retry.dart';
import 'package:flutter/material.dart';

IconData _pluginIcon(String? icon) {
  switch (icon) {
    case 'tv':
      return Icons.tv;
    case 'volume_up':
      return Icons.volume_up;
    case 'touch_app':
      return Icons.touch_app;
    default:
      return Icons.extension;
  }
}

class PluginsPage extends StatefulWidget {
  const PluginsPage({
    super.key,
    this.scrollToInstanceId,
    this.onScrollDone,
  });

  final String? scrollToInstanceId;
  final VoidCallback? onScrollDone;

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollContentKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, bool> _pluginOverrides = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _enabled(Plugin plugin, String instanceId) {
    final key = '${instanceId}_${plugin.id}';
    return _pluginOverrides[key] ?? plugin.enabled;
  }

  Future<void> _setEnabled(
    String instanceId,
    String pluginId,
    bool value,
  ) async {
    try {
      await DevicesScope.of(context).patchPluginEnabled(
        instanceId,
        pluginId,
        value,
      );
      final key = '${instanceId}_$pluginId';
      setState(() => _pluginOverrides[key] = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _scrollToSection(String instanceId) {
    widget.onScrollDone?.call();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final sectionKey = _sectionKeys[instanceId];
      final ctx = sectionKey?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = sectionKey?.currentContext;
        if (context == null || !context.mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  Future<List<Device>>? _devicesFuture;

  @override
  Widget build(BuildContext context) {
    final service = DevicesScope.of(context);
    _devicesFuture ??= service.getDevices();
    return BasePage(
      child: FutureBuilder<List<Device>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('[PluginsPage] Error: ${snapshot.error}');
            debugPrint('[PluginsPage] StackTrace: ${snapshot.stackTrace}');
            return Center(
              child: ErrorWithRetry(
                message: snapshot.error.toString(),
                onRetry: () =>
                    setState(() => _devicesFuture = service.getDevices()),
              ),
            );
          }
          final devices = snapshot.data ?? [];
          final instances = <Instance>[];
          for (final d in devices) {
            if (d.instances != null) instances.addAll(d.instances!);
          }
          for (final inst in instances) {
            _sectionKeys.putIfAbsent(inst.id, () => GlobalKey());
          }

          final scrollToId = widget.scrollToInstanceId;
          if (scrollToId != null && _sectionKeys.containsKey(scrollToId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToSection(scrollToId);
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    key: _scrollContentKey,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final instance in instances) ...[
                        ColoredBox(
                          key: _sectionKeys[instance.id],
                          color: Colors.transparent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chevron_left,
                                      color: AppTheme.textPrimary,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      instance.name,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 18,
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
                              const SizedBox(height: 12),
                              for (final plugin in instance.plugins) ...[
                                _PluginTile(
                                  icon: _pluginIcon(plugin.icon),
                                  name: plugin.name,
                                  enabled: _enabled(plugin, instance.id),
                                  onChanged: (v) =>
                                      _setEnabled(instance.id, plugin.id, v),
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (instance.plugins.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'No plugins',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PluginTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PluginTile({
    required this.icon,
    required this.name,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
