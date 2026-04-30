import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/devices/devices_api.dart';
import 'package:hyperion_flutter/devices/devices_scope.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';
import 'package:hyperion_flutter/profile/profile_utils.dart';
import 'package:hyperion_flutter/profile/session_item_widget.dart';
import 'package:hyperion_flutter/profile/sessions_controller.dart';
import 'package:hyperion_flutter/widgets/error_with_retry.dart';

class SessionsBlock extends StatefulWidget {
  const SessionsBlock({super.key});

  @override
  State<SessionsBlock> createState() => _SessionsBlockState();
}

class _SessionsBlockState extends State<SessionsBlock> {
  late final SessionsController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = SessionsController();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _load();
    _controller.startAutoRefresh(_load);
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

  Future<void> _load() async {
    if (!mounted) return;
    await _controller.load(() => DevicesScope.of(context).getSessions());
  }

  Future<void> _revoke(Session session) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Revoke session?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'The device "${session.name}" will be signed out.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.accentLink)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Revoke', style: TextStyle(color: AppTheme.profileAccentRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final backup = _controller.optimisticRemove(session.id);
    try {
      await DevicesScope.of(context).revokeSession(session.id);
      AppLogger.log('[SessionsBlock] Revoked session: ${session.name}');
    } catch (e) {
      AppLogger.log('[SessionsBlock] Failed to revoke session "${session.name}": $e');
      if (!mounted) return;
      _controller.restoreSessions(backup);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke: $e'),
          backgroundColor: AppTheme.snackbarErrorBackground,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final sessions = c.sessions ?? [];
    final initialLoading = c.loading && c.sessions == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: initialLoading ? null : c.toggleExpanded,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              const Text(
                'Activity sessions',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (initialLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  c.expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
            ],
          ),
        ),
        if (c.error != null) ...[
          const SizedBox(height: 8),
          ErrorWithRetry(
            message: friendlyError(c.error),
            onRetry: _load,
            compact: true,
          ),
        ] else if (c.expanded && sessions.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < sessions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            SessionItem(
              session: sessions[i],
              onRevoke: () => _revoke(sessions[i]),
            ),
          ],
        ] else if (c.expanded && sessions.isEmpty && !c.loading) ...[
          const SizedBox(height: 10),
          Text(
            'No active sessions',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ],
    );
  }
}
