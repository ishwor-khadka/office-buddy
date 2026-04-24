import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/settings/office_schedule.dart';
import '../../../core/settings/office_schedule_repository.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _kOnboarded = 'onboarded_v1';
  final OfficeScheduleRepository _repository = OfficeScheduleRepository();

  int _workStartMinutes = 9 * 60;
  int _workEndMinutes = 18 * 60;
  final Set<int> _offDays = <int>{DateTime.saturday, DateTime.sunday};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final schedule = await _repository.load();
    if (!mounted) return;
    setState(() {
      _workStartMinutes = schedule.workStartMinutes;
      _workEndMinutes = schedule.workEndMinutes;
      _offDays
        ..clear()
        ..addAll(schedule.offDays);
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

  void _toggleOffDay(int weekday) {
    setState(() {
      if (!_offDays.add(weekday)) {
        _offDays.remove(weekday);
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final synced = await _repository.save(
        OfficeSchedule(
          workStartMinutes: _workStartMinutes,
          workEndMinutes: _workEndMinutes,
          offDays: _offDays.toList()..sort(),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboarded, true);

      if (!synced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally. Cloud sync will retry later.'),
          ),
        );
      }
      if (!mounted) return;
      context.go(AppRoutes.homeScreen);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save office timing: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                      'Set your office start time, end time, and off days. You can change this later.',
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
                          Text('Off days', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Select the days you do not work.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _weekdayLabels.entries.map((entry) {
                              final isSelected = _offDays.contains(entry.key);
                              return FilterChip(
                                label: Text(entry.value),
                                selected: isSelected,
                                onSelected: (_) => _toggleOffDay(entry.key),
                                showCheckmark: false,
                                selectedColor: ObTokens.mint.withValues(
                                  alpha: 0.34,
                                ),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.32,
                                ),
                                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight:
                                      isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: BorderSide(
                                    color: isSelected
                                        ? ObTokens.mint
                                        : Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _saving ? null : _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ObTokens.mint,
                        foregroundColor: ObTokens.text,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(_saving ? 'Saving...' : 'Continue'),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

const Map<int, String> _weekdayLabels = <int, String>{
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

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
