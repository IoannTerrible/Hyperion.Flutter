import 'dart:async';

import 'package:clietn_server_application/app_theme.dart';
import 'package:clietn_server_application/auth/auth_scope.dart';
import 'package:clietn_server_application/logging/app_logger.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/base_page.dart';
import 'package:clietn_server_application/config/api_config.dart';
import 'package:clietn_server_application/devices/devices_api.dart';
import 'package:clietn_server_application/devices/devices_scope.dart';
import 'package:clietn_server_application/users/users_api.dart' as users_api;
import 'package:clietn_server_application/plugins/plugin_scope.dart';
import 'package:clietn_server_application/plugins/plugin_settings.dart';
import 'package:clietn_server_application/widgets/error_with_retry.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

String _friendlyError(Object? e) {
  if (e == null) return 'Unknown error';
  final s = e.toString();
  if (s.contains('<!') || s.contains('<html') || s.contains('DOCTYPE')) {
    return 'Server returned an unexpected response';
  }
  const maxLen = 120;
  return s.length > maxLen ? '${s.substring(0, maxLen)}…' : s;
}

String _resolveAvatarUrl(String url) {
  if (url.startsWith('/')) {
    return '${ApiConfig.authFallbackUrl}$url';
  }
  final https = ApiConfig.authBaseUrl;
  final http = ApiConfig.authFallbackUrl;
  if (https != http && url.startsWith(https)) {
    return http + url.substring(https.length);
  }
  return url;
}

void _evictAvatarCache(String? avatarUrl) {
  final url = avatarUrl?.trim();
  if (url != null && url.isNotEmpty) {
    PaintingBinding.instance.imageCache.evict(NetworkImage(_resolveAvatarUrl(url)));
  }
}

IconData _sessionIcon(String? icon) {
  switch (icon) {
    case 'smartphone':
      return Icons.smartphone_outlined;
    case 'desktop_windows':
      return Icons.desktop_windows_outlined;
    default:
      return Icons.devices_other;
  }
}

String _sessionCreatedLabel(DateTime? createdAt) {
  if (createdAt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(createdAt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  return '${createdAt.day}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthScope.of(context),
      builder: (context, _) {
        final state = AuthScope.of(context).state;
        final auth = state is Authenticated ? state : null;
        final email = auth?.email ?? '—';
        return BasePage(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                _ProfileAvatar(avatarUrl: auth?.avatarUrl),
                const SizedBox(height: 16),
                Text(
                  (auth?.displayName?.trim().isNotEmpty ?? false) ? auth!.displayName!.trim() : email,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (auth != null && !auth.emailVerified) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Email not verified',
                    style: TextStyle(color: AppTheme.statusOffline, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.profileCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (auth != null && !auth.isDemo) ...[
                        _EditProfileBlock(email: auth.email),
                        const SizedBox(height: 16),
                      ],
                      const _SessionsBlock(),
                      const SizedBox(height: 16),
                      const _DebugInfoBlock(),
                      _UploadLogsButton(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => AuthScope.of(context).signOut(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.profileAccentRed,
                            foregroundColor: AppTheme.textPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusButton),
                            ),
                          ),
                          child: const Text('Logout'),
                        ),
                      ),
                      if (auth != null && !auth.isDemo) ...[
                        const SizedBox(height: 8),
                        _DeleteAccountButton(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.avatarUrl});

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
                _resolveAvatarUrl(url),
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, error, __) {
                  AppLogger.log('[ProfileAvatar] Failed to load avatar: $error');
                  return const Icon(Icons.person_outline, size: 48, color: AppTheme.profileAvatarIcon);
                },
              )
            : const Icon(Icons.person_outline, size: 48, color: AppTheme.profileAvatarIcon),
      ),
    );
  }
}

class _EditProfileBlock extends StatefulWidget {
  const _EditProfileBlock({required this.email});

  final String email;

  @override
  State<_EditProfileBlock> createState() => _EditProfileBlockState();
}

class _EditProfileBlockState extends State<_EditProfileBlock> {
  final _client = http.Client();
  final _picker = ImagePicker();
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  bool _busy = false;
  bool _editing = false;
  String? _msg;
  bool _initialized = false;

  @override
  void dispose() {
    _client.close();
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _syncFromAuth();
    _initialized = true;
  }

  void _syncFromAuth() {
    final auth = AuthScope.of(context).state;
    final a = auth is Authenticated ? auth : null;
    _displayName.text = a?.displayName ?? '';
    _bio.text = a?.bio ?? '';
  }

