import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/exercises/presentation/exercises_screen.dart';
import '../../features/stress_relief/presentation/stress_relief_screen.dart';
import '../../features/breaks/presentation/break_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../breaks/step_activity_controller.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../ui/ob_bottom_bar.dart';
import '../../features/sleep/presentation/sleep_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainScaffold(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      path: '/stress',
      builder: (context, state) => const StressReliefScreen(),
    ),
    GoRoute(
      path: '/break',
      builder: (context, state) => const BreakScreen(),
    ),
  ],
);

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const SleepScreen(),
    const ExercisesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(stepActivityControllerProvider);

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: ObBottomBar(
        currentIndex: _currentIndex,
        onSelect: (i) {
          setState(() => _currentIndex = i.clamp(0, 3));
        },
        onBreathe: () => context.push('/stress'),
      ),
    );
  }
}
