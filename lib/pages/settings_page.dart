import 'package:flutter/material.dart';
import 'edit_profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Toggle states matching mockup initial values
  bool _pushNotifications = true;
  bool _soundAlerts = true;
  bool _lowStockAlerts = true;
  bool _largeTextMode = false;

  // Font size scaler helper to avoid deprecation warnings while providing instant feedback
  double _scale(double size) {
    return _largeTextMode ? size * 1.25 : size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF0F2B48),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: const Color(0xFF0F2B48),
            fontSize: _scale(20),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Profile'),
              _buildSectionCard([
                _buildNavigationRow(
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xFF2B72D0),
                  iconBgColor: const Color(0xFF2B72D0).withAlpha(26),
                  title: 'Edit Profile',
                  subtitle: 'Change name, age, health info, and avatar',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const EditProfilePage()),
                    );
                  },
                ),
              ]),
              _buildSectionTitle('Reminders'),
              _buildSectionCard([
                _buildSettingRow(
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFF2B72D0),
                  iconBgColor: const Color(0xFF2B72D0).withAlpha(26),
                  title: 'Push Notifications',
                  subtitle: _pushNotifications ? 'Daily reminders enabled' : 'Daily reminders disabled',
                  value: _pushNotifications,
                  onChanged: (val) {
                    setState(() {
                      _pushNotifications = val;
                    });
                  },
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                _buildSettingRow(
                  icon: Icons.volume_up_outlined,
                  iconColor: const Color(0xFF3EC8A8),
                  iconBgColor: const Color(0xFF3EC8A8).withAlpha(26),
                  title: 'Sound Alerts',
                  subtitle: 'Alarm tone for reminders',
                  value: _soundAlerts,
                  onChanged: (val) {
                    setState(() {
                      _soundAlerts = val;
                    });
                  },
                ),
              ]),
              _buildSectionTitle('Stock Alerts'),
              _buildSectionCard([
                _buildSettingRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFFFB9A40),
                  iconBgColor: const Color(0xFFFB9A40).withAlpha(26),
                  title: 'Low Stock Alerts',
                  subtitle: 'Alert when below 10 pills',
                  value: _lowStockAlerts,
                  onChanged: (val) {
                    setState(() {
                      _lowStockAlerts = val;
                    });
                  },
                ),
              ]),
              _buildSectionTitle('Accessibility'),
              _buildSectionCard([
                _buildSettingRow(
                  icon: Icons.text_fields_rounded,
                  iconColor: const Color(0xFF5C6BC0),
                  iconBgColor: const Color(0xFF5C6BC0).withAlpha(26),
                  title: 'Large Text Mode',
                  subtitle: 'Increase font size for readability',
                  value: _largeTextMode,
                  onChanged: (val) {
                    setState(() {
                      _largeTextMode = val;
                    });
                  },
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: _scale(14),
          fontWeight: FontWeight.bold,
          color: const Color(0xFF8A9AAD),
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: _scale(22)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _scale(16),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F2B48),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: _scale(12),
                    color: const Color(0xFF8A9AAD),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF2B72D0),
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: _scale(22)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: _scale(16),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F2B48),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: _scale(12),
                        color: const Color(0xFF8A9AAD),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF8A9AAD),
                size: _scale(24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
