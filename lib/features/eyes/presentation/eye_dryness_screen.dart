import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Screen state enum
enum EyeTestState { intro, scanning, results }

/// Dry Eye Risk Level
enum DryEyeRiskLevel { healthy, mild, moderate, severe }

/// Result data from the eye dryness test
class EyeDrynessResult {
  final int totalBlinks;
  final double testDurationSeconds;
  final double blinksPerMinute;
  final int score;
  final DryEyeRiskLevel riskLevel;

  EyeDrynessResult({
    required this.totalBlinks,
    required this.testDurationSeconds,
    required this.blinksPerMinute,
    required this.score,
    required this.riskLevel,
  });

  static EyeDrynessResult calculate(int blinks, double durationSeconds) {
    final blinksPerMinute = (blinks / durationSeconds) * 60;

    // For 30 second test:
    // Optimal: 8-10 blinks (16-20 blinks/min)
    // Good: 6-7 blinks (12-14 blinks/min)
    // Low: 4-5 blinks (8-10 blinks/min)
    // Very Low: <4 blinks (<8 blinks/min)

    int score;
    DryEyeRiskLevel riskLevel;

    if (blinksPerMinute >= 15 && blinksPerMinute <= 20) {
      // Optimal range - 85-100 score
      score = 85 + ((5 - (blinksPerMinute - 17.5).abs()) * 3).toInt();
      riskLevel = DryEyeRiskLevel.healthy;
    } else if (blinksPerMinute >= 12 && blinksPerMinute < 15) {
      // Slightly below optimal - 70-84 score (mild)
      score = 70 + ((blinksPerMinute - 12) * 5).toInt();
      riskLevel = DryEyeRiskLevel.mild;
    } else if (blinksPerMinute >= 8 && blinksPerMinute < 12) {
      // Low blink rate - 50-69 score (moderate)
      score = 50 + ((blinksPerMinute - 8) * 5).toInt();
      riskLevel = DryEyeRiskLevel.moderate;
    } else if (blinksPerMinute < 8) {
      // Very low - 0-49 score (severe)
      score = (blinksPerMinute * 6.25).toInt();
      riskLevel = DryEyeRiskLevel.severe;
    } else if (blinksPerMinute > 20 && blinksPerMinute <= 25) {
      // Slightly high - still okay
      score = 80 - ((blinksPerMinute - 20) * 4).toInt();
      riskLevel = DryEyeRiskLevel.healthy;
    } else {
      // Very high (>25) - could indicate irritation
      score = 60 - ((blinksPerMinute - 25) * 2).toInt();
      riskLevel = DryEyeRiskLevel.mild;
    }

    return EyeDrynessResult(
      totalBlinks: blinks,
      testDurationSeconds: durationSeconds,
      blinksPerMinute: blinksPerMinute,
      score: score.clamp(0, 100),
      riskLevel: riskLevel,
    );
  }
}

class EyeDrynessScreen extends StatefulWidget {
  const EyeDrynessScreen({super.key});

  @override
  State<EyeDrynessScreen> createState() => _EyeDrynessScreenState();
}

class _EyeDrynessScreenState extends State<EyeDrynessScreen> with TickerProviderStateMixin {
  // Screen state
  EyeTestState _testState = EyeTestState.intro;

  // Camera & ML
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;

  // Blink detection state
  int _totalBlinks = 0;
  bool _eyesWereClosed = false;

  // Timing
  static const int _testDurationSeconds = 30;
  int _remainingSeconds = _testDurationSeconds;
  Timer? _testTimer;
  DateTime? _testStartTime;

  // Results
  EyeDrynessResult? _result;

