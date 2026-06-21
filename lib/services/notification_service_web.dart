// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;


class NotificationService {
  static Future<bool> requestPermission() async {
    try {
      final permission = await html.Notification.requestPermission();
      return permission == 'granted';
    } catch (e) {
      return false;
    }
  }

  static void showNotification({
    required String title,
    required String body,
  }) {
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(
          title,
          body: body,
          icon: '/favicon.png', // Fallback to favicon
        );
      }
    } catch (e) {
      // Ignore notification failures in background/sandboxed modes
    }
  }
}
