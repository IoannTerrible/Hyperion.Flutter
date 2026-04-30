import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';

class ProfileField extends StatelessWidget {
  const ProfileField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
