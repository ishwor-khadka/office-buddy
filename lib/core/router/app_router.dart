import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:office_buddy/core/router/app_routes.dart';
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
import '../../core/exercises/exercise.dart';
import '../../features/exercises/presentation/exercise_detail_screen.dart';
import '../../features/finance/presentation/finance_tracker_screen.dart';
import '../../features/finance/presentation/finance_person_details_screen.dart';
import '../../features/finance/presentation/add_expense_screen.dart';
import '../../features/finance/presentation/lend_borrow_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/account/presentation/account_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter? _appRouter;

GoRouter get appRouter => _appRouter ??= _createAppRouter();

GoRouter _createAppRouter() {
  final auth = FirebaseAuth.instance;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation:
        auth.currentUser == null ? AppRoutes.loginScreen : AppRoutes.homeScreen,
    refreshListenable: _GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final user = auth.currentUser;
      final isLoggedIn = user != null;
      final goingToLogin = state.matchedLocation == AppRoutes.loginScreen;

      if (!isLoggedIn) {
        return goingToLogin ? null : AppRoutes.loginScreen;
      }

      if (goingToLogin || state.matchedLocation == AppRoutes.splashScreen) {
        return AppRoutes.homeScreen;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.loginScreen,
        builder: (context, state) => const GoogleLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.splashScreen,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeScreen,
        builder: (context, state) => const MainScaffold(),
      ),
      GoRoute(
        path: AppRoutes.onBoardingScreen,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountScreen,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.stressScreen,
        builder: (context, state) => const StressReliefScreen(),
      ),
      GoRoute(
        path: AppRoutes.postureScreen,
        builder: (context, state) => const PostureScreen(),
      ),
      GoRoute(
        path: AppRoutes.eyesScreen,
        builder: (context, state) => const EyeDrynessScreen(),
      ),
      GoRoute(
        path: AppRoutes.financeScreen,
        builder: (context, state) => const FinanceTrackerScreen(),
      ),
      GoRoute(
        path: AppRoutes.exerciseDetailScreen,
        builder: (context, state) {
          final exercise = state.extra as Exercise?;
          if (exercise == null) {
            return const Scaffold(
              body: Center(child: Text('Missing exercise data')),
            );
          }
          return ExerciseDetailScreen(exercise: exercise);
        },
      ),
      GoRoute(
        path: AppRoutes.financeAddExpenseScreen,
        builder: (context, state) => const AddExpenseScreen(),
      ),
      GoRoute(
        path: AppRoutes.financePersonScreen,
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
        path: AppRoutes.financeLendBorrowScreen,
        builder: (context, state) => const LendBorrowScreen(),
      ),
      GoRoute(
        path: AppRoutes.breakScreen,
        builder: (context, state) => const BreakScreen(),
      ),
    ],
  );
}

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

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