  void _startEditing() => setState(() {
        _editing = true;
        _msg = null;
      });

  void _cancelEditing() {
    _syncFromAuth();
    setState(() {
      _editing = false;
      _msg = null;
    });
  }

  Future<String?> _token() => AuthScope.of(context).getToken();

  Future<void> _saveProfile() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final token = await _token();
      if (token == null || token.isEmpty) throw Exception('No token');
      await users_api.putMyProfile(
        _client,
        ApiConfig.authBaseUrl,
        token,
        users_api.UpdateMyProfileRequest(
          displayName: _displayName.text.trim().isEmpty ? null : _displayName.text.trim(),
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        ),
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      await AuthScope.of(context).tryRefreshSession();
      if (!mounted) return;
      setState(() {
        _editing = false;
        _msg = null;
      });
    } catch (e) {
      AppLogger.log('[ProfilePage._saveProfile] Error: $e');
      if (!mounted) return;
      setState(() => _msg = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final token = await _token();
      if (token == null || token.isEmpty) throw Exception('No token');
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      AppLogger.log('[ProfilePage._pickAndUploadAvatar] Uploading: ${file.name} (${file.path})');
      final oldAvatarUrl = (AuthScope.of(context).state as Authenticated?)?.avatarUrl;
      await users_api.putMyAvatar(
        _client,
        ApiConfig.authBaseUrl,
        token,
        file,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      _evictAvatarCache(oldAvatarUrl);
      await AuthScope.of(context).tryRefreshSession();
      if (!mounted) return;
      setState(() => _msg = 'Avatar updated');
    } catch (e) {
      AppLogger.log('[ProfilePage._pickAndUploadAvatar] Error: $e');
      if (!mounted) return;
      setState(() => _msg = 'Avatar upload failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndDeleteAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete avatar', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to delete your avatar?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.statusOffline)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final token = await _token();
      if (token == null || token.isEmpty) throw Exception('No token');
      AppLogger.log('[ProfilePage._deleteAvatar] Deleting avatar');
      final oldAvatarUrl = (AuthScope.of(context).state as Authenticated?)?.avatarUrl;
      await users_api.deleteMyAvatar(
        _client,
        ApiConfig.authBaseUrl,
        token,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      _evictAvatarCache(oldAvatarUrl);
      await AuthScope.of(context).tryRefreshSession();
      if (!mounted) return;
      setState(() => _msg = 'Avatar deleted');
    } catch (e) {
      AppLogger.log('[ProfilePage._deleteAvatar] Error: $e');
      if (!mounted) return;
      setState(() => _msg = 'Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Profile',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (!_editing)
              GestureDetector(
                onTap: _busy ? null : _startEditing,
                child: Image.asset(
                  'lib/user_edit.png',
                  width: 22,
                  height: 22,
                  color: _busy ? AppTheme.textSecondary : AppTheme.textPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(widget.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        if (_editing) ...[
          TextField(
            controller: _displayName,
            enabled: !_busy,
            style: const TextStyle(color: AppTheme.inputText, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Display name',
              hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha: 0.7)),
              filled: true,
              fillColor: AppTheme.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                borderSide: const BorderSide(color: AppTheme.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                borderSide: const BorderSide(color: AppTheme.inputBorder),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bio,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: AppTheme.inputText, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Bio',
              hintStyle: TextStyle(color: AppTheme.inputText.withValues(alpha: 0.7)),
              filled: true,
              fillColor: AppTheme.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                borderSide: const BorderSide(color: AppTheme.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                borderSide: const BorderSide(color: AppTheme.inputBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.buttonPrimary,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                  ),
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ),
              const Spacer(),
              _AvatarDeleteCapsule(
                busy: _busy,
                onAvatar: _pickAndUploadAvatar,
                onDelete: _confirmAndDeleteAvatar,
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _busy ? null : _cancelEditing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.statusOffline,
                    side: const BorderSide(color: AppTheme.statusOffline),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ] else ...[
          _ProfileField(
            label: 'Display name',
            value: _displayName.text.trim().isEmpty ? '—' : _displayName.text.trim(),
          ),
          const SizedBox(height: 8),
          _ProfileField(
            label: 'Bio',
            value: _bio.text.trim().isEmpty ? '—' : _bio.text.trim(),
          ),
        ],
        if (_msg != null) ...[
          const SizedBox(height: 8),
          Text(
            _msg!,
            style: TextStyle(
              color: _msg!.toLowerCase().contains('failed') ? AppTheme.statusOffline : AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _AvatarDeleteCapsule extends StatelessWidget {
  const _AvatarDeleteCapsule({
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

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

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

class _SessionsBlock extends StatefulWidget {
  const _SessionsBlock();

  @override
  State<_SessionsBlock> createState() => _SessionsBlockState();
}

class _SessionsBlockState extends State<_SessionsBlock> {
  Future<List<Session>>? _sessionsFuture;
  bool _expanded = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _sessionsFuture = DevicesScope.of(context).getSessions());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = DevicesScope.of(context);
    _sessionsFuture ??= service.getSessions();
    return FutureBuilder<List<Session>>(
      future: _sessionsFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final sessions = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () => setState(() => _expanded = !_expanded),
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
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.textSecondary,
                      size: 22,
                    ),
                ],
              ),
            ),
            if (snapshot.hasError) ...[
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                AppLogger.log('[ProfilePage] Sessions error: ${snapshot.error}');
                return ErrorWithRetry(
                  message: _friendlyError(snapshot.error),
                  onRetry: () => setState(() => _sessionsFuture = service.getSessions()),
                  compact: true,
                );
              }),
            ] else if (_expanded && sessions.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < sessions.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _SessionItem(
                  session: sessions[i],
                  onRevoke: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: const Text('Revoke session?', style: TextStyle(color: AppTheme.textPrimary)),
                        content: Text(
                          'The device "${sessions[i].name}" will be signed out.',
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
                    if (confirmed != true || !context.mounted) return;
                    try {
                      await service.revokeSession(sessions[i].id);
                      setState(() => _sessionsFuture = service.getSessions());
                    } catch (e) {
                      AppLogger.log('[ProfilePage] revokeSession error: $e');
                    }
                  },
                ),
              ],
            ] else if (_expanded && sessions.isEmpty && !isLoading) ...[
              const SizedBox(height: 10),
              Text('No active sessions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ],
          ],
        );
      },
    );
  }
}

class _UploadLogsButton extends StatefulWidget {
  const _UploadLogsButton();

  @override
  State<_UploadLogsButton> createState() => _UploadLogsButtonState();
}

class _UploadLogsButtonState extends State<_UploadLogsButton> {
  bool _uploading = false;

  Future<void> _onUpload(BuildContext context) async {
    final authState = AuthScope.of(context).state;
    if (authState is! Authenticated || authState.isDemo) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload logs requires real account')),
        );
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      final service = DevicesScope.of(context);
      final ok = await service.uploadLogs();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Logs uploaded' : 'No logs to upload'),
          backgroundColor: ok ? null : AppTheme.snackbarErrorBackground,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppTheme.snackbarErrorBackground,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _uploading ? null : () => _onUpload(context),
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file_outlined, size: 20),
        label: Text(_uploading ? 'Uploading...' : 'Upload logs'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: AppTheme.textSecondary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
        ),
      ),
    );
  }
}

class _SessionItem extends StatelessWidget {
  final Session session;
  final VoidCallback onRevoke;

  const _SessionItem({required this.session, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final timeLabel = _sessionCreatedLabel(session.createdAt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.sessionItemBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Row(
        children: [
          Icon(_sessionIcon(session.icon), color: AppTheme.textPrimary, size: 22),
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

class _DeleteAccountButton extends StatefulWidget {
  @override
  State<_DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends State<_DeleteAccountButton> {
  bool _busy = false;
  final _client = http.Client();

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

    // Second confirmation
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.profileCard,
        title: const Text('Are you absolutely sure?', style: TextStyle(color: AppTheme.profileAccentRed)),
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

    setState(() => _busy = true);
    try {
      final token = await AuthScope.of(context).getToken();
      if (token == null || token.isEmpty) throw Exception('No token');
      await users_api.deleteMyAccount(
        _client,
        ApiConfig.authBaseUrl,
        token,
        fallbackBaseUrl: ApiConfig.authFallbackUrl,
      );
      AppLogger.log('[ProfilePage] Account deletion scheduled');
      if (!mounted) return;
      await AuthScope.of(context).signOut();
    } catch (e) {
      AppLogger.log('[ProfilePage] deleteMyAccount error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: AppTheme.profileAccentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : _requestDelete,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.profileAccentRed,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
        ),
        child: _busy
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

class _DebugInfoBlock extends StatelessWidget {
  const _DebugInfoBlock();

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
          color: AppTheme.profileCard.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report_outlined, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('Debug Info', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            _DebugRow('Device ID', a?.deviceId ?? '—'),
            _DebugRow('User ID', a?.userId ?? '—'),
            _DebugRow('App version', '1.0.0'),
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
            child: Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
