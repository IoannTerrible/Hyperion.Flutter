import 'package:hyperion_flutter/app_theme.dart';
import 'package:flutter/material.dart';

/// Error message with Retry button in app style.
class ErrorWithRetry extends StatelessWidget {
  const ErrorWithRetry({
    super.key,
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact
          ? const EdgeInsets.symmetric(vertical: 12)
          : const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
              color: compact ? AppTheme.textSecondary : AppTheme.textPrimary,
              fontSize: compact ? 13 : 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.buttonPrimary,
                foregroundColor: AppTheme.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusButton),
                ),
              ),
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
