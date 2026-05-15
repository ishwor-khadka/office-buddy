import 'package:flutter/material.dart';
import '../../../core/ui/ui_refresh_bus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;

import '../../../core/tracking/tracking_repository.dart';
import '../../../core/audio/birds_audio.dart';

class StressReliefScreen extends ConsumerStatefulWidget {
  const StressReliefScreen({super.key});

  @override
  ConsumerState<StressReliefScreen> createState() => _StressReliefScreenState();
}

class _StressReliefScreenState extends ConsumerState<StressReliefScreen>
    with TickerProviderStateMixin {
  static const int _sessionDurationSeconds = 60;

  // Box breathing: 4s inhale, 4s hold, 4s exhale, 4s hold = 16s cycle
  late AnimationController _cycleController; // 16-second cycle
  late AnimationController _rippleController; // Continuous ripple pulse

  int _secondsLeft = _sessionDurationSeconds; // 1 minute
  Timer? _countdownTimer;
  bool _isPlaying = false;
  bool _isMuted = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioErrorShown = false;

  // 0=Inhale, 1=Hold, 2=Exhale, 3=Hold
  int _currentPhase = 0;

  // Ripple scale driven by phase
  late Animation<double> _breathScale;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _audioPlayer.setReleaseMode(ReleaseMode.loop).catchError(_handleAudioError);

    // 16-second cycle controller
    _cycleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..addListener(_onCycleTick);

    // Breathing scale: inhale expand, hold at max, exhale contract, hold at min
    _breathScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ), // Inhale 4s
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25), // Hold 4s
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.3,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ), // Exhale 4s
      TweenSequenceItem(tween: ConstantTween(0.3), weight: 25), // Hold 4s
    ]).animate(_cycleController);

    // Ripple controller for outer animated rings
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _onCycleTick() {
    final phase = (_cycleController.value * 4).floor().clamp(0, 3);
    if (phase != _currentPhase) {
      UiRefreshBus.instance.update(this, () => _currentPhase = phase);
    } else {
      UiRefreshBus.instance.update(this, () {});
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cycleController.dispose();
    _rippleController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String get _phaseText {
    if (!_isPlaying) return 'Tap play to begin';
    switch (_currentPhase) {
      case 0:
        return 'Breathe In...';
      case 1:
        return 'Hold...';
      case 2:
        return 'Breathe out...';
      case 3:
        return 'Hold...';
      default:
        return '';
    }
  }

  // Background color transitions per phase, matching reference image
  Color get _bgColor {
    if (!_isPlaying) return const Color(0xFFF5EDE3); // warm beige when paused
    switch (_currentPhase) {
      case 0:
      case 1:
        return const Color(0xFF87AE6E); // sage green — inhale/hold
      case 2:
      case 3:
        return const Color(0xFFE07B3A); // warm orange — exhale/hold
      default:
        return const Color(0xFF87AE6E);
    }
  }

  Color get _onColor {
    if (!_isPlaying) return const Color(0xFF5C4033);
    return Colors.white;
  }

  Future<void> _playAudio() async {
    try {
      await BirdsAudio.playOn(_audioPlayer);
    } catch (error) {
      _handleAudioError(error);
    }
  }

  Future<void> _pauseAudio() async {
    try {
      await _audioPlayer.pause();
    } catch (error) {
      _handleAudioError(error);
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (error) {
      _handleAudioError(error);
    }
  }

  void _handleAudioError(Object error) {
    debugPrint('Audio playback error: $error');
    if (!mounted || _audioErrorShown) return;

    _audioErrorShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not play birds sound. Check assets/birds.mp3.'),
      ),
    );
  }

  void _togglePlay() {
    if (_isPlaying) {
      _cycleController.stop();
      _countdownTimer?.cancel();
      _pauseAudio();
      UiRefreshBus.instance.update(this, () => _isPlaying = false);
    } else {
      if (_secondsLeft <= 0) {
        _secondsLeft = _sessionDurationSeconds;
        _currentPhase = 0;
      }
      _cycleController.repeat();
      UiRefreshBus.instance.update(this, () => _isPlaying = true);

      if (!_isMuted) {
        _playAudio();
      }

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsLeft > 0) {
          UiRefreshBus.instance.update(this, () => _secondsLeft--);
        } else {
          t.cancel();
          _timerFinished();
        }
      });
    }
  }

  void _timerFinished() {
    _cycleController.stop();
    _stopAudio();
    UiRefreshBus.instance.update(this, () {
      _isPlaying = false;
      _secondsLeft = 0;
    });
    TrackingRepository.trackIfAvailable(
      type: 'stress_relief_completed',
      data: {'duration_seconds': _sessionDurationSeconds},
    );
    _showCompletionDialog();
  }

  void _toggleMute() {
    UiRefreshBus.instance.update(this, () => _isMuted = !_isMuted);
    if (_isMuted) {
      _pauseAudio();
    } else if (_isPlaying) {
      _playAudio();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Lottie.asset(
                  'assets/Confetti Burst.json',
                  repeat: true,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/energy.png', width: 80, height: 80)
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 2.seconds)
                            .scaleXY(begin: 0.9, end: 1.1, duration: 1.seconds)
                            .then()
                            .scaleXY(begin: 1.1, end: 0.9, duration: 1.seconds),
                        const SizedBox(height: 24),
                        const Text(
                          'Hurray! You finished!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF87AE6E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your heart rate and stress levels have normalized. Great job taking a moment for yourself!',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF5C4033),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: const Color(0xFF87AE6E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          child: const Text(
                            'Back to Dashboard',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final timerText =
        '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        color: _bgColor,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              // ─── Top bar ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _onColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: _onColor,
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Music pill
                    GestureDetector(
                      onTap: _toggleMute,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _onColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _onColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.music_note_rounded,
                              color: _onColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isMuted ? 'Muted' : 'Chirping Birds',
                              style: TextStyle(
                                color: _onColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Ripple + Phase Text ───────────────────────────────
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric ripple circles (like reference image)
                    AnimatedBuilder(
                      animation: _isPlaying
                          ? _cycleController
                          : _rippleController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(size.width, size.width),
                          painter: ConcentricRipplePainter(
                            scale: _isPlaying ? _breathScale.value : 0.3,
                            bgColor: _bgColor,
                            isPlaying: _isPlaying,
                            rippleProgress: _rippleController.value,
                          ),
                        );
                      },
                    ),
                    // Phase label
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Text(
                        _phaseText,
                        key: ValueKey<String>(_phaseText),
                        style: TextStyle(
                          color: _onColor,
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Timer ────────────────────────────────────────────
              Text(
                timerText,
                style: TextStyle(
                  color: _onColor,
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),

              const SizedBox(height: 28),

              // ─── Play / Pause Button ──────────────────────────────
              GestureDetector(
                onTap: _togglePlay,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isPlaying ? _onColor : const Color(0xFF87AE6E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey<bool>(_isPlaying),
                      color: _isPlaying ? _bgColor : Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Painter: Concentric circles like the reference image ──────────────────
class ConcentricRipplePainter extends CustomPainter {
  final double scale;
  final Color bgColor;
  final bool isPlaying;
  final double rippleProgress; // 0→1 idle ripple

  ConcentricRipplePainter({
    required this.scale,
    required this.bgColor,
    required this.isPlaying,
    required this.rippleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.44;

    // Draw 4 concentric filled circles from largest to smallest
    // Each circle is slightly lighter/darker than background
    final List<double> fractions = [1.0, 0.75, 0.52, 0.32];
    final List<double> alphas = [0.12, 0.16, 0.20, 0.26];

    for (int i = 0; i < fractions.length; i++) {
      double r = maxR * fractions[i] * (isPlaying ? (0.6 + scale * 0.4) : 0.8);

      // Idle gentle pulse when paused
      if (!isPlaying) {
        r *= 1.0 + 0.04 * math.sin(rippleProgress * 2 * math.pi + i * 0.8);
      }

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alphas[i])
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConcentricRipplePainter old) => true;
}
