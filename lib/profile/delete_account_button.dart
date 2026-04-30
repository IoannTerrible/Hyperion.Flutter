import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';
import 'package:hyperion_flutter/profile/delete_account_controller.dart';

class DeleteAccountButton extends StatefulWidget {
  const DeleteAccountButton({super.key});

  @override
  State<DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends State<DeleteAccountButton> {
  late final DeleteAccountController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DeleteAccountController();
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

  Future<void> _requestDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.profileCard,
        title: const Text('Delete account?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Your account will be scheduled for deletion in 24 hours.\n\n'
          'You can cancel this by logging in again before the deadline.\n\n'
          'Your activity in the system will be retained in anonymised form.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.profileAccentRed),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.profileCard,
        title: const Text(
          'Are you absolutely sure?',
          style: TextStyle(color: AppTheme.profileAccentRed),
        ),
        content: const Text(
          'This action cannot be undone after 24 hours.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.profileAccentRed),
            child: const Text('Yes, delete it'),
          ),
        ],
      ),
    );
    if (doubleConfirmed != true || !mounted) return;

    try {
      final token = await AuthScope.of(context).getToken();
      if (token == null || token.isEmpty) throw Exception('No token');
      if (!mounted) return;
      await _controller.deleteAccount(
        token: token,
        signOut: () => AuthScope.of(context).signOut(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: AppTheme.profileAccentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _controller.busy ? null : _requestDelete,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.profileAccentRed,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
        ),
        child: _controller.busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.textPrimary,
                ),
              )
            : const Text('Delete account'),
      ),
    );
  }
}
