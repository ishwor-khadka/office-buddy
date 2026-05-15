import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/data/database_helper.dart';
import '../../../core/exercises/exercise.dart';
import '../../../core/exercises/exercise_repository.dart';
import '../../exercises/presentation/exercise_detail_screen.dart';
import '../../../core/posture/posture_classifier.dart';
import '../../../core/tracking/tracking_repository.dart';

class PostureScreen extends StatefulWidget {
  const PostureScreen({super.key});

  @override
  State<PostureScreen> createState() => _PostureScreenState();
}

enum _PostureUiState { intro, scanning, result }

class _PostureScreenState extends State<PostureScreen>
    with SingleTickerProviderStateMixin {
  static const _introImageUrl =
      'https://www.figma.com/api/mcp/asset/cb146a83-a0d3-422d-803a-33e3074a271f';

  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  late final AnimationController _scanLineController;
  Timer? _progressTimer;

  _PostureUiState _uiState = _PostureUiState.intro;
  Uint8List? _capturedImageBytes;
  String? _cameraError;

  bool _isProcessing = false;
  bool _isInitializingCamera = false;
  double _scanProgress = 0.08;
  String _statusMessage = 'Preparing scan...';

  PostureClassification? _lastClassification;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
        mode: PoseDetectionMode.single,
      ),
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  Future<void> _ensureCameraReady() async {
    if (_cameraController?.value.isInitialized == true ||
        _isInitializingCamera) {
      return;
    }

    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'No camera available on this device.');
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera init failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializingCamera = false);
      }
    }
  }

  Future<void> _startCameraScan() async {
    setState(() {
      _uiState = _PostureUiState.scanning;
      _statusMessage = 'Preparing scan...';
      _capturedImageBytes = null;
      _lastClassification = null;
      _cameraError = null;
    });

    await _ensureCameraReady();
    if (!mounted) return;
    if (_cameraController?.value.isInitialized != true) return;

    await _runPostureAnalysis();
  }

  void _startProgressSimulation() {
    _progressTimer?.cancel();
    _scanProgress = 0.08;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || !_isProcessing) return;
      setState(() {
        _scanProgress = (_scanProgress + 0.012).clamp(0.08, 0.92);
      });
    });
  }

  String _issueCode(PostureIssueType issueType) {
    return switch (issueType) {
      PostureIssueType.techNeck => 'TECH_NECK',
      PostureIssueType.roundedShoulders => 'ROUNDED_SHOULDERS',
      PostureIssueType.lateralTilt => 'LATERAL_TILT',
      PostureIssueType.none => 'NONE',
    };
  }

  Future<void> _persistClassification(
    PostureClassification classification,
  ) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final issueType = _issueCode(classification.issueType);
    final result = classification.result == PostureResult.good
        ? 'GOOD'
        : 'NEEDS_CORRECTION';

    await DatabaseHelper.instance.insertPostureLog(
      timestampMillis: nowMs,
      result: result,
      issueType: issueType,
      videoShown: classification.result != PostureResult.good,
    );
    await TrackingRepository.trackIfAvailable(
      type: 'posture_check',
      data: {'result': result, 'issue_type': issueType},
    );
  }

  Future<void> _runPostureAnalysis() async {
    if (_isProcessing) return;
    final controller = _cameraController;
    final detector = _poseDetector;
    if (controller == null || detector == null) return;
    if (!controller.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing alignment...';
      _scanProgress = 0.08;
      _cameraError = null;
    });
    _startProgressSimulation();

    final startedAt = DateTime.now();

    try {
      final picture = await controller.takePicture();
      final capturedBytes = await picture.readAsBytes();
      if (mounted) {
        setState(() => _capturedImageBytes = capturedBytes);
      }

      final image = InputImage.fromFilePath(picture.path);
      final poses = await detector.processImage(image);
      final pose = poses.isNotEmpty ? poses.first : null;

      final classification = pose == null
          ? const PostureClassification(
              result: PostureResult.needsCorrection,
              issueType: PostureIssueType.none,
              confidenceNote: 'No body landmarks detected.',
            )
          : PostureClassifier.classify(pose);

      await _persistClassification(classification);

      const minimumScanDuration = Duration(seconds: 7);
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minimumScanDuration) {
        await Future.delayed(minimumScanDuration - elapsed);
      }

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _scanProgress = 1.0;
        _lastClassification = classification;
        _statusMessage = pose == null
            ? 'No posture detected. Move into frame and retry.'
            : PostureClassifier.issueLabel(classification.issueType);
        _uiState = _PostureUiState.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _scanProgress = 0.08;
        _cameraError = 'Analysis failed. Please try again.';
      });
    } finally {
      _progressTimer?.cancel();
    }
  }

  Future<void> _rescan() async {
    setState(() {
      _uiState = _PostureUiState.scanning;
      _capturedImageBytes = null;
      _cameraError = null;
      _lastClassification = null;
    });
    await _ensureCameraReady();
    if (!mounted) return;
    if (_cameraController?.value.isInitialized != true) return;
    await _runPostureAnalysis();
  }

  Future<List<Exercise>> _getSuggestedExercises(
    PostureIssueType issueType,
  ) async {
    final repo = ExerciseRepository();
    final all = await repo.loadAll();
    final bodyPart = switch (issueType) {
      PostureIssueType.techNeck => 'Neck',
      PostureIssueType.roundedShoulders => 'Back',
      PostureIssueType.lateralTilt => 'Back',
      PostureIssueType.none => 'Neck',
    };
    final matches = all.where((e) => e.bodyPart == bodyPart).toList()
      ..shuffle(Random());
    return matches.take(3).toList();
  }

  Future<void> _showCorrectionSheet(PostureIssueType issueType) async {
    final suggestions = await _getSuggestedExercises(issueType);

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended Exercises',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quick movements to correct posture and reduce fatigue.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF62748E),
                  ),
                ),
                const SizedBox(height: 12),
                for (final ex in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExerciseSuggestion(
                      exercise: ex,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ExerciseDetailScreen(exercise: ex),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008236),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Done'),
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
  void dispose() {
    _progressTimer?.cancel();
    _scanLineController.dispose();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  _ResultContent _buildResultContent(PostureClassification? classification) {
    if (classification == null) {
      return const _ResultContent(
        score: 58,
        badge: 'LOW CONFIDENCE',
        headline: 'Could not verify posture',
        description:
            'Move back so your upper body is visible and rescan in brighter lighting.',
        observations: [
          _ResultObservation(
            title: 'Body landmarks missing',
            description:
                'We could not detect enough shoulder and head points to classify posture.',
            tone: _ObservationTone.warning,
          ),
          _ResultObservation(
            title: 'Scanner is ready',
            description: 'Camera and ML pipeline are active. Try another scan.',
            tone: _ObservationTone.positive,
          ),
        ],
        actions: [
          _ResultAction(
            step: '1',
            title: 'Align Camera to Eye Level',
            description:
                'Keep your head, shoulders, and torso centered in frame.',
          ),
          _ResultAction(
            step: '2',
            title: 'Improve Ambient Lighting',
            description:
                'Use front lighting so body landmarks are easier to track.',
          ),
        ],
      );
    }

    if (classification.result == PostureResult.good) {
      return const _ResultContent(
        score: 92,
        badge: 'GOOD POSTURE',
        headline: 'Great ergonomic alignment',
        description:
            'Your head, shoulders, and trunk are close to neutral posture. Keep this setup.',
        observations: [
          _ResultObservation(
            title: 'Head and neck alignment',
            description:
                'Forward-head angle is within a healthy range for desk posture.',
            tone: _ObservationTone.positive,
          ),
          _ResultObservation(
            title: 'Shoulder balance',
            description:
                'Shoulder level is stable with minimal side tilt under current conditions.',
            tone: _ObservationTone.positive,
          ),
        ],
        actions: [
          _ResultAction(
            step: '1',
            title: 'Maintain Monitor Height',
            description:
                'Keep the top of the display at eye level to preserve neck neutrality.',
          ),
          _ResultAction(
            step: '2',
            title: 'Micro-break Every 30–45 min',
            description: 'Stand or stretch briefly to avoid fatigue buildup.',
          ),
        ],
      );
    }

    switch (classification.issueType) {
      case PostureIssueType.techNeck:
        return const _ResultContent(
          score: 72,
          badge: 'FAIR POSTURE',
          headline: 'Needs slight adjustment',
          description:
              'Lower back support looks stable, but we detected forward head posture that may cause fatigue.',
          observations: [
            _ResultObservation(
              title: 'Forward Head Posture',
              description:
                  'Your neck appears angled forward relative to your shoulder baseline.',
              tone: _ObservationTone.warning,
            ),
            _ResultObservation(
              title: 'Good Lumbar Support',
              description:
                  'Lower back position appears consistent against the chair back.',
              tone: _ObservationTone.positive,
            ),
          ],
          actions: [
            _ResultAction(
              step: '1',
              title: 'Raise Monitor by 3"',
              description:
                  'Align the top of your screen to eye level to reduce neck load.',
            ),
            _ResultAction(
              step: '2',
              title: 'Chin Tucks Exercise',
              description:
                  'Use a short 1–2 minute chin tuck set to reset cervical alignment.',
            ),
          ],
        );
      case PostureIssueType.roundedShoulders:
        return const _ResultContent(
          score: 68,
          badge: 'FAIR POSTURE',
          headline: 'Upper body is slouching',
          description:
              'Shoulder line and head position suggest rounded shoulders and reduced thoracic extension.',
          observations: [
            _ResultObservation(
              title: 'Rounded Shoulder Pattern',
              description:
                  'Shoulders appear protracted, which can increase upper-back strain.',
              tone: _ObservationTone.warning,
            ),
            _ResultObservation(
              title: 'Pelvic base is stable',
              description:
                  'Seated base remains reasonably stable, which helps correction efforts.',
              tone: _ObservationTone.positive,
            ),
          ],
          actions: [
            _ResultAction(
              step: '1',
              title: 'Open Chest and Retract Scapula',
              description:
                  'Perform 8–10 slow shoulder blade squeezes every hour.',
            ),
            _ResultAction(
              step: '2',
              title: 'Thoracic Extension Drill',
              description:
                  'Try a 2-minute extension mobility movement to restore posture.',
            ),
          ],
        );
      case PostureIssueType.lateralTilt:
        return const _ResultContent(
          score: 70,
          badge: 'FAIR POSTURE',
          headline: 'Posture is slightly imbalanced',
          description:
              'Shoulders are uneven side-to-side, which may indicate sustained lateral lean.',
          observations: [
            _ResultObservation(
              title: 'Shoulder Imbalance',
              description:
                  'Left-right shoulder heights differ more than neutral ergonomic range.',
              tone: _ObservationTone.warning,
            ),
            _ResultObservation(
              title: 'Head position mostly centered',
              description:
                  'Head-forward displacement appears moderate despite side tilt.',
              tone: _ObservationTone.positive,
            ),
          ],
          actions: [
            _ResultAction(
              step: '1',
              title: 'Center Keyboard and Mouse',
              description:
                  'Keep input devices close to midline to avoid unilateral leaning.',
            ),
            _ResultAction(
              step: '2',
              title: 'Seated Side Stretch',
              description:
                  'Do 1–2 minutes of gentle side stretching on both sides.',
            ),
          ],
        );
      case PostureIssueType.none:
        return const _ResultContent(
          score: 64,
          badge: 'LOW CONFIDENCE',
          headline: 'Need a clearer scan',
          description:
              'We could not confidently classify posture. Keep your full torso visible and rescan.',
          observations: [
            _ResultObservation(
              title: 'Landmark confidence is low',
              description:
                  'Head or shoulder points were partially occluded during capture.',
              tone: _ObservationTone.warning,
            ),
            _ResultObservation(
              title: 'Scan completed on-device',
              description:
                  'The analysis ran locally with no cloud image upload required.',
              tone: _ObservationTone.positive,
            ),
          ],
          actions: [
            _ResultAction(
              step: '1',
              title: 'Sit Inside the Frame',
              description:
                  'Make sure your full shoulders and head stay inside guide corners.',
            ),
            _ResultAction(
              step: '2',
              title: 'Keep Still for 2 seconds',
              description:
                  'Reduce motion blur so the landmark model can lock accurately.',
            ),
          ],
        );
    }
  }

  Widget _buildIntroView(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            LucideIcons.x,
                            color: Color(0xFF1D293D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF0FDF4),
                      border: Border.all(
                        color: const Color(0xFFDCFCE7),
                        width: 1.3,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 34,
                      color: Color(0xFF008236),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Smart Ergonomic Scan',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Position your device to analyze your workspace. We'll identify areas for improvement in seconds.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF45556C),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 282,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _introImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: const Color(0xFFE2E8F0),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 44,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0),
                                  Colors.black.withValues(alpha: 0),
                                  Colors.black.withValues(alpha: 0.62),
                                ],
                                stops: const [0.0, 0.52, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    color: Color(0xFF00A63E),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Secure & private. Processed locally.',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1D293D),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_cameraError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _cameraError!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFB42318),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isInitializingCamera
                          ? null
                          : _startCameraScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008236),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isInitializingCamera
                                ? 'Preparing Camera...'
                                : 'Start Camera Scan',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 21),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanBackground() {
    if (_capturedImageBytes != null) {
      return Image.memory(
        _capturedImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: Colors.black),
      );
    }
    if (_cameraController?.value.isInitialized == true) {
      return CameraPreview(_cameraController!);
    }
    if (_isInitializingCamera) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _cameraError!,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildScanningView(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildScanBackground(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          const _LiveFrameOverlay(),
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _RoundOverlayButton(
                  icon: LucideIcons.x,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, child) {
              final y = lerpDouble(-1, 1, _scanLineController.value) ?? 0;
              return Align(
                alignment: Alignment(0, y),
                child: IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF00C950).withValues(alpha: 0.88),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF22C55E,
                          ).withValues(alpha: 0.45),
                          blurRadius: 22,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'SYSTEM STATUS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF62748E),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _isProcessing ? 'SCAN_ACTIVE' : 'COMPLETE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF00A63E),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.track_changes_rounded,
                          color: Color(0xFF00A63E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _isProcessing
                              ? 'Analyzing alignment...'
                              : _statusMessage,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF0F172B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _isProcessing ? _scanProgress : 1,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF00A63E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context) {
    final theme = Theme.of(context);
    final result = _buildResultContent(_lastClassification);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF64748B),
          ),
        ),
        title: Text(
          'Analysis Results',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: _isProcessing ? null : _rescan,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF008236),
              side: const BorderSide(color: Color(0xFFB9F8CF), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Rescan'),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    border: Border.all(
                      color: const Color(0xFFB9F8CF),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 132,
                        height: 132,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 132,
                              height: 132,
                              child: CircularProgressIndicator(
                                value: result.score / 100,
                                strokeWidth: 8,
                                backgroundColor: const Color(0xFFD9E4DD),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF008236),
                                ),
                              ),
                            ),
                            Container(
                              width: 96,
                              height: 96,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0FDF4),
                                shape: BoxShape.circle,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${result.score}',
                                          style: const TextStyle(
                                            color: Color(0xFF008236),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 34,
                                            height: 1.0,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: '%',
                                          style: TextStyle(
                                            color: Color(0xFF008236),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SCORE',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(
                                        0xFF00A63E,
                                      ).withValues(alpha: 0.75),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFB9F8CF,
                          ).withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          result.badge,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF016630),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.headline,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0F172B),
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF45556C),
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.check_box_outlined,
                      size: 20,
                      color: Color(0xFF00A63E),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Key Observations',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final obs in result.observations) ...[
                  _ObservationCard(observation: obs),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Text(
                  'Recommended Actions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172B),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < result.actions.length; i++) ...[
                        _ActionRow(action: result.actions[i]),
                        if (i != result.actions.length - 1)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFE2E8F0),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Analysis uses on-device ML Kit pose detection with ergonomic thresholds inspired by occupational health research for neutral spine and shoulder alignment.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF62748E),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.96),
                    Colors.white,
                  ],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => _showCorrectionSheet(
                    _lastClassification?.issueType ?? PostureIssueType.none,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008236),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Exercises',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 21),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_uiState) {
      _PostureUiState.intro => _buildIntroView(context),
      _PostureUiState.scanning => _buildScanningView(context),
      _PostureUiState.result => _buildResultView(context),
    };
  }
}

