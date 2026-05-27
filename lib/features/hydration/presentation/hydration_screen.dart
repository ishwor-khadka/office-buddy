import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/ui/ui_refresh_bus.dart';
import '../../../core/hydration/hydration_repository.dart';
import '../../../core/settings/office_schedule.dart';
import '../../../core/settings/office_schedule_repository.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

const _kWaterFill = Color(0xFF0EA5E9);
const _kWaterDark = Color(0xFF0284C7);
const _kWaterLight = Color(0xFF38BDF8);
const _kWaterBg = Color(0xFFDCF0FD);

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

  String _levelLabel(int percent) {
    if (percent == 0) return 'Start hydrating!';
    if (percent < 25) return 'Getting started';
    if (percent < 50) return 'Keep it up!';
    if (percent < 75) return 'Halfway there!';
    if (percent < 100) return 'Almost there!';
    return 'Hydration Master!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFC2E4F8), // sky blue
              Color(0xFFD8EEFA),
              Color(0xFFEDF6FD),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Ambient glow top-right
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FutureBuilder<_HydrationViewData>(
                future: _future,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  return RefreshIndicator(
                    onRefresh: () async {
                      UiRefreshBus.instance.update(
                        this,
                        () => _future = _loadData(),
                      );
                      await _future;
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        // ── Header ──────────────────────────────────
                        _buildHeader(theme)
                            .animate()
                            .fade(duration: 300.ms)
                            .slideY(begin: -0.06, end: 0),

                        const SizedBox(height: 20),

                        // ── Ring Hero ────────────────────────────────
                        TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: data?.progress ?? 0),
                              duration: const Duration(milliseconds: 1400),
                              curve: Curves.easeOutCubic,
                              builder: (context, animProgress, _) =>
                                  _buildRingCard(theme, animProgress, data),
                            )
                            .animate()
                            .fade(duration: 400.ms)
                            .slideY(begin: 0.06, end: 0),

                        const SizedBox(height: 14),

                        // ── Dose Dots ────────────────────────────────
                        _buildDoseDots(theme, data)
                            .animate()
                            .fade(delay: 100.ms, duration: 400.ms)
                            .slideY(begin: 0.06, end: 0),

                        const SizedBox(height: 14),

                        // ── Next Sip ─────────────────────────────────
                        _buildNextSipCard(theme, data)
                            .animate()
                            .fade(delay: 160.ms, duration: 400.ms)
                            .slideY(begin: 0.06, end: 0),

                        const SizedBox(height: 14),

                        // ── Today's Log ──────────────────────────────
                        _buildLogCard(theme, data)
                            .animate()
                            .fade(delay: 220.ms, duration: 400.ms)
                            .slideY(begin: 0.06, end: 0),

                        const SizedBox(height: 14),

                        // ── Schedule ─────────────────────────────────
                        _buildScheduleCard(theme, data)
                            .animate()
                            .fade(delay: 280.ms, duration: 400.ms)
                            .slideY(begin: 0.06, end: 0),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: const Icon(LucideIcons.arrowLeft, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(LucideIcons.droplets, size: 22, color: _kWaterFill),
        const SizedBox(width: 8),
        Text(
          'Hydration',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRingCard(
    ThemeData theme,
    double animProgress,
    _HydrationViewData? data,
  ) {
    final consumedMl = data?.consumedMl ?? 0;
    final percent = (animProgress * 100).round();

    return ObGlass(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          SizedBox(
            width: 192,
            height: 192,
            child: CustomPaint(
              painter: _WaterRingPainter(
                progress: animProgress,
                strokeWidth: 20,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.droplets,
                      size: 26,
                      color: _kWaterFill.withValues(
                        alpha: 0.7 + 0.3 * animProgress,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percent%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _kWaterDark,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _levelLabel(percent),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _kWaterFill,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statCol(theme, '${consumedMl}ml', 'Consumed', _kWaterFill),
              _verticalDivider(),
              _statCol(theme, '1500ml', 'Target', ObTokens.textMuted),
              _verticalDivider(),
              _statCol(
                theme,
                '${data?.remainingMl ?? 1500}ml',
                'Remaining',
                (data?.remainingMl ?? 1) == 0
                    ? ObTokens.mintDeep
                    : ObTokens.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCol(
    ThemeData theme,
    String value,
    String label,
    Color valueColor,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: ObTokens.textMuted),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 36,
      width: 1,
      color: Colors.black.withValues(alpha: 0.07),
    );
  }

  Widget _buildDoseDots(ThemeData theme, _HydrationViewData? data) {
    final doneCount = data?.todayEntries.length ?? 0;
    return ObGlass(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(LucideIcons.activity, size: 16, color: _kWaterFill),
          const SizedBox(width: 8),
          Text(
            'Daily Doses',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: ObTokens.text,
            ),
          ),
          const Spacer(),
          Row(
            children: List.generate(_maxDoseCount, (i) {
              final done = i < doneCount;
              return Padding(
                padding: const EdgeInsets.only(left: 7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: done
                        ? _kWaterFill.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    LucideIcons.droplets,
                    size: 16,
                    color: done
                        ? _kWaterFill
                        : _kWaterBg.withValues(alpha: 0.8),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSipCard(ThemeData theme, _HydrationViewData? data) {
    final next = data?.nextPlanned;
    final isDone = next == null && data != null;

    return ObGlass(
      tint: isDone ? ObTokens.mint : _kWaterLight,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDone
                    ? [ObTokens.mintDeep, const Color(0xFF22C55E)]
                    : [_kWaterLight, _kWaterDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isDone ? ObTokens.mintDeep : _kWaterFill).withValues(
                    alpha: 0.30,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isDone ? LucideIcons.checkCircle : LucideIcons.clock,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next Sip',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: ObTokens.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data == null
                    ? '—'
                    : isDone
                    ? 'All done for today!'
                    : _formatTime(next!),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDone ? ObTokens.mintDeep : _kWaterDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ThemeData theme, _HydrationViewData? data) {
    final entries = data?.todayEntries ?? [];
    return ObGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 16, color: _kWaterFill),
              const SizedBox(width: 8),
              Text(
                "Today's Sips",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ObTokens.text,
                ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kWaterFill.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${entries.length}/$_maxDoseCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _kWaterFill,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.droplets,
                    size: 20,
                    color: _kWaterBg.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'No water logged yet today.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ObTokens.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            ...entries.asMap().entries.map((e) {
              final displayIndex = entries.length - e.key;
              return _SipEntryRow(
                index: displayIndex,
                entry: e.value,
                formatTime: _formatTime,
                theme: theme,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(ThemeData theme, _HydrationViewData? data) {
    final times = data?.plannedTimes ?? [];
    final now = DateTime.now();

    return ObGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 16, color: _kWaterFill),
              const SizedBox(width: 8),
              Text(
                "Today's Schedule",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ObTokens.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (times.isEmpty)
            Text(
              'No planned slots based on your office schedule.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ObTokens.textMuted,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: times
                  .map((t) {
                    final isPast = t.isBefore(now);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isPast
                            ? _kWaterFill.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPast
                              ? _kWaterFill.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPast
                                ? LucideIcons.checkCircle
                                : LucideIcons.clock,
                            size: 12,
                            color: isPast ? _kWaterFill : ObTokens.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatTime(t),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isPast ? _kWaterDark : ObTokens.textMuted,
                              fontWeight: isPast
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

// ── Sip entry row ─────────────────────────────────────────────────────────────

class _SipEntryRow extends StatelessWidget {
  const _SipEntryRow({
    required this.index,
    required this.entry,
    required this.formatTime,
    required this.theme,
  });

  final int index;
  final _DrinkEntry entry;
  final String Function(DateTime) formatTime;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kWaterLight, _kWaterFill],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: _kWaterFill.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$index',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatTime(entry.time),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: ObTokens.text,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kWaterFill.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${entry.ml} mL',
              style: theme.textTheme.labelMedium?.copyWith(
                color: _kWaterDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Water ring custom painter ─────────────────────────────────────────────────

class _WaterRingPainter extends CustomPainter {
  const _WaterRingPainter({required this.progress, required this.strokeWidth});

  final double progress;
  final double strokeWidth;

  // Arc spans 270° starting at the 7:30 position (135° = 3π/4)
  static const double _startAngle = pi * 0.75;
  static const double _sweepAngle = pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = _kWaterBg
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    final sweep = _sweepAngle * progress.clamp(0.0, 1.0);

    // Filled arc
    canvas.drawArc(
      rect,
      _startAngle,
      sweep,
      false,
      Paint()
        ..color = _kWaterFill
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Glow dot at arc tip
    if (progress > 0.03) {
      final tipAngle = _startAngle + sweep;
      final tipX = center.dx + radius * cos(tipAngle);
      final tipY = center.dy + radius * sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY),
        strokeWidth / 2 + 1,
        Paint()
          ..color = _kWaterLight.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
  }

  @override
  bool shouldRepaint(_WaterRingPainter old) => old.progress != progress;
}

// ── Data classes ──────────────────────────────────────────────────────────────

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
