import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import '../../../core/ui/ui_refresh_bus.dart';

import '../../../core/hydration/hydration_repository.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/settings/office_schedule.dart';
import '../../../core/settings/office_schedule_repository.dart';
import '../../../core/ui/ob_background.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  static const int _targetMl = 1500;
  static const int _doseMl = 250;
  static const int _maxDoseCount = 6;
  static const int _intervalMinutes = 75;
  static const int _startOffsetMinutes = 30;
  static const int _endOffsetMinutes = 30;

  final HydrationRepository _hydrationRepository = HydrationRepository();
  final OfficeScheduleRepository _officeScheduleRepository =
      OfficeScheduleRepository();

  late Future<_HydrationViewData> _future;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        UiRefreshBus.instance.update(this, () => _future = _loadData());
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<_HydrationViewData> _loadData() async {
    final now = DateTime.now();
    final schedule = await _officeScheduleRepository.load();
    final entries = await _hydrationRepository.loadEntries();
    final pendingSince = await _hydrationRepository.getPendingSinceMillis();
    final retryCount = await _hydrationRepository.getPendingRetryCount();

    final todayEntries =
        entries
            .where((entry) {
              final t = (entry['t'] as num?)?.toInt();
              if (t == null) return false;
              final dt = DateTime.fromMillisecondsSinceEpoch(t);
              return dt.year == now.year &&
                  dt.month == now.month &&
                  dt.day == now.day;
            })
            .map((entry) {
              final t = (entry['t'] as num).toInt();
              final ml = ((entry['ml'] as num?)?.toInt() ?? _doseMl);
              return _DrinkEntry(
                time: DateTime.fromMillisecondsSinceEpoch(t),
                ml: ml,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => b.time.compareTo(a.time));

    final consumedMl = todayEntries.fold<int>(0, (sum, item) => sum + item.ml);
    final remainingMl = (_targetMl - consumedMl).clamp(0, _targetMl);
    final progress = (consumedMl / _targetMl).clamp(0, 1).toDouble();

    final plannedTimes = _plannedTimesForDay(now, schedule);
    final nextPlanned = _nextPlannedTime(
      now: now,
      schedule: schedule,
      todayDrinkCount: todayEntries.length,
      lastDrinkTime: todayEntries.isEmpty ? null : todayEntries.first.time,
      pendingSince: pendingSince == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(pendingSince),
      retryCount: retryCount,
    );

    return _HydrationViewData(
      consumedMl: consumedMl,
      remainingMl: remainingMl,
      progress: progress,
      todayEntries: todayEntries,
      plannedTimes: plannedTimes,
      nextPlanned: nextPlanned,
    );
  }

  List<DateTime> _plannedTimesForDay(DateTime date, OfficeSchedule schedule) {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      schedule.workStartMinutes ~/ 60,
      schedule.workStartMinutes % 60,
    ).add(const Duration(minutes: _startOffsetMinutes));
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      schedule.workEndMinutes ~/ 60,
      schedule.workEndMinutes % 60,
    ).subtract(const Duration(minutes: _endOffsetMinutes));

    if (!start.isBefore(end)) return const <DateTime>[];

    final list = <DateTime>[];
    for (var i = 0; i < _maxDoseCount; i++) {
      final t = start.add(Duration(minutes: i * _intervalMinutes));
      if (t.isAfter(end)) break;
      list.add(t);
    }
    return list;
  }

  DateTime? _nextPlannedTime({
    required DateTime now,
    required OfficeSchedule schedule,
    required int todayDrinkCount,
    required DateTime? lastDrinkTime,
    required DateTime? pendingSince,
    required int retryCount,
  }) {
    if (schedule.offDays.contains(now.weekday)) return null;
    if (todayDrinkCount >= _maxDoseCount) return null;

    final dayStart = DateTime(now.year, now.month, now.day);
    final first = dayStart.add(
      Duration(minutes: schedule.workStartMinutes + _startOffsetMinutes),
    );
    final last = dayStart.add(
      Duration(minutes: schedule.workEndMinutes - _endOffsetMinutes),
    );
    if (!first.isBefore(last)) return null;

    if (pendingSince != null) {
      if (retryCount < 1) {
        final retryAt = pendingSince.add(const Duration(minutes: 3));
        return retryAt.isAfter(last) ? null : retryAt;
      }
      return pendingSince;
    }

    if (now.isBefore(first)) return first;
    if (lastDrinkTime == null) return now.isAfter(last) ? null : now;

    final next = lastDrinkTime.add(const Duration(minutes: _intervalMinutes));
    if (next.isAfter(last)) return null;
    return next.isBefore(now) ? now : next;
  }

  String _formatTime(DateTime time) {
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final m = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  Future<void> _triggerTestNotification() async {
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final title =
        NotificationService.hydrationTitles[random.nextInt(
          NotificationService.hydrationTitles.length,
        )];
    final body =
        NotificationService.hydrationBodies[random.nextInt(
          NotificationService.hydrationBodies.length,
        )];
    final actionLabel =
        NotificationService.hydrationActionLabels[random.nextInt(
          NotificationService.hydrationActionLabels.length,
        )];

    await NotificationService.showHydrationReminder(
      id: 990000 + random.nextInt(999),
      title: title,
      body: '$body (+250 mL)',
      actionLabel: actionLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: ObBackground(
        child: SafeArea(
          child: FutureBuilder<_HydrationViewData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return RefreshIndicator(
                onRefresh: () async {
                  UiRefreshBus.instance.update(this, () => _future = _loadData());
                  await _future;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hydration',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Target: 1.5 L',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          LinearProgressIndicator(
                            value: data?.progress ?? 0,
                            minHeight: 12,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF0EA5E9),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Consumed: ${(data?.consumedMl ?? 0)} mL',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Remaining: ${(data?.remainingMl ?? _targetMl)} mL',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Drink Time',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            data?.nextPlanned == null
                                ? 'No more hydration reminders planned for now.'
                                : _formatTime(data!.nextPlanned!),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF0284C7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s Drink Log',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if ((data?.todayEntries.isEmpty ?? true))
                            Text(
                              'No water logged yet today.',
                              style: theme.textTheme.bodyMedium,
                            )
                          else
                            ...data!.todayEntries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.water_drop_rounded,
                                      size: 18,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_formatTime(entry.time)}  •  ${entry.ml} mL',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Planned Reminder Times',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if ((data?.plannedTimes.isEmpty ?? true))
                            Text(
                              'No planned slots for today based on office schedule.',
                              style: theme.textTheme.bodyMedium,
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: data!.plannedTimes
                                  .map(
                                    (t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(_formatTime(t)),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await _triggerTestNotification();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Hydration test notification sent.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications_active_rounded),
                        label: const Text('Test Hydration Notification'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HydrationViewData {
  const _HydrationViewData({
    required this.consumedMl,
    required this.remainingMl,
    required this.progress,
    required this.todayEntries,
    required this.plannedTimes,
    required this.nextPlanned,
  });

  final int consumedMl;
  final int remainingMl;
  final double progress;
  final List<_DrinkEntry> todayEntries;
  final List<DateTime> plannedTimes;
  final DateTime? nextPlanned;
}

class _DrinkEntry {
  const _DrinkEntry({required this.time, required this.ml});

  final DateTime time;
  final int ml;
}
