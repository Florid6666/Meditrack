import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmService {
  /// Initialise the Alarm package
  static Future<void> init() async {
    try {
      await Alarm.init();
    } catch (e) {
      debugPrint('Failed to initialize Alarm package: $e');
    }
  }

  /// Request permissions for notifications and exact alarms
  static Future<void> requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      
      // Request exact alarm permission on Android
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  /// Sync all alarms with medications list
  static Future<void> syncAlarms(
      List<Map<String, dynamic>> medications, List<Map<String, dynamic>> adherenceLogs) async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Load preferred volume level
      double? volumeLevel;
      try {
        final prefs = await SharedPreferences.getInstance();
        volumeLevel = prefs.getDouble('alarm_volume');
      } catch (_) {}

      // Get all currently scheduled alarms
      final activeAlarms = await Alarm.getAlarms();
      final currentMedIds = <int>{};

      for (final med in medications) {
        final String medId = med['id'] as String;
        final int alarmId = medId.hashCode & 0x7FFFFFFF;
        currentMedIds.add(alarmId);

        final reminderTimeStr = med['reminder_time'] as String? ?? '';
        if (reminderTimeStr.isEmpty) continue;

        // Parse reminder time (e.g. "08:00 AM")
        final parsedTime = _parseTimeOfDay(reminderTimeStr);
        if (parsedTime == null) continue;

        // Calculate scheduled DateTime for today
        var targetDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          parsedTime.hour,
          parsedTime.minute,
        );

        // Check if already taken today
        final takenToday = adherenceLogs.any((log) =>
            log['medication_id'] == medId &&
            log['date'] == todayStr &&
            log['taken'] == true);

        // If already taken today OR scheduled time has already passed today, target is tomorrow
        if (takenToday || targetDateTime.isBefore(now)) {
          targetDateTime = targetDateTime.add(const Duration(days: 1));
        }

        // Check if there is an active alarm with this ID
        final existingAlarmIndex = activeAlarms.indexWhere((a) => a.id == alarmId);
        if (existingAlarmIndex != -1) {
          final existingAlarm = activeAlarms[existingAlarmIndex];
          // If the existing alarm is a snooze alarm (i.e. scheduled for today, but at a different time than regular reminder)
          // we do NOT overwrite it!
          final isSnoozed = existingAlarm.dateTime.year == now.year &&
              existingAlarm.dateTime.month == now.month &&
              existingAlarm.dateTime.day == now.day &&
              (existingAlarm.dateTime.hour != parsedTime.hour ||
                  existingAlarm.dateTime.minute != parsedTime.minute);
          
          if (isSnoozed && existingAlarm.dateTime.isAfter(now)) {
            // Keep the snooze alarm active
            continue;
          }
        }

        // Schedule the alarm
        final alarmSettings = AlarmSettings(
          id: alarmId,
          dateTime: targetDateTime,
          assetAudioPath: 'assets/alarm.mp3',
          loopAudio: true,
          vibrate: true,
          volume: volumeLevel,
          androidFullScreenIntent: true,
          notificationSettings: NotificationSettings(
            title: 'MediTrack Medication Alert!',
            body: 'Time to take ${med['name'] ?? 'your medicine'} (${med['dosage'] ?? ''}${med['unit'] ?? ''}${med['meal_instruction'] != null ? ' · ${med['meal_instruction']}' : ''})',
            stopButton: 'Dismiss',
          ),
        );

        await Alarm.set(alarmSettings: alarmSettings);
      }

      // Stop any scheduled alarms that correspond to deleted/inactive medications
      for (final alarm in activeAlarms) {
        if (!currentMedIds.contains(alarm.id)) {
          await Alarm.stop(alarm.id);
        }
      }
    } catch (e) {
      debugPrint('Error syncing alarms: $e');
    }
  }

  /// Stop/Dismiss a specific alarm
  static Future<void> stop(int id) async {
    try {
      await Alarm.stop(id);
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  /// Snooze an alarm by rescheduling it for some minutes in the future
  static Future<void> snooze(Map<String, dynamic> med, int minutes) async {
    try {
      final String medId = med['id'] as String;
      final int alarmId = medId.hashCode & 0x7FFFFFFF;

      // Stop current alarm sound
      await Alarm.stop(alarmId);

      // Load preferred volume level
      double? volumeLevel;
      try {
        final prefs = await SharedPreferences.getInstance();
        volumeLevel = prefs.getDouble('alarm_volume');
      } catch (_) {}

      // Schedule new temporary alarm for snooze duration
      final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: snoozeTime,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volume: volumeLevel,
        androidFullScreenIntent: true,
        notificationSettings: NotificationSettings(
          title: 'MediTrack Medication Alert (Snoozed)!',
          body: 'Time to take ${med['name'] ?? 'your medicine'} (${med['dosage'] ?? ''}${med['unit'] ?? ''}${med['meal_instruction'] != null ? ' · ${med['meal_instruction']}' : ''})',
          stopButton: 'Dismiss',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
    } catch (e) {
      debugPrint('Error snoozing alarm: $e');
    }
  }

  /// Helper to parse "08:00 AM" into TimeOfDay
  static TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final cleanStr = timeStr.trim().replaceAll(RegExp(r'\s+'), ' ');
      final parts = cleanStr.split(' ');
      if (parts.length != 2) return null;
      
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;
      
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();
      
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      debugPrint('Error parsing time string $timeStr: $e');
      return null;
    }
  }
}
