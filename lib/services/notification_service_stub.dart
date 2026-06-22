import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _plugin.initialize(
      settings: initializationSettings,
    );
    _isInitialized = true;
  }

  static Future<bool> requestPermission() async {
    await _ensureInitialized();
    
    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    final iosImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  static void showNotification({
    required String title,
    required String body,
  }) {
    _ensureInitialized().then((_) async {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'meditrack_notifications',
        'MediTrack Notifications',
        channelDescription: 'General app notifications for refill alerts and updates',
        importance: Importance.max,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = (title.hashCode ^ body.hashCode) & 0x7FFFFFFF;
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
      );
    });
  }
}
