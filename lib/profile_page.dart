import 'package:clietn_server_application/app_theme.dart';
import 'package:clietn_server_application/auth/auth_scope.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/base_page.dart';
import 'package:clietn_server_application/devices/devices_api.dart';
import 'package:clietn_server_application/devices/devices_scope.dart';
import 'package:flutter/material.dart';

IconData _sessionIcon(String? icon) {
  switch (icon) {
    case 'smartphone':
      return Icons.smartphone_outlined;
    case 'desktop':
      return Icons.desktop_windows_outlined;
    default:
      return Icons.devices_other;
  }
}

String _sessionLabel(Session s) {
  final last = s.lastSeen ?? s.lastSeenAt ?? '';
  if (last.isEmpty) return s.name;
  return '${s.name} · $last';
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthScope.of(context),
      builder: (context, _) {
        final state = AuthScope.of(context).state;
        final email = state is Authenticated ? state.email : '—';
        final sessionsFuture = DevicesScope.of(context).getSessions();
        return BasePage(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: AppTheme.profileAvatarBg,
                  child: Icon(
                    Icons.person_outline,
                    size: 48,
                    color: AppTheme.profileAvatarIcon,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.profileCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Activity sessions',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Session>>(
                        future: sessionsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                  child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))),
                            );
                          }
                          if (snapshot.hasError) {
                            debugPrint('[ProfilePage] Error: ${snapshot.error}');
                            debugPrint('[ProfilePage] StackTrace: ${snapshot.stackTrace}');
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                snapshot.error.toString(),
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13),
                              ),
                            );
                          }
                          final sessions = snapshot.data ?? [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < sessions.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _SessionItem(
                                  icon: _sessionIcon(sessions[i].icon),
                                  label: _sessionLabel(sessions[i]),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
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

class _SessionItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SessionItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.sessionItemBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
