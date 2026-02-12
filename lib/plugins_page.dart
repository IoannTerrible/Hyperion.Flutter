import 'package:clietn_server_application/app_theme.dart';
import 'package:flutter/material.dart';

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  bool _netflixEnabled = true;
  bool _audioControllerEnabled = false;
  bool _touchMapperEnabled = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.pluginsCard,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusPluginsCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chevron_left,
                              color: AppTheme.textPrimary,
                              size: 28,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Main Instance',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.textSecondary.withOpacity(0.3),
                        thickness: 1,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            _PluginTile(
                              icon: Icons.tv,
                              name: 'Netflix',
                              enabled: _netflixEnabled,
                              onChanged: (v) =>
                                  setState(() => _netflixEnabled = v),
                            ),
                            const SizedBox(height: 10),
                            _PluginTile(
                              icon: Icons.volume_up,
                              name: 'Audio Controller',
                              enabled: _audioControllerEnabled,
                              onChanged: (v) =>
                                  setState(() => _audioControllerEnabled = v),
                            ),
                            const SizedBox(height: 10),
                            _PluginTile(
                              icon: Icons.touch_app,
                              name: 'Touch Mapper',
                              enabled: _touchMapperEnabled,
                              onChanged: (v) =>
                                  setState(() => _touchMapperEnabled = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _PluginTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PluginTile({
    required this.icon,
    required this.name,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.pluginsItem,
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textPrimary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'Enabled' : 'Disabled',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _StatusSwitch(enabled: enabled, onChanged: onChanged),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: enabled
                  ? AppTheme.pluginsEnabled
                  : AppTheme.pluginsDisabledDot,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSwitch extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _StatusSwitch({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.pluginsEnabled
              : AppTheme.pluginsToggleOff,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Align(
          alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
