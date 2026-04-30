import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';
import 'package:hyperion_flutter/auth/auth_state.dart';
import 'package:hyperion_flutter/profile/avatar_delete_capsule_widget.dart';
import 'package:hyperion_flutter/profile/edit_profile_controller.dart';
import 'package:hyperion_flutter/profile/profile_field_widget.dart';

class EditProfileBlock extends StatefulWidget {
  const EditProfileBlock({super.key, required this.email});

  final String email;

  @override
  State<EditProfileBlock> createState() => _EditProfileBlockState();
}

class _EditProfileBlockState extends State<EditProfileBlock> {
  late final EditProfileController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = EditProfileController();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final auth = AuthScope.of(context).state;
    _controller.initFromAuth(auth is Authenticated ? auth : null);
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

  Authenticated? get _auth {
    final state = AuthScope.of(context).state;
    return state is Authenticated ? state : null;
  }

  Future<String?> _token() => AuthScope.of(context).getToken();

  Future<void> _pickAndUploadAvatar() async {
    final token = await _token();
    if (token == null || token.isEmpty || !mounted) return;
    final oldAvatarUrl = _auth?.avatarUrl;
    await _controller.uploadAvatar(
      token: token,
      oldAvatarUrl: oldAvatarUrl,
      onRefresh: () => AuthScope.of(context).tryRefreshSession(),
    );
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
    if (confirmed != true || !mounted) return;
    final token = await _token();
    if (token == null || token.isEmpty || !mounted) return;
    final oldAvatarUrl = _auth?.avatarUrl;
    await _controller.deleteAvatar(
      token: token,
      oldAvatarUrl: oldAvatarUrl,
      onRefresh: () => AuthScope.of(context).tryRefreshSession(),
    );
  }

  Future<void> _saveProfile() async {
    final token = await _token();
    if (token == null || token.isEmpty || !mounted) return;
    await _controller.saveProfile(
      token: token,
      onRefresh: () => AuthScope.of(context).tryRefreshSession(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (!c.editing)
              GestureDetector(
                onTap: c.busy ? null : c.startEditing,
                child: Image.asset(
                  'lib/user_edit.png',
                  width: 22,
                  height: 22,
                  color: c.busy ? AppTheme.textSecondary : AppTheme.textPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.email,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (c.editing) ...[
          TextField(
            controller: c.displayName,
            enabled: !c.busy,
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
            controller: c.bio,
            enabled: !c.busy,
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
                  onPressed: c.busy ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.buttonPrimary,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    ),
                  ),
                  child: c.busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
              const Spacer(),
              AvatarDeleteCapsule(
                busy: c.busy,
                onAvatar: _pickAndUploadAvatar,
                onDelete: _confirmAndDeleteAvatar,
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: c.busy ? null : () => c.cancelEditing(_auth),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.statusOffline,
                    side: const BorderSide(color: AppTheme.statusOffline),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ] else ...[
          ProfileField(
            label: 'Display name',
            value: c.displayName.text.trim().isEmpty ? '—' : c.displayName.text.trim(),
          ),
          const SizedBox(height: 8),
          ProfileField(
            label: 'Bio',
            value: c.bio.text.trim().isEmpty ? '—' : c.bio.text.trim(),
          ),
        ],
        if (c.message != null) ...[
          const SizedBox(height: 8),
          Text(
            c.message!,
            style: TextStyle(
              color: c.message!.toLowerCase().contains('failed')
                  ? AppTheme.statusOffline
                  : AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
