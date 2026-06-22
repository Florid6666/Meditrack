import 'dart:ui';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/alarm_service.dart';

class RingingPage extends StatefulWidget {
  final AlarmSettings alarmSettings;

  const RingingPage({super.key, required this.alarmSettings});

  @override
  State<RingingPage> createState() => _RingingPageState();
}

class _RingingPageState extends State<RingingPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _medication;
  bool _isLoading = true;
  bool _isActionInProgress = false;
  late AnimationController _bellAnimationController;

  @override
  void initState() {
    super.initState();
    _bellAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    
    _loadMedicationDetails();
  }

  @override
  void dispose() {
    _bellAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicationDetails() async {
    try {
      final meds = await SupabaseService.getMedications();
      final med = meds.firstWhere(
        (m) => (m['id'] as String).hashCode & 0x7FFFFFFF == widget.alarmSettings.id,
        orElse: () => {},
      );

      if (med.isEmpty) {
        // Fallback: If not found, stop the alarm and pop the screen
        await AlarmService.stop(widget.alarmSettings.id);
        if (mounted) Navigator.of(context).pop();
        return;
      }

      setState(() {
        _medication = med;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading medication for alarm: $e');
      // Graceful fallback to stop and exit if error occurs
      await AlarmService.stop(widget.alarmSettings.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _handleSkip() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    try {
      await AlarmService.stop(widget.alarmSettings.id);
      
      // Optionally log as skipped (taken = false) in database if needed,
      // but standard app behavior for skip/dismiss is just silencing/dismissing.
      await SupabaseService.logAdherence(
        medicationId: _medication!['id'],
        date: DateTime.now(),
        taken: false,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error skipping dose: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to skip: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _handleMarkAsTaken() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    try {
      await AlarmService.stop(widget.alarmSettings.id);

      // Log to database as taken
      await SupabaseService.logAdherence(
        medicationId: _medication!['id'],
        date: DateTime.now(),
        taken: true,
      );

      // Decrement stock if needed
      final currentStock = _medication!['stock_count'] as int? ?? 0;
      final dosage = (_medication!['dosage'] as num? ?? 1.0).toInt();
      final newStock = currentStock - dosage >= 0 ? currentStock - dosage : 0;
      await SupabaseService.updateMedicationStock(_medication!['id'], newStock);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error taking dose: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log dose: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _handleSnooze() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    try {
      // Snooze for 15 minutes
      await AlarmService.snooze(_medication!, 15);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarm snoozed for 15 minutes')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error snoozing: $e');
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F2B48),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final medName = _medication!['name'] ?? 'Medicine';
    final dosage = _medication!['dosage'] ?? '';
    final unit = _medication!['unit'] ?? '';
    final mealInstruction = _medication!['meal_instruction'] ?? '';
    final reminderTime = _medication!['reminder_time'] ?? '8:00 AM';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      const Color(0xFF0F2B48).withAlpha(217),
                      const Color(0xFF1E6FB3).withAlpha(217),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Content Dialog Container
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                
                // Bottom card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(77),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      // Top pill handle
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Animated Bell Icon
                      AnimatedBuilder(
                        animation: _bellAnimationController,
                        builder: (context, child) {
                          final angle = (0.2 * _bellAnimationController.value) - 0.1;
                          return Transform.rotate(
                            angle: angle,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F2FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF2B72D0),
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Title & Subtitle
                      const Text(
                        'Time to Take Medicine!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F2B48),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Scheduled for $reminderTime',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF8A9AAD),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Medicine detail card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2B72D0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medication_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    medName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F2B48),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$dosage $unit${mealInstruction.isNotEmpty ? ' · $mealInstruction' : ''}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8A9AAD),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            // Skip button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isActionInProgress ? null : _handleSkip,
                                icon: const Icon(Icons.close_rounded, size: 20),
                                label: const Text('Skip'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  foregroundColor: const Color(0xFF64748B),
                                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Take button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isActionInProgress ? null : _handleMarkAsTaken,
                                icon: const Icon(Icons.check_rounded, size: 20),
                                label: const Text('Mark as Taken'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: const Color(0xFF3EC8A8),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Snooze Button
                      TextButton(
                        onPressed: _isActionInProgress ? null : _handleSnooze,
                        child: const Text(
                          'Snooze for 15 minutes',
                          style: TextStyle(
                            color: Color(0xFF2B72D0),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
