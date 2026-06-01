import 'package:flutter/material.dart';
import '../../../core/ui/ui_refresh_bus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:office_buddy/constants/asset_source.dart' as source;

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

  late AnimationController _cycleController;
  late AnimationController _rippleController;

  int _secondsLeft = _sessionDurationSeconds;
  Timer? _countdownTimer;
  bool _isPlaying = false;
  bool _isMuted = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioErrorShown = false;

  int _currentPhase = 0;

  late Animation<double> _breathScale;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _audioPlayer.setReleaseMode(ReleaseMode.loop).catchError(_handleAudioError);

    _cycleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..addListener(_onCycleTick);

    _breathScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.3).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(0.3), weight: 25),
    ]).animate(_cycleController);

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

  String get _phaseLabel {
    if (!_isPlaying) return 'Tap to begin';
    switch (_currentPhase) {
      case 0: return 'Breathe In';
      case 1: return 'Hold';
      case 2: return 'Breathe Out';
      case 3: return 'Hold';
      default: return '';
    }
  }

  Color get _bgColor {
    if (!_isPlaying) return const Color(0xFFF5EDE3);
    switch (_currentPhase) {
      case 0:
      case 1: return const Color(0xFF87AE6E);
      case 2:
      case 3: return const Color(0xFFE07B3A);
      default: return const Color(0xFF87AE6E);
    }
  }

  Color get _onColor {
    if (!_isPlaying) return const Color(0xFF5C4033);
    return Colors.white;
  }

  Future<void> _playAudio() async {
    try { await BirdsAudio.playOn(_audioPlayer); }
    catch (e) { _handleAudioError(e); }
  }

  Future<void> _pauseAudio() async {
    try { await _audioPlayer.pause(); }
    catch (e) { _handleAudioError(e); }
  }

  Future<void> _stopAudio() async {
    try { await _audioPlayer.stop(); }
    catch (e) { _handleAudioError(e); }
  }

  void _handleAudioError(Object error) {
    debugPrint('Audio playback error: $error');
    if (!mounted || _audioErrorShown) return;
    _audioErrorShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not play birds sound.')),
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
      if (!_isMuted) _playAudio();
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
                  source.AssetSource.confrttirBrustJson,
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
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          source.AssetSource.energyImg,
                          width: 80,
                          height: 80,
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 2.seconds)
                            .scaleXY(begin: 0.9, end: 1.1, duration: 1.seconds)
                            .then()
                            .scaleXY(begin: 1.1, end: 0.9, duration: 1.seconds),
                        const SizedBox(height: 20),
                        const Text(
                          'Session Complete',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF87AE6E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your heart rate and stress levels have normalized. Great job taking a moment for yourself!',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF5C4033),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF87AE6E),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            },
                            child: const Text(
                              'Back to Dashboard',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
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
    final mm = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        color: _bgColor,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 8),
              _buildSubtitle(),
              Expanded(
                child: _buildBreathingOrb(size),
              ),
              _buildPhaseIndicator(),
              const SizedBox(height: 28),
              _buildTimerText(mm, ss),
              const SizedBox(height: 24),
              _buildPlayButton(),
              const SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _onColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _onColor.withValues(alpha: 0.25)),
              ),
              child: Icon(LucideIcons.arrowLeft, color: _onColor, size: 18),
            ),
          ),
          const Spacer(),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              color: _onColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            child: const Text('A Moment For You'),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _toggleMute,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _onColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _onColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isMuted ? LucideIcons.volumeX : LucideIcons.music,
                    color: _onColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: _onColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    child: Text(_isMuted ? 'Muted' : 'Birds'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _isPlaying ? 0.0 : 0.75,
      child: Text(
        'Box Breathing  ·  4 – 4 – 4 – 4',
        style: TextStyle(
          color: _onColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBreathingOrb(Size size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _isPlaying ? _cycleController : _rippleController,
          builder: (context, _) {
            return CustomPaint(
              size: Size(size.width, size.width * 0.9),
              painter: ConcentricRipplePainter(
                scale: _isPlaying ? _breathScale.value : 0.3,
                bgColor: _bgColor,
                isPlaying: _isPlaying,
                rippleProgress: _rippleController.value,
              ),
            );
          },
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                _phaseLabel,
                key: ValueKey<String>(_phaseLabel),
                style: TextStyle(
                  color: _onColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator() {
    const steps = ['Inhale', 'Hold', 'Exhale', 'Hold'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final isActive = _isPlaying && _currentPhase == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? _onColor.withValues(alpha: 0.22)
                : _onColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? _onColor.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            steps[i],
            style: TextStyle(
              color: _onColor.withValues(alpha: isActive ? 1.0 : 0.5),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimerText(String mm, String ss) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 400),
      style: TextStyle(
        color: _onColor,
        fontSize: 42,
        fontWeight: FontWeight.w200,
        letterSpacing: 4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      child: Text('$mm:$ss'),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: _onColor.withValues(alpha: _isPlaying ? 0.35 : 0.0),
                width: 2,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPlaying
                  ? _onColor.withValues(alpha: 0.2)
                  : _onColor.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                _isPlaying ? LucideIcons.pause : LucideIcons.play,
                key: ValueKey<bool>(_isPlaying),
                color: _isPlaying ? _onColor : _bgColor,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConcentricRipplePainter extends CustomPainter {
  final double scale;
  final Color bgColor;
  final bool isPlaying;
  final double rippleProgress;

  ConcentricRipplePainter({
    required this.scale,
    required this.bgColor,
    required this.isPlaying,
    required this.rippleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.40;

    final fractions = [1.0, 0.74, 0.50, 0.30];
    final alphas = [0.10, 0.15, 0.20, 0.28];

    for (var i = 0; i < fractions.length; i++) {
      double r = maxR * fractions[i] * (isPlaying ? (0.55 + scale * 0.45) : 0.78);

      if (!isPlaying) {
        r *= 1.0 + 0.045 * math.sin(rippleProgress * 2 * math.pi + i * 0.9);
      }

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: alphas[i])
          ..style = PaintingStyle.fill,
      );
    }

    // Soft inner glow ring when playing
    if (isPlaying) {
      canvas.drawCircle(
        center,
        maxR * 0.30 * (0.55 + scale * 0.45),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConcentricRipplePainter old) => true;
}
