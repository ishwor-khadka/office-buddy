import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/database_helper.dart';
import '../../../core/tracking/tracking_repository.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  static const _kSleepStartMs = 'sleep_active_start_ms';

  int? _activeStartMs;
  bool _loading = true;
  int _weekTotalMinutes = 0;
  int _weekSessions = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final start = prefs.getInt(_kSleepStartMs);
    final since = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final totalSec = await DatabaseHelper.instance.sumSleepSecondsSince(sinceMillis: since);
    final count = await DatabaseHelper.instance.countSleepLogsSince(sinceMillis: since);
    if (!mounted) return;
    setState(() {
      _activeStartMs = start;
      _weekTotalMinutes = (totalSec / 60).round();
      _weekSessions = count;
      _loading = false;
    });
  }

  Future<void> _startSleep() async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_kSleepStartMs, nowMs);
    await TrackingRepository.trackIfAvailable(
      type: 'sleep_started',
      data: {'start_ms': nowMs},
    );
    if (!mounted) return;
    setState(() => _activeStartMs = nowMs);
  }

  Future<void> _stopSleep() async {
    final startMs = _activeStartMs;
    if (startMs == null) return;
    final prefs = await SharedPreferences.getInstance();
    final endMs = DateTime.now().millisecondsSinceEpoch;
    final durSec = ((endMs - startMs) / 1000).round().clamp(0, 9999999);

    await prefs.remove(_kSleepStartMs);
    await DatabaseHelper.instance.insertSleepLog(
      startMillis: startMs,
      endMillis: endMs,
      durationSeconds: durSec,
      quality: null,
    );
    await TrackingRepository.trackIfAvailable(
      type: 'sleep_ended',
      data: {'start_ms': startMs, 'end_ms': endMs, 'duration_seconds': durSec},
    );
    if (!mounted) return;
    setState(() => _activeStartMs = null);
    await _load();
  }

  String _fmtDurationFromStart(int startMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sec = ((now - startMs) / 1000).floor().clamp(0, 999999);
    final h = (sec ~/ 3600);
    final m = (sec % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Sleep')),
      body: ObBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ObGlass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('This week', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 10),
                            _Metric(
                              label: 'Total sleep',
                              value: '${_weekTotalMinutes}m',
                            ),
                            const SizedBox(height: 8),
                            _Metric(
                              label: 'Sessions',
                              value: '$_weekSessions',
                            ),
                            const SizedBox(height: 8),
                            _Metric(
                              label: 'Avg per session',
                              value: _weekSessions == 0
                                  ? '0m'
                                  : '${(_weekTotalMinutes / _weekSessions).round()}m',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ObGlass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sleep tracker', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 10),
                            Text(
                              _activeStartMs == null
                                  ? 'Tap start when you go to bed. Tap stop when you wake up.'
                                  : 'Tracking: ${_fmtDurationFromStart(_activeStartMs!)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            if (_activeStartMs == null)
                              ElevatedButton(
                                onPressed: _startSleep,
                                child: const Text('Start sleep'),
                              )
                            else
                              ElevatedButton(
                                onPressed: _stopSleep,
                                child: const Text('Stop sleep'),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              'Note: phone-only sleep stage detection (REM/deep) is not reliable. This screen tracks time and patterns.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

