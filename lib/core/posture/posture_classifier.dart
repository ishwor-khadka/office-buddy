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

    final shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs().clamp(1.0, 99999.0);

    // Lateral tilt: shoulders not level.
    final shoulderTilt = (leftShoulder.y - rightShoulder.y).abs() / shoulderWidth;
    if (shoulderTilt > 0.12) {
      return const PostureClassification(
        result: PostureResult.needsCorrection,
        issueType: PostureIssueType.lateralTilt,
        confidenceNote: 'Shoulders look uneven.',
      );
    }

    // Tech neck: head (nose/ear) is significantly forward from shoulder midpoint.
    final headX = ((leftEar?.x ?? nose.x) + (rightEar?.x ?? nose.x)) /
        ((leftEar != null && rightEar != null) ? 2.0 : 1.0);
    final forward = (headX - shoulderMidX).abs() / shoulderWidth;

    if (forward > 0.22) {
      return const PostureClassification(
        result: PostureResult.needsCorrection,
        issueType: PostureIssueType.techNeck,
        confidenceNote: 'Head appears forward relative to shoulders.',
      );
    }

    // Rounded shoulders: shoulders are far in front of torso line (nose-mid-shoulder alignment).
    // MVP approximation: if nose is low relative to shoulders and shoulder width is narrow, user may be slouching.
    final headDrop = (nose.y - shoulderMidY) / shoulderWidth;
    if (headDrop > 0.35) {
      return const PostureClassification(
        result: PostureResult.needsCorrection,
        issueType: PostureIssueType.roundedShoulders,
        confidenceNote: 'Upper body looks slouched.',
      );
    }

    // Otherwise: good enough.
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
