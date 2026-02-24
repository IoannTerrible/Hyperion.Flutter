import 'package:clietn_server_application/app_theme.dart';
import 'package:clietn_server_application/base_page.dart';
import 'package:clietn_server_application/devices/devices_api.dart';
import 'package:clietn_server_application/devices/devices_scope.dart';
import 'package:flutter/material.dart';

IconData _deviceIcon(String? icon) {
  switch (icon) {
    case 'smartphone':
      return Icons.smartphone_outlined;
    case 'desktop':
      return Icons.desktop_windows_outlined;
    default:
      return Icons.devices_other;
  }
}

class DevicePage extends StatefulWidget {
  const DevicePage({
    super.key,
    required this.onInstanceTap,
  });

  final void Function(String instanceId) onInstanceTap;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  @override
  Widget build(BuildContext context) {
    final service = DevicesScope.of(context);
    return BasePage(
      child: FutureBuilder<List<Device>>(
        future: service.getDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('[DevicePage] Error: ${snapshot.error}');
            debugPrint('[DevicePage] StackTrace: ${snapshot.stackTrace}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final devices = snapshot.data ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                const SizedBox(height: 14),
                ...devices.map(
                  (device) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: _DeviceCard(
                        icon: _deviceIcon(device.icon),
                        name: device.name,
                        isOnline: device.status == 'Online',
                        instances: device.instances,
                        onInstanceTap: widget.onInstanceTap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool isOnline;
  final List<Instance>? instances;
  final void Function(String instanceId) onInstanceTap;

  const _DeviceCard({
    required this.icon,
    required this.name,
    required this.isOnline,
    this.instances,
    required this.onInstanceTap,
  });

  @override
  Widget build(BuildContext context) {
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
              child: InkWell(
                onTap: () => onInstanceTap(inst.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: inst.status == 'Running'
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
                        inst.status,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
