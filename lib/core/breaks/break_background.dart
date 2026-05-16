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
    // WorkManager periodic minimum is ~15 minutes on Android.
    await Workmanager().registerPeriodicTask(
      periodicTaskName,
      periodicTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
    await Workmanager().registerOneOffTask(
      hydrationRetryTaskName,
      hydrationRetryTaskName,
      initialDelay: const Duration(minutes: _hydrationRetryDelayMinutes),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static void executeTask() {
    Workmanager().executeTask((task, inputData) async {
      WidgetsFlutterBinding.ensureInitialized();
      await FirebaseBootstrap.initialize();

      // Initialize notifications in background isolate so we can show reminders.
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

      await _processHydration(
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

      // BRK-02: Suppress if the user is already moving (steps recorded recently).
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
        // Increase level every 30 minutes beyond 90 if user still sedentary.
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
          '90 min sedentary. Lumbar disc pressure elevated. Walk ${settings.requiredSteps} steps to reset.',
        2 =>
          '120 min no movement. Back strain risk +12% per hour. Walk ${settings.requiredSteps} steps now.',
        3 =>
          '150 min sedentary today. Cumulative risk significant. Walk ${settings.requiredSteps} steps now.',
        _ => 'Walk ${settings.requiredSteps} steps to reset your body.',
      };

      await NotificationService.showBreakReminder(
        id: 101,
        title: title,
        body: body,
        payload: payload,
        fullScreenIntent: shouldEscalate,
      );

      // Mark as ignored until the user completes; increment ignored counter.
      await DatabaseHelper.instance.insertBreakLog(
        timestampMillis: nowMs,
        outcome: 'IGNORED',
        stepsCompleted: 0,
        sedentaryMinsBefore: sedentaryMinutes,
      );
      await breakStateRepo.setConsecutiveIgnored(ignored + 1);

      // Schedule the next check based on interval.
      await breakStateRepo.setNextBreakAtMillis(
        nowMs + settings.breakIntervalMinutes * 60 * 1000,
      );

      return true;
    });
  }

  static Future<void> _processHydration({
    required DateTime now,
    required OfficeSchedule officeSchedule,
    required HydrationRepository hydrationRepo,
  }) async {
    final nowMs = now.millisecondsSinceEpoch;
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayStartMs = dayStart.millisecondsSinceEpoch;
    final firstReminderMinutes =
        officeSchedule.workStartMinutes + _hydrationFirstOffsetMinutes;
    final lastReminderMinutes =
        officeSchedule.workEndMinutes - _hydrationLastOffsetMinutes;
    final nowMinutes = now.hour * 60 + now.minute;

    if (lastReminderMinutes <= firstReminderMinutes) {
      return;
    }
    if (nowMinutes < firstReminderMinutes || nowMinutes > lastReminderMinutes) {
      return;
    }

    final dayEntries = (await hydrationRepo.loadEntries())
        .where((entry) {
          final t = (entry['t'] as num?)?.toInt();
          if (t == null) return false;
          return t >= dayStartMs;
        })
        .toList(growable: false);

    if (dayEntries.length >= _hydrationPerDayLimit) {
      await hydrationRepo.clearPendingPrompt();
      return;
    }

    final pendingSince = await hydrationRepo.getPendingSinceMillis();
    final retryCount = await hydrationRepo.getPendingRetryCount();
    if (pendingSince != null) {
      if (nowMs - pendingSince >= _hydrationRetryDelayMinutes * 60 * 1000 &&
          retryCount < 1) {
        await _sendHydrationPrompt(
          hydrationRepo: hydrationRepo,
          nowMs: nowMs,
          retryCount: retryCount + 1,
        );
      }
      return;
    }

    final lastAck = await hydrationRepo.getLastAcknowledgedAtMillis();
    final dueToStart = nowMinutes >= firstReminderMinutes;
    final dueToInterval =
        lastAck != null &&
        (nowMs - lastAck) >= (_hydrationIntervalMinutes * 60 * 1000);
    final noPromptYetToday = dayEntries.isEmpty;
    final dueForNext = noPromptYetToday ? dueToStart : dueToInterval;
    if (!dueForNext) return;

    // Ensure there is enough room for one retry before office close.
    if (nowMinutes + _hydrationRetryDelayMinutes > lastReminderMinutes) {
      return;
    }

    await _sendHydrationPrompt(
      hydrationRepo: hydrationRepo,
      nowMs: nowMs,
      retryCount: 0,
    );
  }

  static Future<void> _sendHydrationPrompt({
    required HydrationRepository hydrationRepo,
    required int nowMs,
    required int retryCount,
  }) async {
    final random = Random(nowMs);
    final title =
        NotificationService.hydrationTitles[random.nextInt(
          NotificationService.hydrationTitles.length,
        )];
    final body =
        NotificationService.hydrationBodies[random.nextInt(
          NotificationService.hydrationBodies.length,
        )];
    final actionLabel =
        NotificationService.hydrationActionLabels[random.nextInt(
          NotificationService.hydrationActionLabels.length,
        )];
    final notificationId = 700 + random.nextInt(100000);

    await NotificationService.showHydrationReminder(
      id: notificationId,
      title: title,
      body: '$body (+$_hydrationAmountMl mL)',
      actionLabel: actionLabel,
    );
    await hydrationRepo.setPendingPrompt(
      sinceMillis: nowMs,
      notificationId: notificationId,
      retryCount: retryCount,
    );
    await Workmanager().registerOneOffTask(
      hydrationRetryTaskName,
      hydrationRetryTaskName,
      initialDelay: const Duration(minutes: _hydrationRetryDelayMinutes),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
