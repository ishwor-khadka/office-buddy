import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase/firebase_bootstrap.dart';
import '../notifications/notification_service.dart';
import '../router/app_routes.dart';
import '../settings/office_schedule_repository.dart';
import '../settings/settings_repository.dart';
import 'break_state_repository.dart';
import '../data/database_helper.dart';

class BreakBackground {
  static const String periodicTaskName = 'office_buddy_break_tick';

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
  }

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
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

      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      final isOffDay = officeSchedule.offDays.contains(now.weekday);
      final withinWorkHours = nowMinutes >= officeSchedule.workStartMinutes &&
          nowMinutes <= officeSchedule.workEndMinutes;

      if (isOffDay || !withinWorkHours) {
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
}
