import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';
import 'package:hyperion_flutter/auth/auth_state.dart';
import 'package:hyperion_flutter/plugins/plugin_scope.dart';

class DebugInfoBlock extends StatelessWidget {
  const DebugInfoBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = PluginScope.of(context);
    if (!settings.debugInfo) return const SizedBox.shrink();

    final auth = AuthScope.of(context).state;
    final a = auth is Authenticated ? auth : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.profileCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report_outlined, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Debug Info',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DebugRow('Device ID', a?.deviceId ?? '—'),
            _DebugRow('User ID', a?.userId ?? '—'),
            _DebugRow('App version', '2.2.1'),
            _DebugRow('Instance', a?.deviceId != null ? '${a!.deviceId}_mobile' : '—'),
          ],
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
