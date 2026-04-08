import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be top-level for background isolates.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('Notification tapped in background: ${response.payload}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String breakChannelId = 'breaks';
  static const String breakChannelName = 'Break reminders';
  static const String breakChannelDescription =
      'Reminders to take a short movement break.';

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Future<void> initialize({
    required void Function(String? payload) onTapNotification,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (resp) =>
          onTapNotification(resp.payload),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const channel = AndroidNotificationChannel(
      breakChannelId,
      breakChannelName,
      description: breakChannelDescription,
      importance: Importance.max,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
  }

  static Future<void> showBreakReminder({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool fullScreenIntent = false,
  }) async {
    final android = AndroidNotificationDetails(
      breakChannelId,
      breakChannelName,
      channelDescription: breakChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: fullScreenIntent,
      visibility: NotificationVisibility.public,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android),
      payload: payload,
    );
  }
}
