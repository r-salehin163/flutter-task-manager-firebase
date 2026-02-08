import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings);
  }

  static Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails details = AndroidNotificationDetails(
      'task_channel', 'Task Notifications',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: details);
    await _notificationsPlugin.show(0, title, body, platformDetails);
  }
}