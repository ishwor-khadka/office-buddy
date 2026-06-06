import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../breaks/break_state_repository.dart';
import '../hydration/hydration_repository.dart';
import '../router/app_routes.dart';
import '../settings/office_schedule.dart';

// Hydration action IDs
const String hydrationActionId = 'hydration_done';
const String hydrationSnoozeActionId = 'hydration_snooze_15';
const String hydrationSkipDayActionId = 'hydration_skip_day';
const String hydrationPayload = AppRoutes.hydrationScreen;

// Break action IDs
const String breakSnoozeActionId = 'break_snooze_10';
const String breakDoneActionId = 'break_done';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.handleNotificationResponse(response);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final HydrationRepository _hydrationRepository = HydrationRepository();
  static final BreakStateRepository _breakStateRepository =
      BreakStateRepository();

  static const String breakChannelId = 'breaks';
  static const String breakChannelName = 'Break reminders';
  static const String breakChannelDescription =
      'Reminders to take a short movement break.';
  static const String hydrationChannelId = 'hydration';
  static const String hydrationChannelName = 'Hydration reminders';
  static const String hydrationChannelDescription =
      'Reminders to drink 250 ml of water during office hours.';
  static const String _hydrationGroupKey = 'com.officeBuddy.hydration';
  static const String _breakGroupKey = 'com.officeBuddy.breaks';
  static const String _notificationIcon = 'ic_notification';

  static const int _hydrationBaseId = 700000;
  // Snooze pair uses fixed IDs just below baseId (even=main, odd=follow-up).
  static const int _hydrationSnoozeBaseId = 699998;
  static const int _hydrationFollowUpDelayMinutes = 5;

  // Time-of-day hydration titles
  static const List<String> _hydrationMorningTitles = <String>[
    'Good Morning — Time to Hydrate',
    'Start Strong with Water',
    'Morning Hydration Check',
    'Fuel Your Focus — Drink Water',
    'Rise and Sip',
  ];

  static const List<String> _hydrationMidmorningTitles = <String>[
    'Mid-Morning Water Break',
    'Refill Your Focus',
    'Stay Sharp — Sip Water',
    'Hydrate to Keep Going',
    'Water Break Before Your Next Task',
  ];

  static const List<String> _hydrationAfternoonTitles = <String>[
    'Afternoon Hydration Check',
    'Beat the Afternoon Slump — Drink Water',
    'Boost Your Energy with Water',
    'Quick Water Break',
    'Stay Refreshed This Afternoon',
  ];

  static const List<String> _hydrationLateAfternoonTitles = <String>[
    'Almost Done — Stay Hydrated',
    'Late Afternoon Sip',
    'Wrap Up the Day Well — Drink Water',
    'One More Water Break',
    "Don't Forget to Hydrate",
  ];

  static const List<String> hydrationBodies = <String>[
    'Drink 250 mL to stay refreshed.',
    'Small sips help maintain focus.',
    'A quick water break improves energy.',
  ];

  static const List<String> hydrationActionLabels = <String>[
    'Hydrated',
    '+250 ml',
    'Cheers',
    'Done',
    'Drank It',
  ];

  // Keep for backward compat with break_background.dart
  static List<String> get hydrationTitles => [
        ..._hydrationMorningTitles,
        ..._hydrationMidmorningTitles,
        ..._hydrationAfternoonTitles,
        ..._hydrationLateAfternoonTitles,
      ];

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Future<void> initialize({
    required void Function(String? payload) onTapNotification,
  }) async {
    await _configureLocalTimeZone();

    const androidInit =
        AndroidInitializationSettings(_notificationIcon);
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

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

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      breakChannelId,
      breakChannelName,
      description: breakChannelDescription,
      importance: Importance.high,
    ));

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      hydrationChannelId,
      hydrationChannelName,
      description: hydrationChannelDescription,
      importance: Importance.defaultImportance,
    ));
  }

  static Future<void> requestAndroidPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> requestIosPermissions() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
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

  /// Returns a stable, day-unique break notification ID.
  static int breakNotificationId() {
    final now = DateTime.now();
    return 100000 + (now.year % 100) * 400 + _dayOfYear(now);
  }

  static Future<void> showBreakReminder({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool isEscalated = false,
  }) async {
    final android = AndroidNotificationDetails(
      breakChannelId,
      breakChannelName,
      channelDescription: breakChannelDescription,
      importance: isEscalated ? Importance.high : Importance.defaultImportance,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      groupKey: _breakGroupKey,
      icon: _notificationIcon,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          breakSnoozeActionId,
          'Snooze 10m',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          breakDoneActionId,
          'Done',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final darwin = DarwinNotificationDetails(
      categoryIdentifier: 'break',
      interruptionLevel: isEscalated
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: darwin),
      payload: payload,
    );
  }

  static Future<void> _scheduleOneHydrationNotification({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required String actionLabel,
  }) async {
    final android = AndroidNotificationDetails(
      hydrationChannelId,
      hydrationChannelName,
      channelDescription: hydrationChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      groupKey: _hydrationGroupKey,
      icon: _notificationIcon,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          hydrationActionId,
          actionLabel,
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          hydrationSnoozeActionId,
          'Snooze 15m',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          hydrationSkipDayActionId,
          'Skip today',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    const darwin = DarwinNotificationDetails(categoryIdentifier: 'hydration');
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(android: android, iOS: darwin),
        payload: hydrationPayload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(android: android, iOS: darwin),
        payload: hydrationPayload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
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
      if (schedule.offDays.contains(date.weekday)) continue;

      final dayStart = DateTime(date.year, date.month, date.day);
      final firstAt = dayStart.add(
        Duration(minutes: schedule.workStartMinutes + 30),
      );
      final lastAt = dayStart.add(
        Duration(minutes: schedule.workEndMinutes - 30),
      );
      if (!firstAt.isBefore(lastAt)) continue;

      var slot = 0;
      var at = firstAt;
      while (slot < 6 && !at.isAfter(lastAt)) {
        final atMinutes = at.hour * 60 + at.minute;
        final inLunch = schedule.isLunchTime(atMinutes);
        if (!inLunch && at.isAfter(now)) {
          await _scheduleHydrationAt(
            id: _hydrationMainIdFor(date, slot),
            at: at,
            hour: at.hour,
          );
        }
        slot++;
        at = at.add(const Duration(minutes: 75));
      }
    }
  }

  /// Checks if the scheduled hydration tail is running thin and reschedules.
  static Future<void> rearmIfNeeded({required OfficeSchedule schedule}) async {
    final pending = await _plugin.pendingNotificationRequests();
    final hydrationCount =
        pending.where((r) => r.payload == hydrationPayload).length;
    // Rearm when fewer than 6 future slots remain (less than ~1 day's worth).
    if (hydrationCount < 12) {
      await rescheduleHydrationReminders(schedule: schedule, daysAhead: 7);
    }
  }

  // Even ID = main notification; odd ID = follow-up (main + 1).
  static int _hydrationMainIdFor(DateTime date, int slot) {
    final yy = date.year % 100;
    final dayOfYear = _dayOfYear(date);
    return _hydrationBaseId + yy * 8000 + dayOfYear * 20 + slot * 2;
  }

  static int _dayOfYear(DateTime d) {
    final jan1 = DateTime(d.year, 1, 1);
    return d.difference(jan1).inDays + 1;
  }

  static String _pickHydrationTitle(int hour, int seed) {
    final List<String> pool;
    if (hour < 11) {
      pool = _hydrationMorningTitles;
    } else if (hour < 13) {
      pool = _hydrationMidmorningTitles;
    } else if (hour < 16) {
      pool = _hydrationAfternoonTitles;
    } else {
      pool = _hydrationLateAfternoonTitles;
    }
    return pool[seed.abs() % pool.length];
  }

  // id must be even (main); follow-up is automatically scheduled at id+1.
  static Future<void> _scheduleHydrationAt({
    required int id,
    required DateTime at,
    required int hour,
  }) async {
    final seed = at.millisecondsSinceEpoch + id;
    final title = _pickHydrationTitle(hour, seed);
    final body = hydrationBodies[(seed ~/ 7).abs() % hydrationBodies.length];
    final actionLabel =
        hydrationActionLabels[(seed ~/ 13).abs() % hydrationActionLabels.length];
    final bodyText = '$body (+250 mL)';

    await _scheduleOneHydrationNotification(
      id: id,
      title: title,
      body: bodyText,
      at: at,
      actionLabel: actionLabel,
    );
    await _scheduleOneHydrationNotification(
      id: id + 1,
      title: title,
      body: bodyText,
      at: at.add(const Duration(minutes: _hydrationFollowUpDelayMinutes)),
      actionLabel: actionLabel,
    );
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

    final id = response.id;
    final actionId = response.actionId;
    final payload = response.payload;

    // ---- Hydration notifications ----
    final isHydrationPayload = payload == hydrationPayload;
    final isHydrationAction = actionId == hydrationActionId ||
        actionId == hydrationSnoozeActionId ||
        actionId == hydrationSkipDayActionId;

    if (isHydrationPayload || isHydrationAction) {
      if (id != null) {
        await _plugin.cancel(id: id);
        // Cancel the paired notification: even=main cancels odd=follow-up, vice versa.
        final pairedId = id.isEven ? id + 1 : id - 1;
        await _plugin.cancel(id: pairedId);
      }

      if (actionId == hydrationActionId) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await _hydrationRepository.addHydrationEntry(timestampMillis: nowMs);
      } else if (actionId == hydrationSnoozeActionId) {
        final snoozeAt = DateTime.now().add(const Duration(minutes: 15));
        await _scheduleHydrationAt(
          id: _hydrationSnoozeBaseId,
          at: snoozeAt,
          hour: snoozeAt.hour,
        );
      } else if (actionId == hydrationSkipDayActionId) {
        await _hydrationRepository.skipTodayHydration(DateTime.now());
        await _cancelHydrationSchedules();
      }
      return;
    }

    // ---- Break notifications ----
    final isBreakPayload = payload == AppRoutes.breakScreen;
    final isBreakAction =
        actionId == breakSnoozeActionId || actionId == breakDoneActionId;

    if (isBreakPayload || isBreakAction) {
      if (id != null) await _plugin.cancel(id: id);

      if (actionId == breakSnoozeActionId) {
        final snoozeUntil = DateTime.now()
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        await _breakStateRepository.setSnoozeUntilMillis(snoozeUntil);
      } else if (actionId == breakDoneActionId) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await _breakStateRepository.setConsecutiveIgnored(0);
        await _breakStateRepository.setLastMovementAtMillis(nowMs);
      }
    }
  }
}
