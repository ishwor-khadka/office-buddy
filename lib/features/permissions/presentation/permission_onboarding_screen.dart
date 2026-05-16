import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/fcm_token_service.dart';
import '../../../core/permissions/post_login_permission_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/settings/office_schedule_repository.dart';
import '../../../core/ui/ob_background.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  final OfficeScheduleRepository _scheduleRepository =
      OfficeScheduleRepository();
  final ValueNotifier<int> _refreshTick = ValueNotifier<int>(0);
  int _stepIndex = 0;
  bool _requesting = false;

  static const List<_PermissionStep> _steps = <_PermissionStep>[
    _PermissionStep(
      icon: Icons.photo_camera_outlined,
      title: 'Camera access',
      body: 'Enable posture and eye checks when you open those tools.',
      actionLabel: 'Allow camera',
      type: _PermissionType.camera,
    ),
    _PermissionStep(
      icon: Icons.directions_walk_rounded,
      title: 'Activity access',
      body: 'Let Office Buddy count movement for break and step features.',
      actionLabel: 'Allow activity',
      type: _PermissionType.activity,
    ),
    _PermissionStep(
      icon: Icons.notifications_active_outlined,
      title: 'Reminders',
      body: 'Turn on break and hydration reminders during your office hours.',
      actionLabel: 'Allow reminders',
      type: _PermissionType.notifications,
    ),
  ];

  @override
  void dispose() {
    _refreshTick.dispose();
    super.dispose();
  }

  void _refresh(VoidCallback update) {
    if (!mounted) return;
    update();
    _refreshTick.value++;
  }

  Future<void> _requestCurrentStep() async {
    if (_requesting) return;
    final step = _steps[_stepIndex];

    _refresh(() => _requesting = true);
    try {
      switch (step.type) {
        case _PermissionType.camera:
          await PostLoginPermissionService.requestCamera();
          break;
        case _PermissionType.activity:
          await PostLoginPermissionService.requestActivityRecognition();
          break;
        case _PermissionType.notifications:
          await PostLoginPermissionService.requestNotifications();
          unawaited(FcmTokenService.registerCurrentUserToken());
          break;
      }
      await _goNext();
    } finally {
      if (mounted) {
        _refresh(() => _requesting = false);
      }
    }
  }

  Future<void> _goNext() async {
    if (_stepIndex < _steps.length - 1) {
      _refresh(() => _stepIndex++);
      return;
    }

    await PostLoginPermissionService.markCompletedForCurrentUser();
    if (!mounted) return;

    final hasSavedSchedule = await _scheduleRepository
        .hasSavedSchedule()
        .timeout(const Duration(seconds: 4), onTimeout: () => false);
    if (!mounted) return;
    context.go(
      hasSavedSchedule ? AppRoutes.homeScreen : AppRoutes.onBoardingScreen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTick,
      builder: (context, _, child) {
        final step = _steps[_stepIndex];
        final progress = (_stepIndex + 1) / _steps.length;

        return Scaffold(
          backgroundColor: const Color(0xFFF7FBF8),
          body: ObBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white,
                              color: const Color(0xFF57C6A1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_stepIndex + 1}/${_steps.length}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF556070),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 26,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Icon(
                          step.icon,
                          size: 58,
                          color: const Color(0xFF31A981),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF162033),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      step.body,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF667085),
                        height: 1.45,
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _requesting ? null : _requestCurrentStep,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF162033),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _requesting
                            ? 'Opening permission...'
                            : step.actionLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _requesting ? null : _goNext,
                      child: Text(
                        _stepIndex == _steps.length - 1
                            ? 'Not now'
                            : 'Skip for now',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF526070),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _PermissionType { camera, activity, notifications }

class _PermissionStep {
  const _PermissionStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.type,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final _PermissionType type;
}
