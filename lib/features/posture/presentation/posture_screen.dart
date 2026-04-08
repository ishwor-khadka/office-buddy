import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'posture_painter.dart';
import '../../../core/posture/posture_classifier.dart';
import '../../../core/data/database_helper.dart';
import '../../../core/exercises/exercise_repository.dart';
import '../../../core/exercises/exercise.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/tracking/tracking_repository.dart';

class PostureScreen extends StatefulWidget {
  const PostureScreen({super.key});

  @override
  State<PostureScreen> createState() => _PostureScreenState();
}

class _PostureScreenState extends State<PostureScreen> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  String _statusMessage = 'Align yourself in frame.';
  Pose? _lastPose;
  PostureClassification? _lastClassification;
  PoseDetector? _poseDetector;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
        mode: PoseDetectionMode.single,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No camera available.');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController?.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera init failed: $e');
    }
  }

  Future<void> _analyzePosture() async {
    if (_isProcessing) return;
    final controller = _cameraController;
    final detector = _poseDetector;
    if (controller == null || detector == null) return;
    if (!controller.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing posture... Hold still.';
    });

    try {
      final pic = await controller.takePicture();
      final image = InputImage.fromFilePath(pic.path);
      final poses = await detector.processImage(image);
      final pose = poses.isNotEmpty ? poses.first : null;
      if (pose == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No pose detected. Try better lighting.';
          _lastPose = null;
          _lastClassification = null;
        });
        return;
      }

      final classification = PostureClassifier.classify(pose);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final issueType = switch (classification.issueType) {
        PostureIssueType.techNeck => 'TECH_NECK',
        PostureIssueType.roundedShoulders => 'ROUNDED_SHOULDERS',
        PostureIssueType.lateralTilt => 'LATERAL_TILT',
        PostureIssueType.none => 'NONE',
      };
      await DatabaseHelper.instance.insertPostureLog(
        timestampMillis: nowMs,
        result: classification.result == PostureResult.good
            ? 'GOOD'
            : 'NEEDS_CORRECTION',
        issueType: issueType,
        videoShown: classification.result != PostureResult.good,
      );
      await TrackingRepository.trackIfAvailable(
        type: 'posture_check',
        data: {
          'result': classification.result == PostureResult.good
              ? 'GOOD'
              : 'NEEDS_CORRECTION',
          'issue_type': issueType,
        },
      );

      setState(() {
        _isProcessing = false;
        _lastPose = pose;
        _lastClassification = classification;
        _statusMessage = PostureClassifier.issueLabel(classification.issueType);
      });

      if (!mounted) return;
      if (classification.result != PostureResult.good) {
        _showCorrectionSheet(classification.issueType);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nice posture. Keep it up.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Analysis failed. Try again.';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  Future<void> _showCorrectionSheet(PostureIssueType issueType) async {
    final repo = ExerciseRepository();
    final all = await repo.loadAll();
    final bodyPart = switch (issueType) {
      PostureIssueType.techNeck => 'Neck',
      PostureIssueType.roundedShoulders => 'Back',
      PostureIssueType.lateralTilt => 'Back',
      PostureIssueType.none => 'Neck',
    };
    final suggestions = all.where((e) => e.bodyPart == bodyPart).take(3).toList();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ObGlass(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fix now: ${PostureClassifier.issueLabel(issueType)}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Small reset, big payoff. Try one quick exercise.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final ex in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExerciseSuggestion(exercise: ex),
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_cameraController?.value.isInitialized == true)
            CameraPreview(_cameraController!)
          else
            Center(
              child: _cameraError == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _cameraError!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
            ).animate().fade(),

          // Skeleton Overlay
          if (_cameraController?.value.isInitialized == true)
            CustomPaint(
              painter: PosturePainter(pose: _lastPose),
            ).animate().fade(delay: 500.ms),

          // Scanning Overlay Magic Effect
          if (_isProcessing)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.0),
                    theme.colorScheme.primary.withOpacity(0.2),
                    theme.colorScheme.primary.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat()).slideY(
                  begin: -1,
                  end: 1,
                  duration: 2.seconds,
                  curve: Curves.linear,
                ),

          // Contextual Information Panel
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (_isProcessing)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      else
                        Icon(
                          _lastClassification?.result == PostureResult.good
                              ? LucideIcons.checkCircle2
                              : LucideIcons.alertTriangle,
                          color: _lastClassification?.result == PostureResult.good
                              ? Colors.greenAccent
                              : theme.colorScheme.error,
                          size: 28,
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _analyzePosture,
                    child: const Text('Analyze Now'),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1, duration: 400.ms),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSuggestion extends StatelessWidget {
  const _ExerciseSuggestion({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = (exercise.durationSeconds / 60).ceil();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.dumbbell, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${exercise.bodyPart} · ${exercise.difficulty} · $mins min',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
