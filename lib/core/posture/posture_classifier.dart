import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum PostureResult {
  good,
  needsCorrection,
}

enum PostureIssueType {
  none,
  techNeck,
  roundedShoulders,
  lateralTilt,
}

class PostureClassification {
  const PostureClassification({
    required this.result,
    required this.issueType,
    required this.confidenceNote,
  });

  final PostureResult result;
  final PostureIssueType issueType;
  final String confidenceNote;
}

class PostureClassifier {
  // These heuristics are intentionally conservative; posture is hard to classify
  // from a single frame without calibration. This gives a useful MVP signal.
  static PostureClassification classify(Pose pose) {
    final lm = pose.landmarks;
    final leftShoulder = lm[PoseLandmarkType.leftShoulder];
    final rightShoulder = lm[PoseLandmarkType.rightShoulder];
    final nose = lm[PoseLandmarkType.nose];
    final leftEar = lm[PoseLandmarkType.leftEar];
    final rightEar = lm[PoseLandmarkType.rightEar];

    if (leftShoulder == null ||
        rightShoulder == null ||
        nose == null ||
        (leftEar == null && rightEar == null)) {
      return const PostureClassification(
        result: PostureResult.needsCorrection,
        issueType: PostureIssueType.none,
        confidenceNote: 'Low confidence: landmarks missing.',
      );
    }

    final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final shoulderWidth =
        (leftShoulder.x - rightShoulder.x).abs().clamp(1.0, 99999.0);

    // Lateral tilt: shoulders not level.
    final shoulderTilt =
        (leftShoulder.y - rightShoulder.y).abs() / shoulderWidth;
    if (shoulderTilt > 0.12) {
      return const PostureClassification(
        result: PostureResult.needsCorrection,
        issueType: PostureIssueType.lateralTilt,
        confidenceNote: 'Shoulders look uneven.',
      );
    }

    // Correct ear mid-Y: when only one ear is visible, use it directly.
    // (Previous formula added ear.x + nose.x and divided by 1.0 — a sum, not an average.)
    final double earMidY = (leftEar != null && rightEar != null)
        ? (leftEar.y + rightEar.y) / 2.0
        : (leftEar ?? rightEar)!.y;

    // Tech neck (front camera): when head cranes forward the ears drop toward
    // shoulder level. Y increases downward, so in good posture shoulderMidY > earMidY.
    // neckRatio = how many shoulder-widths the ears sit above the shoulders.
    // Typical healthy range: 0.40–0.90. Below 0.28 → forward-head posture.
    final neckRatio = (shoulderMidY - earMidY) / shoulderWidth;
    if (neckRatio < 0.28) {
      return const PostureClassification(
        result: PostureResult.needsCorrection,
        issueType: PostureIssueType.techNeck,
        confidenceNote: 'Head appears forward relative to shoulders.',
      );
    }

    // Rounded shoulders / slouch: nose drops toward shoulder level.
    // noseAbove = how many shoulder-widths the nose sits above the shoulder line.
    // Typical healthy range: 0.55–1.10. Below 0.40 → slouching.
    final noseAbove = (shoulderMidY - nose.y) / shoulderWidth;
    if (noseAbove < 0.40) {
      return const PostureClassification(
        result: PostureResult.needsCorrection,
        issueType: PostureIssueType.roundedShoulders,
        confidenceNote: 'Upper body looks slouched.',
      );
    }

    return const PostureClassification(
      result: PostureResult.good,
      issueType: PostureIssueType.none,
      confidenceNote: 'Looks aligned.',
    );
  }

  static String issueLabel(PostureIssueType type) {
    return switch (type) {
      PostureIssueType.techNeck => 'Tech Neck',
      PostureIssueType.roundedShoulders => 'Rounded Shoulders',
      PostureIssueType.lateralTilt => 'Lateral Tilt',
      PostureIssueType.none => 'Good posture',
    };
  }
}
