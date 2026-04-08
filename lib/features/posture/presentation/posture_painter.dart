import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosturePainter extends CustomPainter {
  PosturePainter({
    required this.pose,
  });

  final Pose? pose;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final p = pose;
    if (p == null) return;

    final lm = p.landmarks;
    Offset? pt(PoseLandmarkType t) {
      final l = lm[t];
      if (l == null) return null;
      // This assumes landmark coordinates are already in the preview space.
      // For MVP we draw relative positions; exact mapping varies by platform/rotation.
      return Offset(l.x, l.y);
    }

    void line(PoseLandmarkType a, PoseLandmarkType b) {
      final pa = pt(a);
      final pb = pt(b);
      if (pa == null || pb == null) return;
      canvas.drawLine(pa, pb, paint);
    }

    // Basic skeleton lines.
    line(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    line(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    line(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    line(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    line(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    line(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    line(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    line(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);

    // Landmarks.
    paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 1;
    for (final l in lm.values) {
      canvas.drawCircle(Offset(l.x, l.y), 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PosturePainter oldDelegate) => oldDelegate.pose != pose;
}
