import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';
import 'package:hyperion_flutter/auth/auth_state.dart';
import 'package:hyperion_flutter/devices/devices_scope.dart';
import 'package:hyperion_flutter/logging/logs_page.dart';
import 'package:hyperion_flutter/profile/upload_logs_controller.dart';

class UploadLogsButton extends StatefulWidget {
  const UploadLogsButton({super.key});

  @override
  State<UploadLogsButton> createState() => _UploadLogsButtonState();
}

class _UploadLogsButtonState extends State<UploadLogsButton> {
  late final UploadLogsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = UploadLogsController();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _onUpload() async {
    final authState = AuthScope.of(context).state;
    if (authState is! Authenticated || authState.isDemo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload logs requires real account')),
        );
      }
      return;
    }
    try {
      final service = DevicesScope.of(context);
      final ok = await _controller.uploadLogs(() => service.uploadLogs());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Logs uploaded' : 'No logs to upload'),
          backgroundColor: ok ? null : AppTheme.snackbarErrorBackground,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppTheme.snackbarErrorBackground,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploading = _controller.uploading;
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: AppTheme.textPrimary,
      side: const BorderSide(color: AppTheme.textSecondary),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: uploading ? null : _onUpload,
            icon: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined, size: 20),
            label: Text(uploading ? 'Uploading...' : 'Upload logs'),
            style: buttonStyle,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LogsPage()),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.textSecondary),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
          ),
          child: const Icon(Icons.list_alt, size: 20),
        ),
      ],
    );
  }
}
