class NotificationService {
  static Future<bool> requestPermission() async {
    return false;
  }

  static void showNotification({
    required String title,
    required String body,
  }) {
    // Stub implementation does nothing on mobile
  }
}