class _ExerciseSuggestion extends StatelessWidget {
  const _ExerciseSuggestion({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = (exercise.durationSeconds / 60).ceil();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.dumbbell,
                color: Color(0xFF475467),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF0F172B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${exercise.bodyPart} · ${exercise.difficulty} · $mins min',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF62748E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _LiveFrameOverlay extends StatelessWidget {
  const _LiveFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
            ),
            const _FrameCorner(alignment: Alignment.topLeft),
            const _FrameCorner(alignment: Alignment.topRight),
            const _FrameCorner(alignment: Alignment.bottomLeft),
            const _FrameCorner(alignment: Alignment.bottomRight),
            const Center(child: _SpineGuide()),
          ],
        ),
      ),
    );
  }
}

class _FrameCorner extends StatelessWidget {
  const _FrameCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(20) : Radius.zero,
            topRight: isTop && !isLeft
                ? const Radius.circular(20)
                : Radius.zero,
            bottomLeft: !isTop && isLeft
                ? const Radius.circular(20)
                : Radius.zero,
            bottomRight: !isTop && !isLeft
                ? const Radius.circular(20)
                : Radius.zero,
          ),
          border: Border(
            top: isTop
                ? const BorderSide(color: Color(0xFF00C950), width: 3.4)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Color(0xFF00C950), width: 3.4)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Color(0xFF00C950), width: 3.4)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Color(0xFF00C950), width: 3.4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SpineGuide extends StatelessWidget {
  const _SpineGuide();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 8; i++) ...[
            Container(
              width: i == 0 || i == 7 ? 12 : 14,
              height: i == 0 || i == 7 ? 12 : 14,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            if (i != 7)
              Container(
                width: 4,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RoundOverlayButton extends StatelessWidget {
  const _RoundOverlayButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

enum _ObservationTone { warning, positive }

class _ResultObservation {
  const _ResultObservation({
    required this.title,
    required this.description,
    required this.tone,
  });

  final String title;
  final String description;
  final _ObservationTone tone;
}

class _ResultAction {
  const _ResultAction({
    required this.step,
    required this.title,
    required this.description,
  });

  final String step;
  final String title;
  final String description;
}

class _ResultContent {
  const _ResultContent({
    required this.score,
    required this.badge,
    required this.headline,
    required this.description,
    required this.observations,
    required this.actions,
  });

  final int score;
  final String badge;
  final String headline;
  final String description;
  final List<_ResultObservation> observations;
  final List<_ResultAction> actions;
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.observation});

  final _ResultObservation observation;

  @override
  Widget build(BuildContext context) {
    final isPositive = observation.tone == _ObservationTone.positive;
    final iconBg = isPositive
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF3C7);
    final iconColor = isPositive
        ? const Color(0xFF00A63E)
        : const Color(0xFFD97706);
    final icon = isPositive
        ? LucideIcons.checkCircle2
        : LucideIcons.alertTriangle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  observation.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  observation.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF45556C),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final _ResultAction action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              action.step,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF90A1B9),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0F172B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF62748E),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
            size: 24,
          ),
        ],
      ),
    );
  }
}
