import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../hydration/hydration_repository.dart';

const String hydrationActionId = 'hydration_done';
const String hydrationPayload = 'hydration_reminder';

// Must be top-level for background isolates.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.handleNotificationResponse(response);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final HydrationRepository _hydrationRepository = HydrationRepository();

  static const String breakChannelId = 'breaks';
  static const String breakChannelName = 'Break reminders';
  static const String breakChannelDescription =
      'Reminders to take a short movement break.';
  static const String hydrationChannelId = 'hydration';
  static const String hydrationChannelName = 'Hydration reminders';
  static const String hydrationChannelDescription =
      'Reminders to drink 250 ml of water during office hours.';

  static const List<String> hydrationTitles = <String>[
    'Desk Hydration Check',
    'Water Break Before Your Next Task',
    'Refill Your Focus',
    'Hydrate to Stay Sharp',
    'Boost Your Energy with Water',
    'Take a Sip 💧',
    'Your Body Needs Water',
    'Quick Water Break',
    'Don’t Forget to Hydrate',
    'Sip Sip Time',
  ];

  static const List<String> hydrationBodies = <String>[
    'Drink 250 mL to stay refreshed.',
    'Small sips help maintain focus.',
    'A quick water break can improve energy.',
  ];

  static const List<String> hydrationActionLabels = <String>[
    'Hydrated',
    '+250ml',
    'Cheers',
    'Done',
    'Drank It',
  ];

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Future<void> initialize({
    required void Function(String? payload) onTapNotification,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (resp) {
        handleNotificationResponse(resp);
        if (resp.actionId == null || resp.actionId!.isEmpty) {
          onTapNotification(resp.payload);
        }
      },
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
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(channel);

    const hydrationChannel = AndroidNotificationChannel(
      hydrationChannelId,
      hydrationChannelName,
      description: hydrationChannelDescription,
      importance: Importance.max,
    );
    await android?.createNotificationChannel(hydrationChannel);
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

  static Future<void> showHydrationReminder({
    required int id,
    required String title,
    required String body,
    required String actionLabel,
  }) async {
    final android = AndroidNotificationDetails(
      hydrationChannelId,
      hydrationChannelName,
      channelDescription: hydrationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          hydrationActionId,
          actionLabel,
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android),
      payload: hydrationPayload,
    );
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.actionId != hydrationActionId) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _hydrationRepository.addHydrationEntry(timestampMillis: nowMs);
    await _hydrationRepository.clearPendingPrompt();
    debugPrint('Hydration acknowledged at $nowMs');
  }
}
