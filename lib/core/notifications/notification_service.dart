import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../hydration/hydration_repository.dart';
import '../router/app_routes.dart';
import '../settings/office_schedule.dart';

const String hydrationActionId = 'hydration_done';
const String hydrationPayload = AppRoutes.hydrationScreen;

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
  static const int _hydrationBaseId = 700000;

  static const List<String> hydrationTitles = <String>[
    'Desk Hydration Check',
    'Water Break Before Your Next Task',
    'Refill Your Focus',
    'Hydrate to Stay Sharp',
    'Boost Your Energy with Water',
    'Take a Sip 💧',
    'Your Body Needs Water',
    'Quick Water Break',
    "Don’t Forget to Hydrate",
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
    await _configureLocalTimeZone();
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

  static Future<void> requestAndroidPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (error) {
      debugPrint('Failed to configure local timezone: $error');
    }
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
      autoCancel: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          hydrationActionId,
          actionLabel,
          showsUserInterface: true,
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

  static Future<void> rescheduleHydrationReminders({
    required OfficeSchedule schedule,
    int daysAhead = 7,
  }) async {
    await _cancelHydrationSchedules();
    if (daysAhead < 1) return;

    final now = DateTime.now();
    for (var dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
      final date = now.add(Duration(days: dayOffset));
      if (schedule.offDays.contains(date.weekday)) {
        continue;
      }

      final dayStart = DateTime(date.year, date.month, date.day);
      final firstAt = dayStart.add(
        Duration(minutes: schedule.workStartMinutes + 30),
      );
      final lastAt = dayStart.add(
        Duration(minutes: schedule.workEndMinutes - 30),
      );
      if (!firstAt.isBefore(lastAt)) {
        continue;
      }

      var slot = 0;
      var at = firstAt;
      while (slot < 6 && !at.isAfter(lastAt)) {
        if (at.isAfter(now)) {
          await _scheduleHydrationAt(id: _hydrationIdFor(date, slot), at: at);
        }
        slot++;
        at = at.add(const Duration(minutes: 75));
      }
    }
  }

  static int _hydrationIdFor(DateTime date, int slot) {
    final yy = date.year % 100;
    final dayOfYear = _dayOfYear(date);
    return _hydrationBaseId + yy * 4000 + dayOfYear * 10 + slot;
  }

  static int _dayOfYear(DateTime d) {
    final jan1 = DateTime(d.year, 1, 1);
    return d.difference(jan1).inDays + 1;
  }

  static Future<void> _scheduleHydrationAt({
    required int id,
    required DateTime at,
  }) async {
    final seed = at.millisecondsSinceEpoch + id;
    final title = hydrationTitles[seed.abs() % hydrationTitles.length];
    final body = hydrationBodies[(seed ~/ 7).abs() % hydrationBodies.length];
    final actionLabel =
        hydrationActionLabels[(seed ~/ 13).abs() %
            hydrationActionLabels.length];

    final android = AndroidNotificationDetails(
      hydrationChannelId,
      hydrationChannelName,
      channelDescription: hydrationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          hydrationActionId,
          actionLabel,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: '$body (+250 mL)',
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(android: android),
        payload: hydrationPayload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('Exact schedule failed, falling back to inexact: $error');
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: '$body (+250 mL)',
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(android: android),
        payload: hydrationPayload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> _cancelHydrationSchedules() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final req in pending) {
      if (req.payload == hydrationPayload) {
        await _plugin.cancel(id: req.id);
      }
    }
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    debugPrint(
      'handleNotificationResponse: id=${response.id}, action=${response.actionId}, payload=${response.payload}',
    );
    if (response.payload != hydrationPayload &&
        response.actionId != hydrationActionId) {
      return;
    }

    final tappedNotificationId = response.id;
    final fallbackPendingId = await _hydrationRepository
        .getPendingNotificationId();
    final idToCancel = tappedNotificationId ?? fallbackPendingId;
    if (idToCancel != null) {
      await _plugin.cancel(id: idToCancel);
    }
    // Device-specific fallback: some OEMs ignore targeted cancel for action taps.
    await _plugin.cancelAll();

    if (response.actionId != hydrationActionId) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _hydrationRepository.addHydrationEntry(timestampMillis: nowMs);
    await _hydrationRepository.clearPendingPrompt();
    if (idToCancel != null) {
      await _plugin.cancel(id: idToCancel);
    }
    await _plugin.cancelAll();
  }
}
