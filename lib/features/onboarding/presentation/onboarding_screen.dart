import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/settings_providers.dart';
import '../../../core/settings/user_settings.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _kOnboarded = 'onboarded_v1';

  int _workStartMinutes = 9 * 60;
  int _workEndMinutes = 18 * 60;
  int _breakIntervalMinutes = 45;
  int _requiredSteps = 25;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final settings = await ref.read(userSettingsProvider.future);
    if (!mounted) return;
    setState(() {
      _workStartMinutes = settings.workStartMinutes;
      _workEndMinutes = settings.workEndMinutes;
      _breakIntervalMinutes = settings.breakIntervalMinutes;
      _requiredSteps = settings.requiredSteps;
    });
  }

  String _fmtTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({
    required bool start,
  }) async {
    final initial = TimeOfDay(
      hour: (start ? _workStartMinutes : _workEndMinutes) ~/ 60,
      minute: (start ? _workStartMinutes : _workEndMinutes) % 60,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        _workStartMinutes = minutes;
      } else {
        _workEndMinutes = minutes;
      }
    });
  }

  Future<void> _finish() async {
    final settings = UserSettings(
      workStartMinutes: _workStartMinutes,
      workEndMinutes: _workEndMinutes,
      breakIntervalMinutes: _breakIntervalMinutes,
      requiredSteps: _requiredSteps,
    );
    await ref.read(userSettingsProvider.notifier).save(settings);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, true);

    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ObBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Welcome to Office Buddy',
                  style: theme.textTheme.displayLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Set your work hours and break rhythm. You can change this later.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ObGlass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Work hours', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TimePill(
                              label: 'Start',
                              value: _fmtTime(_workStartMinutes),
                              onTap: () => _pickTime(start: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimePill(
                              label: 'End',
                              value: _fmtTime(_workEndMinutes),
                              onTap: () => _pickTime(start: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ObGlass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Break interval', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        '${_breakIntervalMinutes} minutes',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Slider(
                        min: 20,
                        max: 90,
                        divisions: 14,
                        value: _breakIntervalMinutes.toDouble(),
                        onChanged: (v) => setState(() {
                          _breakIntervalMinutes = v.round();
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ObGlass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Steps to dismiss', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        '${_requiredSteps} steps',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Slider(
                        min: 20,
                        max: 30,
                        divisions: 10,
                        value: _requiredSteps.toDouble(),
                        onChanged: (v) => setState(() {
                          _requiredSteps = v.round();
                        }),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ObTokens.mint,
                    foregroundColor: ObTokens.text,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
