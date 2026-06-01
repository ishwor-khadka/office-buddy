import 'package:flutter/material.dart';
import '../../../core/ui/ui_refresh_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../../core/data/database_helper.dart';
import '../../../core/exercises/exercise.dart';
import '../../../core/exercises/exercise_animation.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';
import '../../../core/tracking/tracking_repository.dart';

Color _bodyPartColor(String bodyPart) => switch (bodyPart) {
  'Neck' => ObTokens.iris,
  'Back' => ObTokens.mintDeep,
  'Wrist' => ObTokens.sky,
  'Eyes' => const Color(0xFFF59E0B),
  _ => ObTokens.iris,
};

IconData _bodyPartIcon(String bodyPart) => switch (bodyPart) {
  'Neck' => LucideIcons.alignCenterVertical,
  'Back' => LucideIcons.moveVertical,
  'Wrist' => LucideIcons.hand,
  'Eyes' => LucideIcons.eye,
  _ => LucideIcons.dumbbell,
};

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
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
          UiRefreshBus.instance.update(this, () {
            _secondsLeft--;
          });
        } else {
          timer.cancel();
          UiRefreshBus.instance.update(this, () {
            _isPlaying = false;
            _isFinished = true;
          });
          _logCompletion();
        }
      });
    }
    UiRefreshBus.instance.update(this, () {
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
    final color = _bodyPartColor(widget.exercise.bodyPart);
    final progress = _initialSeconds > 0
        ? _secondsLeft / _initialSeconds
        : 0.0;
    final mm = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');
    final mins = (_initialSeconds / 60).ceil();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(widget.exercise.title)),
      body: ObBackground(
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.14),
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (color == ObTokens.iris
                          ? ObTokens.mintDeep
                          : ObTokens.iris)
                      .withValues(alpha: 0.12),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroCard(theme, color, mins)
                        .animate()
                        .fade(duration: 320.ms)
                        .slideY(begin: -0.04),
                    const SizedBox(height: 16),
                    _buildTimerCard(
                      theme,
                      color,
                      progress,
                      mm,
                      ss,
                    ).animate().fade(duration: 360.ms, delay: 60.ms),
                    const SizedBox(height: 16),
                    _buildInstructionsCard(theme, color)
                        .animate()
                        .fade(duration: 360.ms, delay: 120.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme, Color color, int mins) {
    return ObGlass(
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.10)],
              ),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: ExerciseAnimation(
              bodyPart: widget.exercise.bodyPart,
              isPlaying: _isPlaying && !_isFinished,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exercise.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ObTokens.text,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _Badge(
                      label: widget.exercise.bodyPart,
                      color: color,
                      icon: _bodyPartIcon(widget.exercise.bodyPart),
                    ),
                    _Badge(
                      label: '$mins min',
                      color: ObTokens.textMuted,
                      icon: LucideIcons.clock,
                    ),
                    _Badge(
                      label: widget.exercise.difficulty,
                      color: widget.exercise.difficulty == 'Easy'
                          ? ObTokens.mintDeep
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(
    ThemeData theme,
    Color color,
    double progress,
    String mm,
    String ss,
  ) {
    return ObGlass(
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _RingPainter(
                    progress: _isFinished ? 1.0 : progress,
                    color: _isFinished ? ObTokens.mintDeep : color,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isFinished) ...[
                      Icon(
                        LucideIcons.checkCircle,
                        size: 40,
                        color: ObTokens.mintDeep,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Done!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: ObTokens.mintDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else ...[
                      Text(
                        '$mm:$ss',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 52,
                          color: ObTokens.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPlaying ? 'Keep going' : 'Ready?',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!_isFinished) ...[
            Text(
              'Maintain a relaxed jaw and steady breath.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _PlayPauseButton(
              isPlaying: _isPlaying,
              color: color,
              onTap: _toggleTimer,
            ),
          ] else ...[
            Text(
              'Logged. Come back any time for another quick reset.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ObTokens.mintDeep, ObTokens.sky],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.checkCircle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'All Done',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(ThemeData theme, Color color) {
    return ObGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.list, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                'Instructions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ObTokens.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...widget.exercise.instructions.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.9),
                          (color == ObTokens.iris ? ObTokens.sky : color)
                              .withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(step, style: theme.textTheme.bodyLarge),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.color,
    required this.onTap,
  });

  final bool isPlaying;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondColor = color == ObTokens.iris ? ObTokens.sky : ObTokens.iris;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isPlaying
                ? [secondColor, color]
                : [color, secondColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? LucideIcons.pause : LucideIcons.play,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final fgPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + 2 * math.pi,
          colors: [
            color,
            color == ObTokens.iris ? ObTokens.sky : ObTokens.iris,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
