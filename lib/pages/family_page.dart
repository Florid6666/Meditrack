import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  List<Map<String, dynamic>> _receivedInvites = [];
  List<Map<String, dynamic>> _monitoredMembers = [];
  bool _isLoading = true;

  // Map to track reminder status (sending, sent) per member
  final Map<String, String> _reminderStates = {}; // 'memberName': 'idle' | 'sending' | 'sent'

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      // 1. Fetch pending invitations sent to us
      _receivedInvites = await SupabaseService.getReceivedInvitations();

      // 2. Fetch people we are monitoring
      final sentInvites = await SupabaseService.getSentInvitations();
      final acceptedMembers = sentInvites.where((inv) => inv['status'] == 'accepted').toList();

      final List<Map<String, dynamic>> loadedMembers = [];
      for (final member in acceptedMembers) {
        final inviteeId = member['invitee_id'] as String?;
        if (inviteeId != null) {
          final data = await SupabaseService.getMonitoredMemberData(inviteeId);
          if (data != null) {
            loadedMembers.add({
              'id': member['id'],
              'invitee_id': inviteeId,
              'relation': member['relation'],
              'email': member['invitee_email'],
              'profile': data['profile'] ?? {},
              'medications': List<Map<String, dynamic>>.from(data['medications'] ?? []),
              'adherence_logs': List<Map<String, dynamic>>.from(data['adherence_logs'] ?? []),
            });
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _monitoredMembers = loadedMembers;
        });
      }
    } catch (e) {
      debugPrint('Error loading family data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respondToInvite(String requestId, bool accept) async {
    try {
      await SupabaseService.respondToInvitation(requestId: requestId, accept: accept);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invitation accepted!' : 'Invitation declined.'),
            backgroundColor: accept ? const Color(0xFF3EC8A8) : const Color(0xFFE57373),
          ),
        );
      }
      _loadFamilyData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F9FD),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B72D0)),
          ),
        ),
      );
    }

    final hasNoData = _receivedInvites.isEmpty && _monitoredMembers.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FD),
      body: SafeArea(
        child: hasNoData
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  Expanded(child: _buildEmptyState()),
                ],
              )
            : RefreshIndicator(
                onRefresh: _loadFamilyData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      _buildGradientBanner(context),
                      _buildReceivedInvitesSection(),
                      _buildSectionTitle('Family Members'),
                      _buildFamilyMembersList(),
                      const SizedBox(height: 24),
                      _buildAddMemberLink(context),
                      const SizedBox(height: 100), // Safety bottom padding
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Family',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F2B48),
              letterSpacing: -0.5,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.person_add_rounded,
              color: Color(0xFF2B72D0),
              size: 28,
            ),
            onPressed: () => _showInviteDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF3EC8A8), // Green/Teal
            Color(0xFF2B72D0), // Royal Blue
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x262B72D0),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monitor Family Members',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invite family to track together',
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showInviteDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(51),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Invite',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
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

  Widget _buildReceivedInvitesSection() {
    if (_receivedInvites.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Family Requests'),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _receivedInvites.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final invite = _receivedInvites[index];
            final reqId = invite['id'] as String;
            final rawRelation = invite['relation'] ?? 'Family';
            final relation = rawRelation.contains('|') ? rawRelation.split('|')[0] : rawRelation;
            final profile = invite['profiles'] as Map<String, dynamic>?;
            final senderName = (profile?['full_name'] != null && (profile?['full_name'] as String).trim().isNotEmpty)
                ? profile!['full_name']
                : (profile?['email'] ?? 'Unknown Sender');

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xB2FEDBA8), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: Color(0xFFD97706), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$senderName wants to monitor your medications as: $relation',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9E5D00),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _respondToInvite(reqId, false),
                        child: const Text('Decline', style: TextStyle(color: Color(0xFFE57373), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _respondToInvite(reqId, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3EC8A8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFamilyMembersList() {
    if (_monitoredMembers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          'No family members monitored yet.',
          style: TextStyle(color: Color(0xFF8A9AAD), fontStyle: FontStyle.italic),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _monitoredMembers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final member = _monitoredMembers[index];
        return _buildFamilyMemberCard(context, member);
      },
    );
  }

  Widget _buildFamilyMemberCard(BuildContext context, Map<String, dynamic> member) {
    final rawRelation = member['relation'] ?? 'Family';
    final parts = rawRelation.contains('|') ? rawRelation.split('|') : [rawRelation];
    final relation = parts[0];
    final customName = parts.length > 1 ? parts[1] : null;

    final profile = member['profile'] ?? {};
    final email = member['email'] ?? '';
    final rawName = profile['full_name'] as String?;
    final name = (customName != null && customName.trim().isNotEmpty)
        ? customName
        : ((rawName != null && rawName.trim().isNotEmpty) ? rawName : email);
    final avatarUrl = profile['avatar_url'] ?? '';
    
    final medications = member['medications'] as List<Map<String, dynamic>>;
    final adherenceLogs = member['adherence_logs'] as List<Map<String, dynamic>>;
    
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    
    final totalDoses = medications.length;
    final takenDoses = adherenceLogs.where((l) => l['date'] == todayStr && l['taken'] == true).length;
    final missedDoses = adherenceLogs.where((l) => l['date'] == todayStr && l['taken'] == false).length;
    
    final pendingOrMissedCount = missedDoses > 0 ? missedDoses : (totalDoses - takenDoses);
    final pendingOrMissedLabel = missedDoses > 0 ? 'Missed' : 'Pending';
    final showSendReminder = missedDoses > 0;
    
    final takenLogs = adherenceLogs.where((l) => l['taken'] == true).length;
    final totalLogs = adherenceLogs.length;
    final adherenceRate = totalLogs == 0 ? 100.0 : (takenLogs / totalLogs) * 100;
    
    String status = 'On Track';
    Color statusColor = const Color(0xFF3EC8A8);
    if (missedDoses > 0) {
      status = '$missedDoses Missed';
      statusColor = const Color(0xFFFB9A40);
    }
    
    final statusBgColor = statusColor.withAlpha(26);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE8F2FF),
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : relation[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF2B72D0),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ClipOval(
                        child: Image.network(
                          avatarUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : relation[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF2B72D0),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$relation – $name',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F2B48),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Last active: Active today',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8A9AAD),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildMetricsBox(
                value: '$takenDoses/$totalDoses',
                label: 'Taken',
                bgColor: const Color(0xFF3EC8A8).withAlpha(20),
                textColor: const Color(0xFF3EC8A8),
              ),
              const SizedBox(width: 10),
              _buildMetricsBox(
                value: '$pendingOrMissedCount',
                label: pendingOrMissedLabel,
                bgColor: pendingOrMissedLabel.toLowerCase() == 'missed'
                    ? const Color(0xFFE57373).withAlpha(20)
                    : const Color(0xFFFB9A40).withAlpha(20),
                textColor: pendingOrMissedLabel.toLowerCase() == 'missed'
                    ? const Color(0xFFE57373)
                    : const Color(0xFFFB9A40),
              ),
              const SizedBox(width: 10),
              _buildMetricsBox(
                value: '${adherenceRate.round()}%',
                label: 'Rate',
                bgColor: const Color(0xFF2B72D0).withAlpha(20),
                textColor: const Color(0xFF2B72D0),
              ),
            ],
          ),

          if (showSendReminder) ...[
            const SizedBox(height: 16),
            _buildReminderButton(name, relation),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsBox({
    required String value,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A9AAD),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderButton(String memberName, String relation) {
    final state = _reminderStates[memberName] ?? 'idle';

    if (state == 'sending') {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1EE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD3C8), width: 1.5),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE57373)),
            ),
          ),
        ),
      );
    } else if (state == 'sent') {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFB3EBE0), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, color: Color(0xFF3EC8A8), size: 20),
            SizedBox(width: 8),
            Text(
              'Reminder Sent Successfully!',
              style: TextStyle(
                color: Color(0xFF3EC8A8),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () => _sendReminder(memberName, relation),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF1EE),
          side: const BorderSide(color: Color(0xFFFFD3C8), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFFE57373),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Send Reminder',
              style: TextStyle(
                color: Color(0xFFE57373),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendReminder(String memberName, String relation) {
    setState(() {
      _reminderStates[memberName] = 'sending';
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _reminderStates[memberName] = 'sent';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text('Reminder sent to $memberName ($relation)!'),
              ],
            ),
            backgroundColor: const Color(0xFFE57373),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _reminderStates[memberName] = 'idle';
            });
          }
        });
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF2B72D0).withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B72D0).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: Color(0xFF2B72D0),
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Monitored Family Members',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F2B48),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add your family members by entering their email address. Once they accept the request, their medicine intake status and compliance reports will be shown here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8A9AAD),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 220,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _showInviteDialog(context),
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: const Text(
                  'Add Family Member',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B72D0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMemberLink(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => _showInviteDialog(context),
        child: const Text(
          'Add Family Member',
          style: TextStyle(
            color: Color(0xFF2B72D0),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRelation = 'Mom';
    final relationsList = ['Mom', 'Dad', 'Spouse', 'Child', 'Grandparent', 'Other'];
    bool isInviting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Invite Family Member', style: TextStyle(color: Color(0xFF0F2B48), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter name, relationship, and email address of your family member to send them a monitoring request invite.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF8A9AAD), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text('Member Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8A9AAD))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Mom',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Relation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8A9AAD))),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRelation,
                          isExpanded: true,
                          items: relationsList.map((rel) {
                            return DropdownMenuItem(value: rel, child: Text(rel));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedRelation = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8A9AAD))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'family@example.com',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A9AAD), fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isInviting
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final customName = nameController.text.trim();
                          if (customName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a member name'), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }
                          setDialogState(() {
                            isInviting = true;
                          });
                          try {
                            await SupabaseService.sendFamilyInvitation(
                              email: email,
                              relation: '$selectedRelation|$customName',
                            );
                            if (context.mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Monitoring request sent to $email!'),
                                  backgroundColor: const Color(0xFF3EC8A8),
                                ),
                              );
                              _loadFamilyData();

                              // Prefill and open native mail app for invitation
                              final user = SupabaseService.currentUser;
                              final senderName = user?.email ?? 'A family member';
                              final Uri emailUri = Uri(
                                scheme: 'mailto',
                                path: email,
                                query: 'subject=${Uri.encodeComponent('MediTrack - Family Monitoring Invitation')}&body=${Uri.encodeComponent('Hello!\n\nI would like to monitor your medicine intake on MediTrack.\n\nPlease log into the MediTrack app, navigate to the Family page, and accept my request ($senderName) so that I can stay updated on your compliance.\n\nBest regards!')}',
                              );
                              try {
                                if (await canLaunchUrl(emailUri)) {
                                  await launchUrl(emailUri);
                                }
                              } catch (launchError) {
                                debugPrint('Could not launch email client: $launchError');
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              final errorStr = e.toString();
                              final message = (errorStr.contains('23505') || errorStr.contains('duplicate key'))
                                  ? 'An invitation has already been sent to this email address.'
                                  : 'Error: $e';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
                              );
                            }
                          } finally {
                            setDialogState(() {
                              isInviting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B72D0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: isInviting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
