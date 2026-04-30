import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/devices/devices_api.dart';
import 'package:hyperion_flutter/profile/profile_utils.dart';

class SessionItem extends StatelessWidget {
  const SessionItem({super.key, required this.session, required this.onRevoke});

  final Session session;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final timeLabel = sessionCreatedLabel(session.createdAt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.sessionItemBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Row(
        children: [
          Icon(sessionIcon(session.icon), color: AppTheme.textPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                ),
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRevoke,
            icon: Icon(Icons.logout, size: 18, color: AppTheme.profileAccentRed),
            tooltip: 'Revoke session',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
