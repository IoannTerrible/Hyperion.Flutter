import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';

class AvatarDeleteCapsule extends StatelessWidget {
  const AvatarDeleteCapsule({
    super.key,
    required this.busy,
    required this.onAvatar,
    required this.onDelete,
  });

  final bool busy;
  final VoidCallback onAvatar;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(AppTheme.radiusButton);
    const borderColor = AppTheme.textSecondary;
    const dividerColor = Color(0x66A0A0A0);

    return Container(
      height: 46,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusButton - 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: busy ? null : onAvatar,
              borderRadius: const BorderRadius.only(topLeft: radius, bottomLeft: radius),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                child: Text(
                  'Avatar',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
              ),
            ),
            Container(width: 1, height: 22, color: dividerColor),
            InkWell(
              onTap: busy ? null : onDelete,
              borderRadius: const BorderRadius.only(topRight: radius, bottomRight: radius),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                child: Icon(Icons.delete_outline, size: 17, color: AppTheme.statusOffline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
