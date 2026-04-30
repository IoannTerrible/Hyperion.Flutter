import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/auth/auth_scope.dart';
import 'package:hyperion_flutter/auth/auth_state.dart';
import 'package:hyperion_flutter/base_page.dart';
import 'package:hyperion_flutter/profile/debug_info_block.dart';
import 'package:hyperion_flutter/profile/delete_account_button.dart';
import 'package:hyperion_flutter/profile/edit_profile_block.dart';
import 'package:hyperion_flutter/profile/profile_avatar_widget.dart';
import 'package:hyperion_flutter/profile/sessions_block.dart';
import 'package:hyperion_flutter/profile/upload_logs_button.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = AuthScope.of(context);
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final state = notifier.state;
        final auth = state is Authenticated ? state : null;
        final email = auth?.email ?? '—';
        return BasePage(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                ProfileAvatar(avatarUrl: auth?.avatarUrl),
                const SizedBox(height: 16),
                Text(
                  (auth?.displayName?.trim().isNotEmpty ?? false)
                      ? auth!.displayName!.trim()
                      : email,
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
                        EditProfileBlock(email: auth.email),
                        const SizedBox(height: 16),
                      ],
                      const SessionsBlock(),
                      const SizedBox(height: 16),
                      const DebugInfoBlock(),
                      const UploadLogsButton(),
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
                              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                            ),
                          ),
                          child: const Text('Logout'),
                        ),
                      ),
                      if (auth != null && !auth.isDemo) ...[
                        const SizedBox(height: 8),
                        const DeleteAccountButton(),
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
