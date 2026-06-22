import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Toggle states for Notification settings dialog
  bool _dailyReminders = true;
  bool _refillAlerts = true;
  bool _familyDigest = false;

  String _fullName = 'Jane Doe';
  int _age = 68;
  String _bloodType = 'O-';
  double _weight = 64.0;
  double _height = 162.0;
  String _email = 'jane.doe@email.com';
  int _medsCount = 0;
  bool _isLoadingProfile = true;
  String? _avatarUrl;
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _adherenceLogs = [];
  List<Map<String, dynamic>> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoadingProfile = true;
    });
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        setState(() {
          _email = user.email ?? _email;
          final metaName = user.userMetadata?['full_name'] as String?;
          if (metaName != null && metaName.trim().isNotEmpty) {
            _fullName = metaName;
          } else {
            _fullName = user.email?.split('@').first ?? _fullName;
          }
        });
      }
      
      final profile = await SupabaseService.getProfile();
      if (profile != null) {
        setState(() {
          _fullName = profile['full_name'] ?? _fullName;
          _age = profile['age'] ?? _age;
          _bloodType = profile['blood_type'] ?? _bloodType;
          _weight = (profile['weight'] as num?)?.toDouble() ?? _weight;
          _height = (profile['height'] as num?)?.toDouble() ?? _height;
          _avatarUrl = profile['avatar_url'];
        });
      }

      final meds = await SupabaseService.getMedications();
      final logs = await SupabaseService.getAdherenceLogs();
      final contacts = await SupabaseService.getEmergencyContacts();
      setState(() {
        _medications = meds;
        _adherenceLogs = logs;
        _emergencyContacts = contacts;
        _medsCount = meds.length;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  int get _adherenceRate {
    if (_adherenceLogs.isEmpty) return 0;
    final takenLogs = _adherenceLogs.where((log) => log['taken'] == true).length;
    return ((takenLogs / _adherenceLogs.length) * 100).round();
  }

  int get _dayStreak {
    if (_adherenceLogs.isEmpty) return 0;
    
    final takenDates = _adherenceLogs
        .where((log) => log['taken'] == true)
        .map((log) => log['date'] as String)
        .toSet()
        .toList();
        
    if (takenDates.isEmpty) return 0;
    
    takenDates.sort((a, b) => b.compareTo(a));
    
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
    
    if (!takenDates.contains(todayStr) && !takenDates.contains(yesterdayStr)) {
      return 0;
    }
    
    int streak = 0;
    DateTime checkDate = takenDates.contains(todayStr) ? now : yesterday;
    
    while (true) {
      final checkDateStr = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      if (takenDates.contains(checkDateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FD),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildProfileHeader(),
            if (_isLoadingProfile)
              const LinearProgressIndicator(
                backgroundColor: Color(0xFFF5F9FD),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B72D0)),
              ),
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildSettingsMenu(context),
            const SizedBox(height: 32),
            _buildSignOutButton(context),
            const SizedBox(height: 12),
            _buildDeleteAccountButton(context),
            const SizedBox(height: 100), // Safety bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF0F2B48), // Deep Blue
            Color(0xFF1E6FB3), // Royal Blue
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Settings Gear Icon top-right
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 26,
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
                _loadProfileData();
              },
            ),
          ),
          Center(
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Circular Avatar Image
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFE8F2FF),
                    backgroundImage: (_avatarUrl != null && _avatarUrl!.startsWith('data:image/'))
                        ? MemoryImage(base64Decode(_avatarUrl!.split(',').last))
                        : NetworkImage(
                            _avatarUrl ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&auto=format&fit=crop',
                          ) as ImageProvider,
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                 Text(
                  _fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Email and Age Info
                Text(
                  '$_email · Age $_age',
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      transform: Matrix4.translationValues(0, -20, 0),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatCol(
            value: _medsCount.toString(),
            label: 'Medicines',
            color: const Color(0xFF2B72D0), // Blue
          ),
          Container(
            width: 1,
            height: 32,
            color: const Color(0xFFE2E8F0),
          ),
          _buildStatCol(
            value: _adherenceLogs.isEmpty ? '0%' : '$_adherenceRate%',
            label: 'Adherence',
            color: const Color(0xFF3EC8A8), // Green
          ),
          Container(
            width: 1,
            height: 32,
            color: const Color(0xFFE2E8F0),
          ),
          _buildStatCol(
            value: _dayStreak.toString(),
            label: 'Day Streak',
            color: const Color(0xFFFB9A40), // Orange
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol({
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A9AAD),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Personal Info Item
          _buildMenuCard(
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF2B72D0),
            iconBgColor: const Color(0xFF2B72D0).withAlpha(26),
            title: 'Personal Info',
            subtitle: 'Name, age, blood type',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
              _loadProfileData();
            },
          ),
          const SizedBox(height: 16),
          // Medical History Item
          _buildMenuCard(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF3EC8A8),
            iconBgColor: const Color(0xFF3EC8A8).withAlpha(26),
            title: 'Medical History',
            subtitle: 'Conditions, allergies',
            onTap: () => _showMedicalHistoryDialog(context),
          ),
          const SizedBox(height: 16),
          // Custom Styled Emergency Contacts Card
          _buildMenuCard(
            icon: Icons.phone_outlined,
            iconColor: const Color(0xFFE57373),
            iconBgColor: const Color(0xFFE57373).withAlpha(26),
            title: 'Emergency Contacts',
            subtitle: _emergencyContacts.isEmpty ? 'No contacts added' : '${_emergencyContacts.length} contact${_emergencyContacts.length == 1 ? "" : "s"} added',
            isEmergency: true,
            onTap: () => _showEmergencyContactsDialog(context),
          ),
          const SizedBox(height: 16),
          // Notifications Item
          _buildMenuCard(
            icon: Icons.notifications_none_rounded,
            iconColor: const Color(0xFFFB9A40),
            iconBgColor: const Color(0xFFFB9A40).withAlpha(26),
            title: 'Notifications',
            subtitle: 'Reminders & alerts',
            onTap: () => _showNotificationsDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEmergency = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isEmergency ? const Color(0xFFFFF1EE) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isEmergency ? Border.all(color: const Color(0xFFFFD3C8), width: 1.5) : null,
        boxShadow: isEmergency
            ? null
            : const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isEmergency ? const Color(0xFFE57373) : const Color(0xFF0F2B48),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isEmergency ? const Color(0xFFD38B8B) : const Color(0xFF8A9AAD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isEmergency ? const Color(0xFFE57373) : const Color(0xFF8A9AAD),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: () => _confirmSignOut(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFFFF1EE),
            side: const BorderSide(color: Color(0xFFFFD3C8), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                color: Color(0xFFE57373),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: Color(0xFFE57373),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out of MediTrack?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
             ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // pop dialog
                try {
                  await SupabaseService.signOut();
                } catch (e) {
                  debugPrint('Sign out error: $e');
                }
                
                if (context.mounted) {
                  // Route to Login Page, clearing all navigations
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Successfully signed out.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57373),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }



  void _showMedicalHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final sortedLogs = List<Map<String, dynamic>>.from(_adherenceLogs);
        sortedLogs.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Color(0xFF3EC8A8),
                size: 26,
              ),
              SizedBox(width: 8),
              Text(
                'Medical History',
                style: TextStyle(
                  color: Color(0xFF0F2B48),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: sortedLogs.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3EC8A8).withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_outlined,
                          color: Color(0xFF3EC8A8),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No History Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F2B48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your history is currently empty. Doses logged as taken or missed on the Home page will automatically appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A9AAD),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedLogs.length,
                    itemBuilder: (context, index) {
                      final log = sortedLogs[index];
                      final med = _medications.firstWhere(
                        (m) => m['id'] == log['medication_id'],
                        orElse: () => <String, dynamic>{},
                      );
                      final medName = med['name'] ?? 'Deleted Medication';
                      final medTime = med['reminder_time'] ?? '8:00 AM';
                      final taken = log['taken'] == true;
                      final dateString = log['date'] as String;

                      String formattedDate = dateString;
                      try {
                        final parts = dateString.split('-');
                        if (parts.length == 3) {
                          final year = parts[0];
                          final monthInt = int.tryParse(parts[1]) ?? 1;
                          final day = int.tryParse(parts[2]) ?? 1;
                          final months = [
                            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                          ];
                          formattedDate = "${months[monthInt - 1]} $day, $year";
                        }
                      } catch (_) {}

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 0,
                        color: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: taken
                                      ? const Color(0xFF3EC8A8).withAlpha(26)
                                      : const Color(0xFFFB9A40).withAlpha(26),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  taken ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  color: taken ? const Color(0xFF3EC8A8) : const Color(0xFFFB9A40),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F2B48),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      taken ? 'Taken' : 'Missed',
                                      style: TextStyle(
                                        color: taken ? const Color(0xFF3EC8A8) : const Color(0xFFFB9A40),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0F2B48),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    medTime,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF8A9AAD),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF2B72D0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEmergencyContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.contact_phone_outlined,
                    color: Color(0xFFE57373),
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency Contacts',
                      style: const TextStyle(
                        color: Color(0xFF0F2B48),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_emergencyContacts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE57373).withAlpha(26),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone_disabled_outlined,
                                color: Color(0xFFE57373),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Contacts Added',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F2B48),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'You have not added any emergency doctor or contact numbers yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8A9AAD),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _emergencyContacts.length,
                          separatorBuilder: (context, index) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final contact = _emergencyContacts[index];
                            final id = contact['id'] as String;
                            final name = contact['name'] ?? '';
                            final relation = contact['relation'] ?? '';
                            final phone = contact['phone'] ?? '';

                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F2B48),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        relation,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF8A9AAD),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        phone,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF2B72D0),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.call_rounded, color: Color(0xFF3EC8A8), size: 22),
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  padding: EdgeInsets.zero,
                                  onPressed: () async {
                                    final Uri launchUri = Uri(
                                      scheme: 'tel',
                                      path: phone,
                                    );
                                    try {
                                      if (await canLaunchUrl(launchUri)) {
                                        await launchUrl(launchUri);
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Could not launch call to $phone'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to make a call: $e'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 22),
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  padding: EdgeInsets.zero,
                                  onPressed: () async {
                                    try {
                                      await SupabaseService.deleteEmergencyContact(id);
                                      final updated = await SupabaseService.getEmergencyContacts();
                                      setState(() {
                                        _emergencyContacts = updated;
                                      });
                                      setDialogState(() {});
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to delete: $e'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddContactDialog(context, setDialogState),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE57373),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Add Emergency Contact',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Color(0xFF2B72D0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddContactDialog(BuildContext context, StateSetter parentSetState) {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Add Emergency Contact',
                style: TextStyle(
                  color: Color(0xFF0F2B48),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Name / Doctor',
                          hintText: 'e.g. Dr. Sarah Miller',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: relationController,
                        decoration: const InputDecoration(
                          labelText: 'Relation / Specialty',
                          hintText: 'e.g. Primary Physician, Son',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter relation/specialty';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g. +1 (555) 987-6543',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a phone number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isSaving = true;
                            });
                            try {
                              await SupabaseService.addEmergencyContact(
                                name: nameController.text.trim(),
                                relation: relationController.text.trim(),
                                phone: phoneController.text.trim(),
                              );
                              final updated = await SupabaseService.getEmergencyContacts();
                              
                              setState(() {
                                _emergencyContacts = updated;
                              });
                              parentSetState(() {});
                              
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to add contact: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } finally {
                              setDialogState(() {
                                isSaving = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57373),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Notification Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Daily Reminders',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2B48), fontSize: 15),
                    ),
                    subtitle: const Text('Receive alerts when a dose is scheduled', style: TextStyle(fontSize: 12)),
                    value: _dailyReminders,
                    activeTrackColor: const Color(0xFF2B72D0),
                    onChanged: (val) {
                      setState(() => _dailyReminders = val);
                      this.setState(() {}); // sync with main
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text(
                      'Refill Alerts',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2B48), fontSize: 15),
                    ),
                    subtitle: const Text('Get notified when stocks fall below threshold', style: TextStyle(fontSize: 12)),
                    value: _refillAlerts,
                    activeTrackColor: const Color(0xFF2B72D0),
                    onChanged: (val) {
                      setState(() => _refillAlerts = val);
                      this.setState(() {});
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text(
                      'Family Digest',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2B48), fontSize: 15),
                    ),
                    subtitle: const Text('Receive weekly family tracking reports', style: TextStyle(fontSize: 12)),
                    value: _familyDigest,
                    activeTrackColor: const Color(0xFF2B72D0),
                    onChanged: (val) {
                      setState(() => _familyDigest = val);
                      this.setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: () => _confirmDeleteAccount(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFFEE2E2),
            side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Delete Account',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
                  SizedBox(width: 8),
                  Text('Delete Account'),
                ],
              ),
              content: const Text(
                'Are you sure you want to permanently delete your MediTrack account?\n\n'
                'This action cannot be undone. All your profile info, medications, and adherence logs will be permanently deleted.',
                style: TextStyle(height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });
                          try {
                            await SupabaseService.deleteAccount();
                            if (context.mounted) {
                              Navigator.of(context).pop(); // pop dialog
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const LoginPage()),
                                (route) => false,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Your account has been deleted successfully.'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Color(0xFF1F2937),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(context).pop(); // pop dialog
                              
                              final errorMsg = e.toString();
                              if (errorMsg.contains('delete_user_account') || errorMsg.contains('does not exist')) {
                                _showDeleteSetupInstructions(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete account: $e'),
                                    backgroundColor: const Color(0xFFEF4444),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Permanently Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteSetupInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Setup Required in Supabase'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To enable users to delete their own accounts and prevent sign-in until they sign up again, please run this SQL query in your Supabase SQL Editor:',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SelectableText(
                    '-- 0. Create a table for emergency contacts\n'
                    'create table if not exists public.emergency_contacts (\n'
                    '  id uuid default gen_random_uuid() primary key,\n'
                    '  user_id uuid references auth.users(id) on delete cascade not null,\n'
                    '  name text not null,\n'
                    '  relation text not null,\n'
                    '  phone text not null,\n'
                    '  created_at timestamp with time zone default timezone(\'utc\'::text, now()) not null\n'
                    ');\n\n'
                    '-- Enable Row Level Security (RLS) for emergency contacts\n'
                    'alter table public.emergency_contacts enable row level security;\n\n'
                    '-- RLS Policy for emergency contacts\n'
                    'create policy "Users can manage their own emergency contacts"\n'
                    '  on public.emergency_contacts for all\n'
                    '  to authenticated\n'
                    '  using (auth.uid() = user_id);\n\n'
                    '-- 1. Create a table to track deleted accounts by email\n'
                    'create table if not exists public.deleted_accounts (\n'
                    '  email text primary key,\n'
                    '  deleted_at timestamp with time zone default timezone(\'utc\'::text, now()) not null\n'
                    ');\n\n'
                    '-- Enable Row Level Security (RLS)\n'
                    'alter table public.deleted_accounts enable row level security;\n\n'
                    '-- Allow public read access to deleted_accounts\n'
                    'create policy "Allow public read access to deleted_accounts"\n'
                    '  on public.deleted_accounts for select\n'
                    '  to anon, authenticated\n'
                    '  using (true);\n\n'
                    '-- 2. Create or replace the delete_user_account function\n'
                    'create or replace function delete_user_account()\n'
                    'returns void as \$\$\n'
                    'declare\n'
                    '  v_user_id uuid;\n'
                    '  v_email text;\n'
                    'begin\n'
                    '  v_user_id := auth.uid();\n'
                    '  if v_user_id is null then\n'
                    '    raise exception \'Not authenticated\';\n'
                    '  end if;\n\n'
                    '  -- Fetch user email before deleting\n'
                    '  select email into v_email from auth.users where id = v_user_id;\n\n'
                    '  -- Clean up user data\n'
                    '  delete from public.adherence_logs where user_id = v_user_id;\n'
                    '  delete from public.medications where user_id = v_user_id;\n'
                    '  delete from public.emergency_contacts where user_id = v_user_id;\n'
                    '  delete from public.profiles where id = v_user_id;\n\n'
                    '  -- Add email to deleted accounts list\n'
                    '  if v_email is not null then\n'
                    '    insert into public.deleted_accounts (email)\n'
                    '    values (v_email)\n'
                    '    on conflict (email) do update\n'
                    '    set deleted_at = timezone(\'utc\'::text, now());\n'
                    '  end if;\n\n'
                    '  -- Delete auth user\n'
                    '  delete from auth.users where id = v_user_id;\n'
                    'end;\n'
                    '\$\$ language plpgsql security definer;\n\n'
                    '-- 3. Drop the signup trigger if you created it previously, to prevent Google Sign-In bypass:\n'
                    'drop trigger if exists on_auth_user_created on auth.users;\n'
                    'drop function if exists public.handle_new_user_signup();',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}


