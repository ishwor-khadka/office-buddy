import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pedometer/pedometer.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/breaks/break_state_repository.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/tracking/tracking_repository.dart';

class BreakScreen extends StatefulWidget {
  final int requiredSteps;

  const BreakScreen({super.key, this.requiredSteps = 25});

  @override
  State<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends State<BreakScreen> {
  int _requiredSteps = 25;
  int _currentSteps = 0;
  int? _baselineSteps;
  bool _isSnoozed = false;
  bool _snoozeUsed = false;
  Stream<StepCount>? _stepStream;
  StreamSubscription<StepCount>? _stepSub;
  String? _stepError;

  @override
  void initState() {
    super.initState();
    _requiredSteps = widget.requiredSteps;
    _loadSettings();
    _ensureActivityPermission();
    _initSteps();
  }

  Future<void> _ensureActivityPermission() async {
    try {
      final status = await Permission.activityRecognition.status;
      if (status.isDenied || status.isRestricted) {
        await Permission.activityRecognition.request();
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsRepository().load();
    if (!mounted) return;
    setState(() => _requiredSteps = settings.requiredSteps);
  }

  Future<void> _initSteps() async {
    try {
      _stepStream = Pedometer.stepCountStream;
      _stepSub = _stepStream!.listen(
        (event) {
          final steps = event.steps;
          if (_baselineSteps == null) {
            _baselineSteps = steps;
            return;
          }
          final delta = steps - _baselineSteps!;
          if (delta < 0) return;

          if (mounted) {
            setState(() => _currentSteps = delta);
          }

          if (delta >= _requiredSteps) {
            _completeBreak(stepsCompleted: delta);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() => _stepError = 'Step counter not available: $e');
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _stepError = 'Step counter init failed: $e');
    }
  }

  Future<void> _completeBreak({required int stepsCompleted}) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    final settings = await SettingsRepository().load();
    final breakState = BreakStateRepository();

    await DatabaseHelper.instance.insertBreakLog(
      timestampMillis: nowMs,
      outcome: 'COMPLETED',
      stepsCompleted: stepsCompleted,
      sedentaryMinsBefore: null,
    );
    await TrackingRepository.trackIfAvailable(
      type: 'break_completed',
      data: {
        'steps_completed': stepsCompleted,
      },
    );

    await breakState.setConsecutiveIgnored(0);
    await breakState.setEscalationLevel(0);
    await breakState.clearSnooze();
    await breakState.setNextBreakAtMillis(
      nowMs + settings.breakIntervalMinutes * 60 * 1000,
    );
    await breakState.setLastMovementAtMillis(nowMs);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    super.dispose();
  }

  Future<void> _snooze() async {
    setState(() => _isSnoozed = true);
    _snoozeUsed = true;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final breakState = BreakStateRepository();

    await DatabaseHelper.instance.insertBreakLog(
      timestampMillis: nowMs,
      outcome: 'SNOOZED',
      stepsCompleted: 0,
      sedentaryMinsBefore: null,
    );
    await TrackingRepository.trackIfAvailable(
      type: 'break_snoozed',
      data: {'snooze_minutes': 5},
    );

    await breakState.setSnoozeUntilMillis(nowMs + 5 * 60 * 1000);
    await breakState.setNextBreakAtMillis(nowMs + 5 * 60 * 1000);
    await breakState.setConsecutiveIgnored(0);
    await breakState.setEscalationLevel(0);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Break snoozed for 5 minutes.')),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_currentSteps / _requiredSteps).clamp(0.0, 1.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.errorContainer,
        body: SafeArea(
          child: IgnorePointer(
            ignoring: _isSnoozed,
            child: AnimatedOpacity(
              opacity: _isSnoozed ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.activitySquare,
                      size: 80,
                      color: theme.colorScheme.onErrorContainer,
                    ).animate(onPlay: (c) => c.repeat()).shakeX(amount: 3),
                    const SizedBox(height: 36),
                    Text(
                      'Time to move',
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 34,
                      ),
                    ).animate().fade().slideY(begin: 0.2),
                    const SizedBox(height: 12),
                    Text(
                      'Walk ${_requiredSteps} steps to dismiss.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer.withOpacity(0.85),
                      ),
                    ).animate().fade(delay: 200.ms),
                    if (_stepError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _stepError!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tip: step counting may not work on an emulator. Try on a physical device.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer.withOpacity(0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 44),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            backgroundColor: Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '$_currentSteps',
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 56,
                              ),
                            ),
                            Text(
                              ' / ${_requiredSteps} steps',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer.withOpacity(0.75),
                              ),
                            )
                          ],
                        )
                      ],
                    ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                          onPressed: _snoozeUsed ? null : _snooze,
                            child: Text(
                              _snoozeUsed ? 'Snoozed' : 'Snooze (5m)',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer
                                    .withOpacity(_snoozeUsed ? 0.35 : 0.65),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.onErrorContainer,
                              foregroundColor: theme.colorScheme.errorContainer,
                            ),
                            onPressed: _stepError == null
                                ? null
                                : () {
                                    setState(() => _currentSteps = _requiredSteps);
                                    _completeBreak(stepsCompleted: _requiredSteps);
                                  },
                            child: const Text('I walked'),
                          ),
                        ),
                      ],
                    ).animate().fade(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
