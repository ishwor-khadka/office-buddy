import 'dart:math' as math;

import 'package:flutter/material.dart';

class ExerciseAnimation extends StatefulWidget {
  const ExerciseAnimation({
    super.key,
    required this.bodyPart,
    this.isPlaying = true,
  });

  final String bodyPart; // Neck, Back, Wrist, Eyes
  final bool isPlaying;

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ExerciseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.isPlaying && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return CustomPaint(
          painter: _StickFigurePainter(
            progress: t,
            bodyPart: widget.bodyPart,
            accentA: theme.colorScheme.primary,
            accentB: theme.colorScheme.secondary,
          ),
        );
      },
    );
  }
}

class _StickFigurePainter extends CustomPainter {
  _StickFigurePainter({
    required this.progress,
    required this.bodyPart,
    required this.accentA,
    required this.accentB,
  });

  final double progress;
  final String bodyPart;
  final Color accentA;
  final Color accentB;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = math.min(size.width, size.height) / 260.0;

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF0B1B14).withValues(alpha: 0.75);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16 * scale
      ..strokeCap = StrokeCap.round
      ..color = accentA.withValues(alpha: 0.28);

    // Figure base points.
    final headR = 22 * scale;
    final neck = center.translate(0, -55 * scale);
    final head = neck.translate(0, -28 * scale);
    final chest = center.translate(0, -20 * scale);
    final hip = center.translate(0, 55 * scale);

    // Animation parameters by module.
    final neckTilt = (progress - 0.5) * 2.0; // -1..1
    final armSwing = math.sin(progress * math.pi) * 1.0; // 0..1..0
    final wristRotate = (progress - 0.5) * 2.0;
    final eyeFocus = math.sin(progress * math.pi * 2) * 0.5;

    double headAngle = 0;
    double torsoAngle = 0;
    double leftArmAngle = -0.6;
    double rightArmAngle = 0.6;
    double leftForearmAngle = 0.4;
    double rightForearmAngle = -0.4;

    switch (bodyPart) {
      case 'Neck':
        headAngle = 0.35 * neckTilt;
        break;
      case 'Back':
        torsoAngle = 0.22 * neckTilt;
        headAngle = 0.12 * neckTilt;
        break;
      case 'Wrist':
        leftForearmAngle = 0.6 + 0.35 * wristRotate;
        rightForearmAngle = -0.6 - 0.35 * wristRotate;
        break;
      case 'Eyes':
        headAngle = 0.08 * eyeFocus;
        break;
      default:
        break;
    }

    // Joints distances.
    final shoulderW = 60 * scale;
    final upperArm = 65 * scale;
    final forearm = 55 * scale;
    final upperLeg = 70 * scale;
    final lowerLeg = 65 * scale;

    // Torso rotation around chest.
    Offset rot(Offset pt, Offset origin, double a) {
      final s = math.sin(a);
      final c = math.cos(a);
      final x = pt.dx - origin.dx;
      final y = pt.dy - origin.dy;
      return Offset(origin.dx + x * c - y * s, origin.dy + x * s + y * c);
    }

    final chestR = rot(chest, chest, torsoAngle);
    final hipR = rot(hip, chest, torsoAngle);
    final neckR = rot(neck, chest, torsoAngle);
    final headCenter = rot(head, neckR, headAngle);

    final leftShoulder = chestR.translate(-shoulderW, 0);
    final rightShoulder = chestR.translate(shoulderW, 0);

    // Legs (stable stance).
    final leftHip = hipR.translate(-22 * scale, 0);
    final rightHip = hipR.translate(22 * scale, 0);
    final leftKnee = leftHip.translate(-10 * scale, upperLeg);
    final rightKnee = rightHip.translate(10 * scale, upperLeg);
    final leftAnkle = leftKnee.translate(-6 * scale, lowerLeg);
    final rightAnkle = rightKnee.translate(6 * scale, lowerLeg);

    // Arms (slight breathing swing).
    final swing = (armSwing - 0.5) * 0.25;
    final la = leftArmAngle - swing;
    final ra = rightArmAngle + swing;

    Offset seg(Offset start, double len, double a) =>
        start.translate(math.cos(a) * len, math.sin(a) * len);

    final leftElbow = seg(leftShoulder, upperArm, math.pi / 2 + la);
    final rightElbow = seg(rightShoulder, upperArm, math.pi / 2 + ra);
    final leftWrist = seg(
      leftElbow,
      forearm,
      math.pi / 2 + la + leftForearmAngle,
    );
    final rightWrist = seg(
      rightElbow,
      forearm,
      math.pi / 2 + ra + rightForearmAngle,
    );

    // Draw glow accents for the focused body part.
    void glowLine(Offset a, Offset b) {
      canvas.drawLine(a, b, glow);
    }

    if (bodyPart == 'Neck') {
      glowLine(neckR, headCenter);
    } else if (bodyPart == 'Back') {
      glowLine(chestR, hipR);
    } else if (bodyPart == 'Wrist') {
      glowLine(leftElbow, leftWrist);
      glowLine(rightElbow, rightWrist);
    } else if (bodyPart == 'Eyes') {
      // A subtle halo around the head.
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * scale
        ..color = accentB.withValues(alpha: 0.25);
      canvas.drawCircle(headCenter, headR + 12 * scale, halo);
    }

    // Head
    canvas.drawCircle(headCenter, headR, p);
    // Torso
    canvas.drawLine(chestR, hipR, p);
    canvas.drawLine(leftShoulder, rightShoulder, p);
    // Arms
    canvas.drawLine(leftShoulder, leftElbow, p);
    canvas.drawLine(leftElbow, leftWrist, p);
    canvas.drawLine(rightShoulder, rightElbow, p);
    canvas.drawLine(rightElbow, rightWrist, p);
    // Legs
    canvas.drawLine(leftHip, leftKnee, p);
    canvas.drawLine(leftKnee, leftAnkle, p);
    canvas.drawLine(rightHip, rightKnee, p);
    canvas.drawLine(rightKnee, rightAnkle, p);
  }

  @override
  bool shouldRepaint(covariant _StickFigurePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bodyPart != bodyPart ||
        oldDelegate.accentA != accentA ||
        oldDelegate.accentB != accentB;
  }
}
