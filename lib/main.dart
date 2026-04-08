import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/notifications/notification_service.dart';
import 'core/breaks/break_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  await NotificationService.initialize(
    onTapNotification: (payload) {
      if (payload == null || payload.isEmpty) return;
      appRouter.go(payload);
    },
  );
  await BreakBackground.initialize();
  await BreakBackground.registerPeriodicTick();
  runApp(
    const ProviderScope(
      child: OfficeHealthApp(),
    ),
  );
}

class OfficeHealthApp extends ConsumerWidget {
  const OfficeHealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Office Buddy',
      theme: AppTheme.glassLightTheme,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
