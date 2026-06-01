import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase/firebase_bootstrap.dart';
import '../hydration/hydration_repository.dart';
import '../notifications/notification_service.dart';
import '../router/app_routes.dart';
import '../settings/office_schedule.dart';
import '../settings/office_schedule_repository.dart';
import '../settings/settings_repository.dart';
import 'break_state_repository.dart';
import '../data/database_helper.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  BreakBackground.executeTask();
}

class BreakBackground {
  static const String periodicTaskName = 'office_buddy_break_tick';
  static const String hydrationRetryTaskName = 'office_buddy_hydration_retry';
  static const int _hydrationPerDayLimit = 6;
  static const int _hydrationAmountMl = 250;
  static const int _hydrationIntervalMinutes = 75;
  static const int _hydrationRetryDelayMinutes = 3;
  static const int _hydrationFirstOffsetMinutes = 30;
  static const int _hydrationLastOffsetMinutes = 30;

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> registerPeriodicTick() async {
    await Workmanager().registerPeriodicTask(
      periodicTaskName,
      periodicTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static void executeTask() {
    Workmanager().executeTask((task, inputData) async {
      WidgetsFlutterBinding.ensureInitialized();
      await FirebaseBootstrap.initialize();

      await NotificationService.initialize(onTapNotification: (_) {});

      final officeScheduleRepo = OfficeScheduleRepository();
      final settingsRepo = SettingsRepository();
      final breakStateRepo = BreakStateRepository();
      final officeSchedule = await officeScheduleRepo.load();
      final settings = await settingsRepo.load();
      final hydrationRepo = HydrationRepository();

      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      final isOffDay = officeSchedule.offDays.contains(now.weekday);
      final withinWorkHours =
          nowMinutes >= officeSchedule.workStartMinutes &&
          nowMinutes <= officeSchedule.workEndMinutes;

      if (isOffDay || !withinWorkHours) {
        return true;
      }

      // Re-arm hydration schedule if the tail is running thin.
      await NotificationService.rearmIfNeeded(schedule: officeSchedule);

      // Retry logic: send a follow-up if a hydration slot fired but wasn't acked.
      await _checkHydrationRetry(
        now: now,
        officeSchedule: officeSchedule,
        hydrationRepo: hydrationRepo,
      );

      if (task != periodicTaskName) {
        return true;
      }

      final nowMs = now.millisecondsSinceEpoch;
      final snoozeUntil = await breakStateRepo.getSnoozeUntilMillis();
      if (snoozeUntil != null && nowMs < snoozeUntil) {
        return true;
      }

      final nextBreakAt = await breakStateRepo.getNextBreakAtMillis();
      if (nextBreakAt == null) {
        await breakStateRepo.setNextBreakAtMillis(
          nowMs + settings.breakIntervalMinutes * 60 * 1000,
        );
        return true;
      }

      if (nowMs < nextBreakAt) {
        return true;
      }

      // Suppress if the user is already moving (steps recorded recently).
      final lastStepAt = await breakStateRepo.getLastStepAtMillis();
      if (lastStepAt != null && (nowMs - lastStepAt) <= 2 * 60 * 1000) {
        await breakStateRepo.setNextBreakAtMillis(
          nowMs + settings.breakIntervalMinutes * 60 * 1000,
        );
        return true;
      }

      // Break is due. Decide escalation based on ignored + sedentary time.
      final ignored = await breakStateRepo.getConsecutiveIgnored();
      final lastMoveMs = await breakStateRepo.getLastMovementAtMillis();
      final sedentaryMinutes = lastMoveMs == null
          ? 999
          : ((nowMs - lastMoveMs) / (60 * 1000)).floor();

      final shouldEscalate = ignored >= 2 && sedentaryMinutes >= 90;

      var escalationLevel = await breakStateRepo.getEscalationLevel();
      if (!shouldEscalate) {
        escalationLevel = 0;
        await breakStateRepo.setEscalationLevel(0);
      } else {
        if (sedentaryMinutes >= 150) {
          escalationLevel = 3;
        } else if (sedentaryMinutes >= 120) {
          escalationLevel = 2;
        } else {
          escalationLevel = 1;
        }
        await breakStateRepo.setEscalationLevel(escalationLevel);
      }

      final payload = AppRoutes.breakScreen;
      final title = shouldEscalate ? 'Movement needed' : 'Time for a break';
      final body = switch (escalationLevel) {
        1 =>
          '90 min sedentary. Walk ${settings.requiredSteps} steps to reset.',
        2 =>
          '120 min without movement. Walk ${settings.requiredSteps} steps now.',
        3 =>
          '150+ min sedentary. Walk ${settings.requiredSteps} steps now.',
        _ => 'Walk ${settings.requiredSteps} steps to reset your body.',
      };

      final notifId = NotificationService.breakNotificationId();
      await NotificationService.showBreakReminder(
        id: notifId,
        title: title,
        body: body,
        payload: payload,
        isEscalated: shouldEscalate,
      );

      await DatabaseHelper.instance.insertBreakLog(
        timestampMillis: nowMs,
        outcome: 'IGNORED',
        stepsCompleted: 0,
        sedentaryMinsBefore: sedentaryMinutes,
      );
      await breakStateRepo.setConsecutiveIgnored(ignored + 1);

      await breakStateRepo.setNextBreakAtMillis(
        nowMs + settings.breakIntervalMinutes * 60 * 1000,
      );

      return true;
    });
  }

  /// Sends a one-time follow-up if a hydration slot fired but wasn't acknowledged.
  static Future<void> _checkHydrationRetry({
    required DateTime now,
    required OfficeSchedule officeSchedule,
    required HydrationRepository hydrationRepo,
  }) async {
    final nowMs = now.millisecondsSinceEpoch;
    final nowMinutes = now.hour * 60 + now.minute;

    final firstReminderMinutes =
        officeSchedule.workStartMinutes + _hydrationFirstOffsetMinutes;
    final lastReminderMinutes =
        officeSchedule.workEndMinutes - _hydrationLastOffsetMinutes;

    if (nowMinutes < firstReminderMinutes || nowMinutes > lastReminderMinutes) {
      return;
    }

    // Skip if user explicitly skipped today.
    if (await hydrationRepo.isHydrationSkippedToday(now)) return;

    // Skip if hydration snooze is active.
    final snoozeUntil = await hydrationRepo.getHydrationSnoozeUntilMillis();
    if (snoozeUntil != null && nowMs < snoozeUntil) return;

    // Skip if today's quota is already met.
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayStartMs = dayStart.millisecondsSinceEpoch;
    final dayEntries = (await hydrationRepo.loadEntries()).where((entry) {
      final t = (entry['t'] as num?)?.toInt();
      return t != null && t >= dayStartMs;
    }).toList(growable: false);

    if (dayEntries.length >= _hydrationPerDayLimit) return;

    // Compute all slots that should have fired today up to now.
    final expectedSlots = _computeTodaySlots(officeSchedule, now);
    final passedSlots = expectedSlots.where((s) => s.isBefore(now)).toList();
    if (passedSlots.isEmpty) return;

    final latestSlot = passedSlots.last;

    // Skip retry if in lunch window.
    final latestSlotMinutes = latestSlot.hour * 60 + latestSlot.minute;
    if (officeSchedule.isLunchTime(latestSlotMinutes)) return;

    // Check if the latest slot has been acknowledged.
    final lastAckMs = await hydrationRepo.getLastAcknowledgedAtMillis();
    if (lastAckMs != null &&
        lastAckMs >= latestSlot.millisecondsSinceEpoch) {
      return;
    }

    // Only retry once per slot (check lastPromptAt).
    final lastPromptMs = await hydrationRepo.getLastPromptAtMillis();
    if (lastPromptMs != null &&
        lastPromptMs >= latestSlot.millisecondsSinceEpoch) {
      return;
    }

    // Require the retry delay to pass before sending.
    final minutesSinceSlot = now.difference(latestSlot).inMinutes;
    if (minutesSinceSlot < _hydrationRetryDelayMinutes) return;

    await _sendHydrationRetry(
      hydrationRepo: hydrationRepo,
      nowMs: nowMs,
      logsToday: dayEntries.length,
    );
  }

  static List<DateTime> _computeTodaySlots(
    OfficeSchedule schedule,
    DateTime now,
  ) {
    final dayStart = DateTime(now.year, now.month, now.day);
    final firstAt = dayStart.add(
      Duration(minutes: schedule.workStartMinutes + _hydrationFirstOffsetMinutes),
    );
    final lastAt = dayStart.add(
      Duration(minutes: schedule.workEndMinutes - _hydrationLastOffsetMinutes),
    );
    if (!firstAt.isBefore(lastAt)) return const [];

    final slots = <DateTime>[];
    var at = firstAt;
    var count = 0;
    while (count < _hydrationPerDayLimit && !at.isAfter(lastAt)) {
      final atMinutes = at.hour * 60 + at.minute;
      if (!schedule.isLunchTime(atMinutes)) {
        slots.add(at);
      }
      count++;
      at = at.add(const Duration(minutes: _hydrationIntervalMinutes));
    }
    return slots;
  }

  static Future<void> _sendHydrationRetry({
    required HydrationRepository hydrationRepo,
    required int nowMs,
    required int logsToday,
  }) async {
    final random = Random(nowMs);
    final allTitles = NotificationService.hydrationTitles;
    final title = allTitles[random.nextInt(allTitles.length)];
    final body = NotificationService.hydrationBodies[random.nextInt(
      NotificationService.hydrationBodies.length,
    )];
    final actionLabel = NotificationService.hydrationActionLabels[random.nextInt(
      NotificationService.hydrationActionLabels.length,
    )];
    final notificationId = 700 + random.nextInt(100000);

    final progressSuffix = ' ($logsToday/$_hydrationPerDayLimit today)';

    await NotificationService.showHydrationReminder(
      id: notificationId,
      title: title,
      body: '$body (+$_hydrationAmountMl mL)$progressSuffix',
      actionLabel: actionLabel,
    );

    await hydrationRepo.setPendingPrompt(
      sinceMillis: nowMs,
      notificationId: notificationId,
      retryCount: 1,
    );
  }
}
