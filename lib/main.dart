import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:office_buddy/core/router/app_routes.dart';
import 'core/ui/ui_refresh_bus.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/notifications/notification_service.dart';
import 'core/breaks/break_background.dart';
import 'core/settings/office_schedule_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  await NotificationService.initialize(
    onTapNotification: (payload) {
      if (payload == null || payload.isEmpty) return;
      appRouter.go(AppRoutes.homeScreen);
      appRouter.push(payload);
    },
  );
  await BreakBackground.initialize();
  await BreakBackground.registerPeriodicTick();
  final officeSchedule = await OfficeScheduleRepository().load();
  await NotificationService.rescheduleHydrationReminders(
    schedule: officeSchedule,
  );
  runApp(const ProviderScope(child: OfficeHealthApp()));
}

class OfficeHealthApp extends ConsumerWidget {
  const OfficeHealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<int>(
      valueListenable: UiRefreshBus.instance.tick,
      builder: (context, _, child) {
        return MaterialApp.router(
          title: 'Office Buddy',
          theme: AppTheme.glassLightTheme,
          themeMode: ThemeMode.light,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
