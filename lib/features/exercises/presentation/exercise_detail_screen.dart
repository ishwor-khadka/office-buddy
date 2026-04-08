import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import 'dart:ui';

import '../../../core/data/database_helper.dart';
import '../../../core/exercises/exercise.dart';
import '../../../core/exercises/exercise_animation.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/tracking/tracking_repository.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  ConsumerState<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  late int _secondsLeft;
  Timer? _timer;
  bool _isPlaying = false;
  bool _isFinished = false;
  int _initialSeconds = 0;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.exercise.durationSeconds;
    _initialSeconds = widget.exercise.durationSeconds;
  }

  void _toggleTimer() {
    if (_isPlaying) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft > 0) {
          setState(() {
            _secondsLeft--;
          });
        } else {
          timer.cancel();
          setState(() {
            _isPlaying = false;
            _isFinished = true;
          });
          _logCompletion();
        }
      });
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _logCompletion() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final spent = _initialSeconds;
    await DatabaseHelper.instance.insertExerciseLog(
      exerciseId: widget.exercise.id,
      bodyPart: widget.exercise.bodyPart,
      timestampMillis: nowMs,
      durationSeconds: spent,
    );
    await TrackingRepository.trackIfAvailable(
      type: 'exercise_completed',
      data: {
        'exercise_id': widget.exercise.id,
        'body_part': widget.exercise.bodyPart,
        'duration_seconds': spent,
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Convert duration to MM:SS
    final minutesUrl = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final secondsUrl = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.exercise.title),
      ),
      body: ObBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ObGlass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary.withValues(alpha: 0.28),
                                      theme.colorScheme.secondary.withValues(alpha: 0.18),
                                    ],
                                  ),
                                ),
                                child: ExerciseAnimation(
                                  bodyPart: widget.exercise.bodyPart,
                                  isPlaying: _isPlaying && !_isFinished,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.exercise.bodyPart,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.exercise.difficulty,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isFinished ? 'Great job' : '$minutesUrl:$secondsUrl',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 46,
                          color: _isFinished
                              ? const Color(0xFF0B7A4B)
                              : theme.colorScheme.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isFinished
                            ? 'Logged. Come back any time for another quick reset.'
                            : 'Maintain a relaxed jaw and steady breath.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      if (!_isFinished)
                        Align(
                          alignment: Alignment.center,
                          child: ElevatedButton(
                            onPressed: _toggleTimer,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(18),
                              shape: const CircleBorder(),
                              backgroundColor: _isPlaying
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.primary,
                            ),
                            child: Icon(
                              _isPlaying ? LucideIcons.pause : LucideIcons.play,
                              size: 30,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          child: const Text('Done'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ObGlass(
                    child: ListView.separated(
                      itemCount: widget.exercise.instructions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final step = widget.exercise.instructions[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(step, style: theme.textTheme.bodyLarge),
                            ),
                          ],
                        );
                      },
                    ),
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
