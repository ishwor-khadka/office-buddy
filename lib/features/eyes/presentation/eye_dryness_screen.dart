import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class EyeDrynessScreen extends StatefulWidget {
  const EyeDrynessScreen({super.key});

  @override
  State<EyeDrynessScreen> createState() => _EyeDrynessScreenState();
}

class _EyeDrynessScreenState extends State<EyeDrynessScreen> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // Needed for blink detection (eye open probability)
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  
  bool _isProcessingImage = false;
  int _blinkCount = 0;
  String _statusMessage = 'Align face to scan blinks...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    await _cameraController?.initialize();
    if (mounted) setState(() {});
    
    _cameraController?.startImageStream((CameraImage image) {
      if (_isProcessingImage) return;
      _isProcessingImage = true;
      _processCameraImage(image);
    });
  }

  // Placeholder logic processing ML Kit Face Input (Image Format conversion is complex in Flutter natively,
  // usually handled using InputImage.fromBytes, but for MVP UI simulation we track logic below)
  void _processCameraImage(CameraImage image) async {
    // Simulated Blink detection pipeline
    // When Left/Right Eye Open Probability drops below 0.3, it's a blink!
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate processing delay
    
    if (mounted) {
      setState(() {
        _statusMessage = 'Scanning active...';
      });
    }
    _isProcessingImage = false;
  }

  void _simulateABlinkForTesting() {
    setState(() {
      _blinkCount++;
      _statusMessage = 'Blink Detected!';
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_cameraController?.value.isInitialized == true)
            CameraPreview(_cameraController!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Scan Frame UI Overlay
          SafeArea(
            child: Column(
              children: [
                // AppBar Overlay
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Eye Dryness Scan',
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Magic Face Ring Overlay
                Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orangeAccent, width: 3),
                    borderRadius: BorderRadius.circular(200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.03, duration: 2.seconds),
                
                const Spacer(),

                // Status Panel
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_blinkCount',
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.orangeAccent),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Blinks Detected', style: theme.textTheme.bodyMedium),
                            Text(
                              _statusMessage,
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // Temporary generic tester button since physical cameras aren't available in emulator
                      IconButton(
                        icon: const Icon(LucideIcons.playCircle, color: Colors.white54),
                        onPressed: _simulateABlinkForTesting,
                      ),
                    ],
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
