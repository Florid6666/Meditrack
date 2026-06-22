import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import 'add_medicine_page.dart';
import 'medicine_details_page.dart';
import 'reports_page.dart';
import 'family_page.dart';
import 'profile_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String _userName = 'Jane';
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _adherenceLogs = [];
  bool _isLoadingHome = true;
  String? _avatarUrl;
  int _pendingNotificationsCount = 0;
  List<Map<String, dynamic>> _receivedInvites = [];

  // Reminder timer
  Timer? _reminderTimer;

  String get _todayDateString => "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

  int get _takenTodayCount {
    return _adherenceLogs.where((log) => log['date'] == _todayDateString && log['taken'] == true).length;
  }

  int get _missedTodayCount {
    final missed = _medications.length - _takenTodayCount;
    return missed < 0 ? 0 : missed;
  }

  double get _adherenceRate {
    if (_adherenceLogs.isEmpty) return 100.0;
    final takenLogs = _adherenceLogs.where((log) => log['taken'] == true).length;
    return (takenLogs / _adherenceLogs.length) * 100;
  }

  String get _nameInitials {
    if (_userName.isEmpty) return 'JD';
    final parts = _userName.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  List<AdherenceDay> get _dynamicAdherenceDays {
    final now = DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final mondayUtc = todayUtc.subtract(Duration(days: now.weekday - 1));
    final daysOfWeek = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return List.generate(7, (index) {
      final date = mondayUtc.add(Duration(days: index));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final logsForDate = _adherenceLogs.where((log) => log['date'] == dateStr && log['taken'] == true);
      final completed = logsForDate.isNotEmpty;
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

      return AdherenceDay(
        day: daysOfWeek[index],
        completed: completed,
        isToday: isToday,
      );
    });
  }

  int _parseTimeToMinutes(String timeStr) {
    try {
      final cleanStr = timeStr.trim().replaceAll(RegExp(r'\s+'), ' ');
      final parts = cleanStr.split(' ');
      if (parts.length != 2) return 0;
      
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return 0;
      
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();
      
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      return hour * 60 + minute;
    } catch (e) {
      debugPrint('Error parsing time string $timeStr: $e');
      return 0;
    }
  }

  List<Map<String, dynamic>> get _missedMedications {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final todayStr = _todayDateString;
    
    return _medications.where((med) {
      final medId = med['id'] as String;
      final timeStr = med['reminder_time'] as String? ?? '';
      if (timeStr.isEmpty) return false;
      
      final medMinutes = _parseTimeToMinutes(timeStr);
      if (medMinutes >= currentMinutes) return false;
      
      final takenToday = _adherenceLogs.any((log) =>
          log['medication_id'] == medId &&
          log['date'] == todayStr &&
          log['taken'] == true);
          
      return !takenToday;
    }).toList();
  }

  void _updateMissedCount() {
    final currentCount = _receivedInvites.length + _missedMedications.length;
    if (_pendingNotificationsCount != currentCount) {
      setState(() {
        _pendingNotificationsCount = currentCount;
      });
      _triggerMobileNotifications(_receivedInvites, _missedMedications);
    }
  }

  Future<void> _triggerMobileNotifications(
      List<Map<String, dynamic>> invites, List<Map<String, dynamic>> missedMeds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final notifiedKeys = prefs.getStringList('notified_keys') ?? [];
      final newNotifiedKeys = List<String>.from(notifiedKeys);
      bool hasNew = false;
      
      final todayStr = _todayDateString;
      
      // 1. Process family invites
      for (final invite in invites) {
        final inviteId = invite['id'] as String?;
        if (inviteId == null) continue;
        
        final key = 'invite_$inviteId';
        if (!notifiedKeys.contains(key)) {
          newNotifiedKeys.add(key);
          hasNew = true;
          
          final inviterName = invite['inviter_name'] ?? 'Someone';
          final relation = invite['relation'] ?? 'family';
          
          NotificationService.showNotification(
            title: 'Family Monitoring Request',
            body: '$inviterName wants to add you as a $relation monitor.',
          );
        }
      }
      
      // 2. Process missed medications
      for (final med in missedMeds) {
        final medId = med['id'] as String?;
        if (medId == null) continue;
        
        final key = 'missed_${medId}_$todayStr';
        if (!notifiedKeys.contains(key)) {
          newNotifiedKeys.add(key);
          hasNew = true;
          
          final medName = med['name'] ?? 'medicine';
          final time = med['reminder_time'] ?? 'scheduled time';
          
          NotificationService.showNotification(
            title: 'Missed Medication Alert',
            body: 'You missed your dose of $medName scheduled for $time.',
          );
        }
      }
      
      if (hasNew) {
        await prefs.setStringList('notified_keys', newNotifiedKeys);
      }
    } catch (e) {
      debugPrint('Error triggering mobile notifications: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _startReminderTimer();
    AlarmService.requestPermissions();
    NotificationService.requestPermission();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoadingHome = true;
    });
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        }
        return;
      }

      // Check if account has been deleted (e.g. on another device/session cleanup)
      if (user.email != null) {
        final isDeleted = await SupabaseService.isAccountDeleted(user.email!);
        if (isDeleted) {
          await SupabaseService.signOut();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const LoginPage(),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This account has been deleted.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Color(0xFFEF4444),
              ),
            );
          }
          return;
        }
      }

      final profile = await SupabaseService.getProfile();
      if (profile != null) {
        setState(() {
          _userName = profile['full_name']?.split(' ').first ?? _userName;
          _avatarUrl = profile['avatar_url'];
        });
      } else {
        final fullName = user.userMetadata?['full_name'] as String?;
        setState(() {
          _userName = fullName?.split(' ').first ?? user.email?.split('@').first ?? 'User';
        });
      }
      final meds = await SupabaseService.getMedications();
      final logs = await SupabaseService.getAdherenceLogs();
      final invites = await SupabaseService.getReceivedInvitations();
      setState(() {
        _medications = meds;
        _adherenceLogs = logs;
        _receivedInvites = invites;
        _pendingNotificationsCount = invites.length + _missedMedications.length;
      });
      _triggerMobileNotifications(invites, _missedMedications);
      // Synchronize native background alarms
      AlarmService.syncAlarms(meds, logs);
    } catch (e) {
      debugPrint('Error loading home data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHome = false;
        });
      }
    }
  }

  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_medications.isEmpty) return;
      _updateMissedCount();
    });
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildStatsRow(),
              _buildSectionTitle("Today's Schedule"),
              _buildScheduleList(),
              _buildLowStockAlert(),
              _buildSectionTitle("7-Day Adherence"),
              _buildAdherenceCard(),
              const SizedBox(height: 100), // Space for bottom bar
            ],
          ),
        );
      case 1:
        return ReportsPage(
          onGoHome: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        );
      case 2:
        return const FamilyPage();
      case 3:
        return _buildNotificationsTab();
      case 4:
        return const ProfilePage();
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _buildNotificationsTab() {
    final missedMeds = _missedMedications;
    final totalCount = _receivedInvites.length + missedMeds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F2B48),
                  letterSpacing: -0.5,
                ),
              ),
              if (totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalCount New',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadHomeData,
            color: const Color(0xFF2B72D0),
            child: totalCount == 0
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildNotificationEmptyState(),
                    ),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    children: [
                      if (missedMeds.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, top: 12),
                          child: Text(
                            'Missed Medications',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFB9A40),
                            ),
                          ),
                        ),
                        ...missedMeds.map((med) {
                          final medId = med['id'] as String;
                          final name = med['name'] ?? 'Unknown Medicine';
                          final time = med['reminder_time'] ?? '8:00 AM';
                          final dosage = med['dosage'] ?? '';
                          final unit = med['unit'] ?? '';
                          final type = med['type'] ?? 'Tablet';
                          
                          bool isLogging = false;

                          return StatefulBuilder(
                            builder: (context, setCardState) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x04000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF1EE),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFFFD3C8), width: 1),
                                          ),
                                          child: const Icon(
                                            Icons.alarm_off_rounded,
                                            color: Color(0xFFE57373),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Color(0xFF0F2B48),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Scheduled for $time · $dosage $unit ($type)',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF8A9AAD),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: isLogging
                                              ? null
                                              : () async {
                                                  setCardState(() {
                                                    isLogging = true;
                                                  });
                                                  try {
                                                    await SupabaseService.logAdherence(
                                                      medicationId: medId,
                                                      date: DateTime.now(),
                                                      taken: true,
                                                    );
                                                    _loadHomeData();
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Error logging dose: $e')),
                                                      );
                                                    }
                                                    setCardState(() {
                                                      isLogging = false;
                                                    });
                                                  }
                                                },
                                          icon: isLogging
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.check_rounded, size: 16),
                                          label: const Text(
                                            'Consume Now',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3EC8A8),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }),
                      ],
                      if (_receivedInvites.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, top: 12),
                          child: Text(
                            'Family Monitoring Requests',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2B72D0),
                            ),
                          ),
                        ),
                        ...List.generate(_receivedInvites.length, (index) {
                          final invite = _receivedInvites[index];
                          final reqId = invite['id'] as String;
                          final rawRelation = invite['relation'] ?? 'Family';
                          final relation = rawRelation.contains('|') ? rawRelation.split('|')[0] : rawRelation;
                          final profile = invite['profiles'] as Map<String, dynamic>?;
                          final senderName = (profile?['full_name'] != null && (profile?['full_name'] as String).trim().isNotEmpty)
                              ? profile!['full_name']
                              : (profile?['email'] ?? 'Unknown Sender');
                          
                          bool isResponding = false;

                          return StatefulBuilder(
                            builder: (context, setCardState) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x04000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF8EE),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFFEDBA8), width: 1),
                                          ),
                                          child: const Icon(
                                            Icons.favorite_rounded,
                                            color: Color(0xFFD97706),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                senderName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Color(0xFF0F2B48),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Wants to monitor you as: $relation',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF8A9AAD),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: isResponding
                                              ? null
                                              : () async {
                                                  setCardState(() {
                                                    isResponding = true;
                                                  });
                                                  await _respondToInviteFromNotifications(reqId, false);
                                                  setState(() {
                                                    _receivedInvites.removeAt(index);
                                                    _pendingNotificationsCount = _receivedInvites.length + _missedMedications.length;
                                                  });
                                                },
                                          child: const Text(
                                            'Decline',
                                            style: TextStyle(
                                              color: Color(0xFFE57373),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton(
                                          onPressed: isResponding
                                              ? null
                                              : () async {
                                                  setCardState(() {
                                                    isResponding = true;
                                                  });
                                                  await _respondToInviteFromNotifications(reqId, true);
                                                  setState(() {
                                                    _receivedInvites.removeAt(index);
                                                    _pendingNotificationsCount = _receivedInvites.length + _missedMedications.length;
                                                  });
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3EC8A8),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: isResponding
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text(
                                                  'Accept',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHome && _medications.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F9FD),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B72D0)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FD),
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: (_currentIndex == 0)
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddMedicinePage(),
                  ),
                );
                if (result == true) {
                  _loadHomeData();
                }
              },
              backgroundColor: const Color(0xFF2B72D0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 6,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey!! $_userName',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F2B48),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You have ${_medications.length} doses today',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xD91E6FB3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Notification Bell
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF1E6FB3),
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 3;
                      });
                    },
                  ),
                  if (_pendingNotificationsCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '$_pendingNotificationsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              // User Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B72D0),
                  shape: BoxShape.circle,
                  image: _avatarUrl != null
                      ? DecorationImage(
                          image: _avatarUrl!.startsWith('data:image/')
                              ? MemoryImage(base64Decode(_avatarUrl!.split(',').last))
                              : NetworkImage(_avatarUrl!) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _avatarUrl == null
                    ? Center(
                        child: Text(
                          _nameInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Today's Doses Card (Blue)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 115,
              decoration: BoxDecoration(
                color: const Color(0xFF2B72D0),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D2B72D0),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _medications.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    "Today's Doses",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Taken Card (White)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 115,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _takenTodayCount.toString(),
                    style: const TextStyle(
                      color: Color(0xFF3EC8A8),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Taken',
                    style: TextStyle(
                      color: Color(0xFF8A9AAD),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Missed Card (White)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 115,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _missedTodayCount.toString(),
                    style: const TextStyle(
                      color: Color(0xFFFB9A40),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Missed',
                    style: TextStyle(
                      color: Color(0xFF8A9AAD),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F2B48),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_isLoadingHome) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_medications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.medication_liquid_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'No medications scheduled.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AddMedicinePage(),
                    ),
                  );
                  if (result == true) {
                    _loadHomeData();
                  }
                },
                child: const Text('Add your first medicine'),
              )
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _medications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final med = _medications[index];
        final medId = med['id'] as String;
        
        final takenToday = _adherenceLogs.any((log) =>
            log['medication_id'] == medId &&
            log['date'] == _todayDateString &&
            log['taken'] == true);

        Color color = const Color(0xFF2B72D0);
        if (med['type'] == 'Capsule') {
          color = const Color(0xFF3EC8A8);
        } else if (med['type'] == 'Liquid') {
          color = const Color(0xFFFB9A40);
        }

        return _buildMedicationCard(
          name: med['name'] ?? '',
          instructions: '${med['type']} · ${med['dosage']}${med['unit']}${med['meal_instruction'] != null ? ' · ${med['meal_instruction']}' : ''}',
          time: med['reminder_time'] ?? '8:00 AM',
          color: color,
          isTaken: takenToday,
          onToggleTaken: () async {
            try {
              await SupabaseService.logAdherence(
                medicationId: medId,
                date: DateTime.now(),
                taken: !takenToday,
              );
              _loadHomeData();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error logging dose: $e')),
              );
            }
          },
          onTap: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MedicineDetailsPage(
                  medication: med,
                  adherenceLogs: _adherenceLogs.where((log) => log['medication_id'] == medId).toList(),
                ),
              ),
            );
            if (result == true) {
              _loadHomeData();
            }
          },
        );
      },
    );
  }

  Widget _buildMedicationCard({
    required String name,
    required String instructions,
    required String time,
    required Color color,
    required bool isTaken,
    required VoidCallback onToggleTaken,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Medication Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(30, (color.r * 255).round(), (color.g * 255).round(), (color.b * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                // Medication details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F2B48),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        instructions,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A9AAD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action or Time chip (Toggles Adherence)
                GestureDetector(
                  onTap: onToggleTaken,
                  child: isTaken
                      ? Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3EC8A8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(25, (color.r * 255).round(), (color.g * 255).round(), (color.b * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLowStockAlert() {
    final lowStockMeds = _medications.where((m) {
      final stock = m['stock_count'] as int? ?? 0;
      final alert = m['refill_alert'] as int? ?? 10;
      return stock <= alert;
    }).toList();

    if (lowStockMeds.isEmpty) {
      return const SizedBox();
    }

    final med = lowStockMeds.first;
    final name = med['name'] ?? '';
    final stock = med['stock_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xB2FEDBA8),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MedicineDetailsPage(
                    medication: med,
                    adherenceLogs: _adherenceLogs.where((log) => log['medication_id'] == med['id']).toList(),
                  ),
                ),
              );
              if (result == true) {
                _loadHomeData();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 26,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Low Stock Alert',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9E5D00),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$name — only $stock pills left',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB57E2F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A9AAD),
                  ),
                ),
                Text(
                  '${_adherenceRate.round()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3EC8A8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _dynamicAdherenceDays.map((day) => _buildAdherenceDayCol(day)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceDayCol(AdherenceDay day) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: day.completed
                ? const Color(0xFF3EC8A8)
                : (day.isToday ? const Color(0xFFE8F2FF) : const Color(0xFFF1F5F9)),
            shape: BoxShape.circle,
            border: day.isToday
                ? Border.all(color: const Color(0xFF2B72D0), width: 2)
                : null,
          ),
          child: Center(
            child: day.completed
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  )
                : (day.isToday
                    ? const Icon(
                        Icons.circle_outlined,
                        color: Color(0xFF2B72D0),
                        size: 10,
                      )
                    : null),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day.day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: day.isToday ? const Color(0xFF2B72D0) : const Color(0xFF8A9AAD),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 15,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.home_rounded, 'HOME'),
              _buildBottomNavItem(1, Icons.bar_chart_rounded, 'REPORTS'),
              _buildBottomNavItem(2, Icons.people_alt_rounded, 'FAMILY'),
              _buildBottomNavItem(3, Icons.notifications_rounded, 'NOTIFS'),
              _buildBottomNavItem(4, Icons.person_rounded, 'PROFILE'),
              const SizedBox(width: 48), // Space for floating button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF2B72D0) : const Color(0xFF8A9AAD);

    Widget iconWidget = Icon(
      icon,
      color: isSelected ? const Color(0xFF2B72D0) : color,
      size: isSelected ? 20 : 22,
    );

    if (index == 3 && _pendingNotificationsCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Center(
                child: Text(
                  '$_pendingNotificationsCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        if (index == 0) {
          _loadHomeData();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: isSelected
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x1F2B72D0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconWidget,
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF2B72D0),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNotificationEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2B72D0).withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF2B72D0),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F2B48),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No new pending requests or alerts.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8A9AAD),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToInviteFromNotifications(String requestId, bool accept) async {
    try {
      await SupabaseService.respondToInvitation(requestId: requestId, accept: accept);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invitation accepted!' : 'Invitation declined.'),
            backgroundColor: accept ? const Color(0xFF3EC8A8) : const Color(0xFFE57373),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadHomeData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class AdherenceDay {
  final String day;
  final bool completed;
  final bool isToday;

  AdherenceDay({
    required this.day,
    required this.completed,
    this.isToday = false,
  });
}
