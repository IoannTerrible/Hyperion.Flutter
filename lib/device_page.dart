import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/base_page.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:hyperion_flutter/devices/devices_api.dart';
import 'package:hyperion_flutter/devices/devices_scope.dart';
import 'package:hyperion_flutter/devices/devices_service.dart';
import 'package:hyperion_flutter/instance_plugins_page.dart';
import 'package:hyperion_flutter/widgets/error_with_retry.dart';
import 'package:flutter/material.dart';

String _formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

typedef _PageData = ({
  List<InstanceSummary> instances,
});

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  Future<_PageData>? _dataFuture;
  int _lastVersion = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version = DevicesScope.versionOf(context);
    if (version != _lastVersion) {
      _lastVersion = version;
      _dataFuture = null;
    }
  }

  Future<_PageData> _load(DevicesService service) async {
    return (
      instances: await service.getInstances(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = DevicesScope.of(context);
    _dataFuture ??= _load(service);
    return BasePage(
      child: FutureBuilder<_PageData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            AppLogger.log('[DevicePage] Failed to load: ${snapshot.error}');
            return Center(
              child: ErrorWithRetry(
                message: snapshot.error.toString(),
                onRetry: () => setState(() => _dataFuture = _load(service)),
              ),
            );
          }
          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () {
              setState(() => _dataFuture = _load(service));
              return _dataFuture!;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left, color: AppTheme.textPrimary, size: 28),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Devices',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  thickness: 1,
                ),
                const SizedBox(height: 14),

                // ── Hyperion instances (from PluginService) ──
                if (data.instances.isNotEmpty) ...[
                  _SectionHeader(label: 'Hyperion Instances'),
                  const SizedBox(height: 8),
                  ...data.instances.map(
                    (inst) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InstanceTile(instance: inst, service: service),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (data.instances.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.desktop_windows_outlined,
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
                              size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'No Hyperion instances found',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Launch Hyperion on a desktop or web\nbrowser to see it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.65),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}

IconData _clientTypeIcon(String? clientType) {
  switch (clientType) {
    case 'web':
      return Icons.language;
    case 'desktop':
      return Icons.desktop_windows_outlined;
    default:
      return Icons.desktop_windows_outlined;
  }
}

class _InstanceTile extends StatelessWidget {
  const _InstanceTile({required this.instance, required this.service});

  final InstanceSummary instance;
  final DevicesService service;

  String _displayName() {
    if (instance.label != null && instance.label!.isNotEmpty) {
      return instance.label!;
    }
    final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    if (uuidPattern.hasMatch(instance.instanceId)) {
      return 'Instance ${instance.instanceId.substring(0, 8).toUpperCase()}';
    }
    return instance.instanceId;
  }

  bool get _isOnline =>
      DateTime.now().difference(instance.lastUpdatedAt).inSeconds < 60;

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    return _ClientTile(
      icon: _clientTypeIcon(instance.clientType),
      name: name,
      subtitle: 'Last active ${_formatRelativeTime(instance.lastUpdatedAt)}',
      isOnline: _isOnline,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InstancePluginsPage(
            instanceId: instance.instanceId,
            instanceName: name,
            service: service,
          ),
        ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({
    required this.icon,
    required this.name,
    required this.onTap,
    this.subtitle,
    this.isOnline,
  });

  final IconData icon;
  final String name;
  final String? subtitle;
  final bool? isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.devicesCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusPluginsCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPluginsCard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusPluginsCard),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.textPrimary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isOnline != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline!
                        ? AppTheme.statusOnline
                        : AppTheme.textSecondary.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