  // Animation controllers
  late AnimationController _blinkAnimController;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );

    _blinkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController?.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  void _startTest() async {
    await _initializeCamera();

    setState(() {
      _testState = EyeTestState.scanning;
      _totalBlinks = 0;
      _remainingSeconds = _testDurationSeconds;
      _eyesWereClosed = false;
    });

    _testStartTime = DateTime.now();

    // Start image stream for blink detection
    _cameraController?.startImageStream(_processCameraImage);

    // Start countdown timer
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        _completeTest();
      }
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessingImage || _testState != EyeTestState.scanning) return;
    _isProcessingImage = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessingImage = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isNotEmpty) {
        final face = faces.first;
        final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
        final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
        _detectBlink(leftEyeOpen, rightEyeOpen);
      }
    } catch (e) {
      // Silently handle processing errors
    }

    _isProcessingImage = false;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
      final sensorOrientation = camera.sensorOrientation;

      InputImageRotation? rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      }

      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      if (image.planes.isEmpty) return null;

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  void _detectBlink(double leftEyeOpen, double rightEyeOpen) {
    const double closedThreshold = 0.3;
    const double openThreshold = 0.8;

    final avgEyeOpen = (leftEyeOpen + rightEyeOpen) / 2;

    if (!_eyesWereClosed && avgEyeOpen < closedThreshold) {
      _eyesWereClosed = true;
    } else if (_eyesWereClosed && avgEyeOpen > openThreshold) {
      setState(() {
        _totalBlinks++;
      });
      _eyesWereClosed = false;

      // Trigger blink animation
      _blinkAnimController.forward().then((_) => _blinkAnimController.reverse());
      HapticFeedback.lightImpact();
    }
  }

  void _completeTest() {
    _testTimer?.cancel();
    _cameraController?.stopImageStream();

    final testDuration = _testStartTime != null
        ? DateTime.now().difference(_testStartTime!).inSeconds.toDouble()
        : _testDurationSeconds.toDouble();

    final result = EyeDrynessResult.calculate(_totalBlinks, testDuration);

    setState(() {
      _testState = EyeTestState.results;
      _result = result;
    });
  }

  void _resetTest() {
    _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _testState = EyeTestState.intro;
      _totalBlinks = 0;
      _remainingSeconds = _testDurationSeconds;
      _result = null;
      _isCameraInitialized = false;
    });
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    _blinkAnimController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_testState) {
      EyeTestState.intro => _buildIntroScreen(),
      EyeTestState.scanning => _buildScanningScreen(),
      EyeTestState.results => _buildResultsScreen(),
    };
  }

  // ==================== INTRO SCREEN ====================
  Widget _buildIntroScreen() {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader('Eye Dryness Test', showInfo: true),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Main Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Eye Icon
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  LucideIcons.scanFace,
                                  size: 54,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2000.ms),

                          const SizedBox(height: 28),

                          Text(
                            'Check your eye dryness',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF101828),
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 12),

                          Text(
                            "We'll measure your blink rate using the front camera to determine your eye fatigue levels.",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF6A7282),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Features Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildFeatureRow(
                            icon: LucideIcons.zap,
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF3B82F6),
                            title: 'Quick & Easy',
                            subtitle: 'Takes less than 30 seconds',
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: Color(0xFFF9FAFB)),
                          ),
                          _buildFeatureRow(
                            icon: LucideIcons.alertTriangle,
                            iconBg: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFF97316),
                            title: 'Screen Fatigue',
                            subtitle: 'Detects early signs of dry eyes',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Start Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _startTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                          shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        ),
                        child: Text(
                          'Start Test',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
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
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E2939),
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6A7282),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== SCANNING SCREEN ====================
  Widget _buildScanningScreen() {
    final theme = Theme.of(context);
    final timeStr = '00:${_remainingSeconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF101828),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildDarkHeader('Scanning...'),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Timer and Blinks Pills
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPill(
                          icon: LucideIcons.timer,
                          text: timeStr,
                        ),
                        const SizedBox(width: 16),
                        AnimatedBuilder(
                          animation: _blinkAnimController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_blinkAnimController.value * 0.15),
                              child: _buildPill(
                                icon: LucideIcons.eye,
                                text: '$_totalBlinks Blinks',
                              ),
                            );
                          },
                        ),
                      ],
                    )
                        .animate()
                        .fade(duration: 300.ms)
                        .slideY(begin: -0.1, end: 0),

                    const SizedBox(height: 40),

                    // Face Scan Frame
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 0.75,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow behind frame
                              Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  color: const Color(0xFFA78BFA).withValues(alpha: 0.03),
                                ),
                              ),

                              // Dashed border frame
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Stack(
                                    children: [
                                      // Camera preview or placeholder
                                      if (_isCameraInitialized && _cameraController != null)
                                        Positioned.fill(
                                          child: CameraPreview(_cameraController!),
                                        )
                                      else
                                        const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFA78BFA),
                                          ),
                                        ),

                                      // Scanning line animation
                                      AnimatedBuilder(
                                        animation: _scanLineController,
                                        builder: (context, child) {
                                          return Positioned(
                                            top: _scanLineController.value * 300,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 80,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    const Color(0xFFA78BFA).withValues(alpha: 0.4),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      // Corner brackets for face alignment
                                      Positioned(
                                        top: 60,
                                        left: 40,
                                        child: _buildCornerBracket(isTopLeft: true),
                                      ),
                                      Positioned(
                                        top: 60,
                                        right: 40,
                                        child: _buildCornerBracket(isTopRight: true),
                                      ),
                                      Positioned(
                                        bottom: 60,
                                        left: 40,
                                        child: _buildCornerBracket(isBottomLeft: true),
                                      ),
                                      Positioned(
                                        bottom: 60,
                                        right: 40,
                                        child: _buildCornerBracket(isBottomRight: true),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Instructions
                    Text(
                      'Please blink normally',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Position your face within the frame.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF99A1AF),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerBracket({
    bool isTopLeft = false,
    bool isTopRight = false,
    bool isBottomLeft = false,
    bool isBottomRight = false,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          isTopLeft: isTopLeft,
          isTopRight: isTopRight,
          isBottomLeft: isBottomLeft,
          isBottomRight: isBottomRight,
        ),
      ),
    );
  }

  Widget _buildPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RESULTS SCREEN ====================
  Widget _buildResultsScreen() {
    final theme = Theme.of(context);
    final result = _result!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader('Test Results', showInfo: true),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge & Score Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Risk Badge
                          _buildRiskBadge(result.riskLevel),

                          const SizedBox(height: 20),

                          // Score Circle
                          _buildScoreCircle(result.score, result.riskLevel),

                          const SizedBox(height: 16),

                          // Status Text
                          Text(
                            _getRiskTitle(result.riskLevel),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You blinked ${result.totalBlinks} times during the test. ${_getRiskDescription(result.riskLevel)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6A7282),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fade(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 16),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            label: 'YOUR BLINKS',
                            value: '${result.totalBlinks}',
                            subtitle: 'in ${result.testDurationSeconds.toInt()}s',
                            valueColor: const Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            label: 'OPTIMAL',
                            value: '10-15',
                            subtitle: 'in 30s',
                            valueColor: const Color(0xFF00C950),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fade(delay: 100.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 16),

                    // Did You Know Card
                    _buildDidYouKnowCard()
                        .animate()
                        .fade(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 24),

                    // Recommendations Section
                    Text(
                      'Recommendations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF101828),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ..._buildRecommendationsList(result),

                    const SizedBox(height: 24),

                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF101828),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Done',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
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
    );
  }

  Widget _buildRiskBadge(DryEyeRiskLevel level) {
    final (bgColor, textColor, text) = switch (level) {
      DryEyeRiskLevel.healthy => (const Color(0xFFECFDF5), const Color(0xFF059669), 'HEALTHY EYES'),
      DryEyeRiskLevel.mild => (const Color(0xFFFFF7ED), const Color(0xFFF54900), 'MILD DRYNESS'),
      DryEyeRiskLevel.moderate => (const Color(0xFFFEF3C7), const Color(0xFFD97706), 'MODERATE DRYNESS'),
      DryEyeRiskLevel.severe => (const Color(0xFFFEE2E2), const Color(0xFFDC2626), 'SEVERE DRYNESS'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            level == DryEyeRiskLevel.healthy ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCircle(int score, DryEyeRiskLevel level) {
    final color = switch (level) {
      DryEyeRiskLevel.healthy => const Color(0xFF22C55E),
      DryEyeRiskLevel.mild => const Color(0xFFF97316),
      DryEyeRiskLevel.moderate => const Color(0xFFD97706),
      DryEyeRiskLevel.severe => const Color(0xFFDC2626),
    };

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 12,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(const Color(0xFFF3F4F6)),
            ),
          ),
          // Progress circle
          SizedBox(
            width: 160,
            height: 160,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          // Score text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: score),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101828),
                      letterSpacing: -1.5,
                    ),
                  );
                },
              ),
              const Text(
                'SCORE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF99A1AF),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subtitle,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF99A1AF),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6A7282),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDidYouKnowCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDBEAFE).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.lightbulb,
              size: 16,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Did you know?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2939),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Staring at screens reduces your blink rate by up to 60%, preventing your eyes from receiving vital moisture.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4A5565),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2939),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6A7282),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SHARED HEADER WIDGETS ====================
  Widget _buildHeader(String title, {bool showInfo = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_testState == EyeTestState.results) {
                Navigator.of(context).pop();
              } else {
                _resetTest();
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(LucideIcons.chevronLeft, size: 20, color: Color(0xFF101828)),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF101828),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (showInfo)
            const SizedBox(
              width: 40,
              height: 40,
              child: Icon(LucideIcons.info, size: 20, color: Color(0xFF99A1AF)),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildDarkHeader(String title) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: const Color(0xFF101828),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _testTimer?.cancel();
              _cameraController?.stopImageStream();
              _resetTest();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.chevronLeft, size: 20, color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  String _getRiskTitle(DryEyeRiskLevel level) {
    return switch (level) {
      DryEyeRiskLevel.healthy => 'Eyes Look Healthy!',
      DryEyeRiskLevel.mild => 'Blink Rate is Low',
      DryEyeRiskLevel.moderate => 'Moderate Dryness',
      DryEyeRiskLevel.severe => 'High Dryness Risk',
    };
  }

  String _getRiskDescription(DryEyeRiskLevel level) {
    return switch (level) {
      DryEyeRiskLevel.healthy => 'Your blink rate is within optimal levels.',
      DryEyeRiskLevel.mild => 'Your resting blink rate is below optimal levels.',
      DryEyeRiskLevel.moderate => 'Your eyes may be experiencing moderate strain.',
      DryEyeRiskLevel.severe => 'Consider taking a break and using eye drops.',
    };
  }

  List<Widget> _buildRecommendationsList(EyeDrynessResult result) {
    final recommendations = <Map<String, dynamic>>[];

    // Always show these core recommendations
    recommendations.add({
      'icon': LucideIcons.droplet,
      'iconBg': const Color(0xFFEFF6FF),
      'iconColor': const Color(0xFF3B82F6),
      'title': 'Hydrating Eye Drops',
      'subtitle': 'Use artificial tears to moisturize your eyes',
    });

    recommendations.add({
      'icon': LucideIcons.eye,
      'iconBg': const Color(0xFFF0FDF4),
      'iconColor': const Color(0xFF22C55E),
      'title': 'The 20-20-20 Rule',
      'subtitle': 'Every 20 mins, look 20 ft away for 20 seconds',
    });

    recommendations.add({
      'icon': LucideIcons.sun,
      'iconBg': const Color(0xFFFFF7ED),
      'iconColor': const Color(0xFFF97316),
      'title': 'Adjust Screen Brightness',
      'subtitle': 'Match your screen brightness to room lighting',
    });

    // Add more recommendations based on severity
    if (result.riskLevel != DryEyeRiskLevel.healthy) {
      recommendations.add({
        'icon': LucideIcons.monitor,
        'iconBg': const Color(0xFFF3E8FF),
        'iconColor': const Color(0xFF8B5CF6),
        'title': 'Position Your Screen',
        'subtitle': 'Keep screen slightly below eye level to reduce exposure',
      });

      recommendations.add({
        'icon': LucideIcons.wind,
        'iconBg': const Color(0xFFECFDF5),
        'iconColor': const Color(0xFF10B981),
        'title': 'Avoid Direct Airflow',
        'subtitle': 'Keep fans and AC vents away from your face',
      });
    }

    if (result.riskLevel == DryEyeRiskLevel.moderate ||
        result.riskLevel == DryEyeRiskLevel.severe) {
      recommendations.add({
        'icon': LucideIcons.glassWater,
        'iconBg': const Color(0xFFE0F2FE),
        'iconColor': const Color(0xFF0EA5E9),
        'title': 'Stay Hydrated',
        'subtitle': 'Drink at least 8 glasses of water daily',
      });

      recommendations.add({
        'icon': LucideIcons.moon,
        'iconBg': const Color(0xFFF1F5F9),
        'iconColor': const Color(0xFF64748B),
        'title': 'Use Night Mode',
        'subtitle': 'Enable dark mode or night shift in the evening',
      });

      recommendations.add({
        'icon': LucideIcons.clock,
        'iconBg': const Color(0xFFFEF2F2),
        'iconColor': const Color(0xFFEF4444),
        'title': 'Take Regular Breaks',
        'subtitle': 'Step away from screens every 30-45 minutes',
      });
    }

    if (result.riskLevel == DryEyeRiskLevel.severe) {
      recommendations.add({
        'icon': LucideIcons.stethoscope,
        'iconBg': const Color(0xFFFDF2F8),
        'iconColor': const Color(0xFFEC4899),
        'title': 'Consult an Eye Doctor',
        'subtitle': 'Consider scheduling an eye examination',
      });

      recommendations.add({
        'icon': LucideIcons.glasses,
        'iconBg': const Color(0xFFFEFCE8),
        'iconColor': const Color(0xFFCA8A04),
        'title': 'Consider Blue Light Glasses',
        'subtitle': 'Filter harmful blue light from screens',
      });
    }

    // Build the widget list with animations
    final widgets = <Widget>[];
    for (int i = 0; i < recommendations.length; i++) {
      final rec = recommendations[i];
      widgets.add(
        _buildRecommendationCard(
          icon: rec['icon'] as IconData,
          iconBg: rec['iconBg'] as Color,
          iconColor: rec['iconColor'] as Color,
          title: rec['title'] as String,
          subtitle: rec['subtitle'] as String,
        )
            .animate()
            .fade(delay: Duration(milliseconds: 300 + (i * 80)), duration: 400.ms)
            .slideX(begin: 0.1, end: 0),
      );
      if (i < recommendations.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }
}

// Custom painter for corner brackets
class _CornerBracketPainter extends CustomPainter {
  final bool isTopLeft;
  final bool isTopRight;
  final bool isBottomLeft;
  final bool isBottomRight;

  _CornerBracketPainter({
    this.isTopLeft = false,
    this.isTopRight = false,
    this.isBottomLeft = false,
    this.isBottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFA78BFA).withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const length = 20.0;

    if (isTopLeft) {
      path.moveTo(0, length);
      path.lineTo(0, 0);
      path.lineTo(length, 0);
    } else if (isTopRight) {
      path.moveTo(size.width - length, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, length);
    } else if (isBottomLeft) {
      path.moveTo(0, size.height - length);
      path.lineTo(0, size.height);
      path.lineTo(length, size.height);
    } else if (isBottomRight) {
      path.moveTo(size.width - length, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - length);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
