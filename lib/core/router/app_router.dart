import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/breaks/step_activity_controller.dart';
import '../../core/ui/ob_bottom_bar.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/auth/presentation/google_login_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/stress_relief/presentation/stress_relief_screen.dart';
import '../../features/breaks/presentation/break_screen.dart';
import '../../features/posture/presentation/posture_screen.dart';
import '../../features/eyes/presentation/eye_dryness_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/sleep/presentation/sleep_screen.dart';
import '../../features/exercises/presentation/exercises_screen.dart';
import '../../features/finance/presentation/finance_tracker_screen.dart';
import '../../features/finance/presentation/finance_person_details_screen.dart';
import '../../features/finance/presentation/add_expense_screen.dart';
import '../../features/finance/presentation/lend_borrow_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/account/presentation/account_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const GoogleLoginScreen()),
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/home', builder: (context, state) => const MainScaffold()),
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
      path: '/posture',
      builder: (context, state) => const PostureScreen(),
    ),
    GoRoute(
      path: '/eyes',
      builder: (context, state) => const EyeDrynessScreen(),
    ),
    GoRoute(
      path: '/finance',
      builder: (context, state) => const FinanceTrackerScreen(),
    ),
    GoRoute(
      path: '/finance/add-expense',
      builder: (context, state) => const AddExpenseScreen(),
    ),
    GoRoute(
      path: '/finance/person',
      builder: (context, state) {
        final args = state.extra as FinancePersonDetailsArgs?;
        return FinancePersonDetailsScreen(
          args:
              args ??
              const FinancePersonDetailsArgs(
                name: 'Rajesh',
                amount: '₹500',
                isOwed: true,
                color: Color(0xFF5EB7F6),
                initials: '👱',
                transactions: [
                  FinanceTransaction(
                    title: 'Dinner at restaurant',
                    dateLabel: 'Apr 5, 2026',
                    amount: '₹300',
                  ),
                  FinanceTransaction(
                    title: 'Movie tickets',
                    dateLabel: 'Apr 3, 2026',
                    amount: '₹200',
                  ),
                ],
              ),
        );
      },
    ),
    GoRoute(
      path: '/finance/lend-borrow',
      builder: (context, state) => const LendBorrowScreen(),
    ),
    GoRoute(path: '/break', builder: (context, state) => const BreakScreen()),
  ],
);

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    SleepScreen(),
    ExercisesScreen(),
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
      ),
    );
  }
}
