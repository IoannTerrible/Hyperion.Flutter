import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Variable Mapping from CSS
    const Color bgStart = Color(0xFFF3F4F6);
    const Color bgEnd = Color(0xFFF7C8D3);
    const Color textColor = Color(0xFF333333);
    const Color textColorSecondary = Color(0xFF757575); // Fixed opacity color
    const Color headerBg = Color(0xFF333333);
    const Color headerText = Colors.white;
    const Color accentStrong = Color(0xFFB33B63);
    const Color panelBg = Color(0xE6FFFFFF); // rgba(255, 255, 255, 0.9)
    const double panelRadius = 16.0;

    return Scaffold(
      backgroundColor: bgStart,
      appBar: AppBar(
        backgroundColor: headerBg,
        elevation: 0,
        title: const Text(
          'PROFILE',
          style: TextStyle(
            color: headerText,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
      ),
      body: Container(
        // Background Gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgStart, bgEnd],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // User Identity Section
              const CircleAvatar(
                radius: 45,
                backgroundColor: headerBg,
                child: Icon(Icons.person, size: 45, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Admin User',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'admin@hyperion.local',
                style: TextStyle(
                  color: textColorSecondary,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 40),

              // Sessions Panel
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'ACTIVE SESSIONS',
                    style: TextStyle(
                      color: accentStrong,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              // The Rounded Panel
              Container(
                decoration: BoxDecoration(
                  color: panelBg,
                  borderRadius: BorderRadius.circular(panelRadius),
                ),
                child: Column(
                  children: [
                    _buildSessionItem(
                      icon: Icons.smartphone,
                      title: 'iPhone 15 Pro',
                      subtitle: 'London, UK • Active now',
                      isLast: false,
                      accent: accentStrong,
                      text: textColor,
                      subText: textColorSecondary,
                    ),
                    _buildSessionItem(
                      icon: Icons.desktop_windows,
                      title: 'Workstation Desktop',
                      subtitle: 'Berlin, DE • 2 hours ago',
                      isLast: true,
                      accent: accentStrong,
                      text: textColor,
                      subText: textColorSecondary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Logout Button with the same Panel Radius
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: headerBg,
                    foregroundColor: headerText,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(panelRadius),
                    ),
                  ),
                  child: const Text(
                    'LOGOUT',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLast,
    required Color accent,
    required Color text,
    required Color subText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast 
          ? null 
          : Border(bottom: BorderSide(color: text.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 12, color: subText),
        ],
      ),
    );
  }
}