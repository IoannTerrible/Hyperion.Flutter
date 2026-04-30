import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:hyperion_flutter/profile/profile_utils.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: 45,
      backgroundColor: AppTheme.profileAvatarBg,
      child: ClipOval(
        child: hasUrl
            ? Image.network(
                resolveAvatarUrl(url),
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, error, _) {
                  AppLogger.log('[ProfileAvatar] Failed to load avatar: $error');
                  return const Icon(
                    Icons.person_outline,
                    size: 48,
                    color: AppTheme.profileAvatarIcon,
                  );
                },
              )
            : const Icon(
                Icons.person_outline,
                size: 48,
                color: AppTheme.profileAvatarIcon,
              ),
      ),
    );
  }
}
