import 'package:clietn_server_application/app_theme.dart';
import 'package:flutter/material.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.devicesCard,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusPluginsCard),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chevron_left,
                        color: AppTheme.textPrimary,
                        size: 28,
                      ),
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
                  color: AppTheme.textSecondary.withOpacity(0.3),
                  thickness: 1,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DeviceCard(
                        icon: Icons.smartphone_outlined,
                        name: 'iPhone 14',
                        status: DeviceStatus.online,
                        instances: const [
                          _InstanceInfo(name: 'Main Instance', status: InstanceStatus.running),
                          _InstanceInfo(name: 'Test Instance', status: InstanceStatus.stopped),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _DeviceCard(
                        icon: Icons.desktop_windows_outlined,
                        name: 'Gaming PC',
                        status: DeviceStatus.offline,
                        instances: null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

enum DeviceStatus { online, offline }

enum InstanceStatus { running, stopped }

class _InstanceInfo {
  final String name;
  final InstanceStatus status;

  const _InstanceInfo({
    required this.name,
    required this.status,
  });
}

class _DeviceCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final DeviceStatus status;
  final List<_InstanceInfo>? instances;

  const _DeviceCard({
    required this.icon,
    required this.name,
    required this.status,
    this.instances,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOnline = status == DeviceStatus.online;
    final Color statusColor =
        isOnline ? AppTheme.statusOnline : AppTheme.statusOffline;
    final String statusLabel = isOnline ? 'Online' : 'Offline';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (instances != null && instances!.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...instances!.map(
            (inst) => Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: inst.status == InstanceStatus.running
                          ? AppTheme.statusRunning
                          : AppTheme.statusStopped,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    inst.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    inst.status == InstanceStatus.running ? 'Running' : 'Stopped',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
