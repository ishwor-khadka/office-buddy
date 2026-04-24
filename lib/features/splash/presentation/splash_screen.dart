import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/settings/office_schedule_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final OfficeScheduleRepository _officeScheduleRepository =
      OfficeScheduleRepository();

  late AnimationController _controller;
  late Animation<double> _mintFillAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _textFadeAnim;
  late Animation<double> _circleFadeAnim;
  Timer? _routeTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Mint background "fill" expands to cover the screen.
    _mintFillAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // Whole logo fades + scales forward (zoom-in effect)
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.35, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    // Soft outer glow ring fades in slightly later
    _circleFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.7, curve: Curves.easeIn),
      ),
    );

    // Subtitle text fades in near the end
    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _routeTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      _routeNext();
    });
  }

  Future<void> _routeNext() async {
    final auth = FirebaseBootstrap.authOrNull;
    if (auth?.currentUser == null) {
      if (!mounted) return;
      context.go(AppRoutes.loginScreen);
      return;
    }

    final hasSavedSchedule = await _officeScheduleRepository.hasSavedSchedule();
    if (!mounted) return;
    context.go(
      hasSavedSchedule ? AppRoutes.homeScreen : AppRoutes.onBoardingScreen,
    );
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final diagonal = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final fillBaseSize = 220.0;
    final maxFillScale = (diagonal / fillBaseSize) * 1.15;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF8),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final fillScale = (0.001 + _mintFillAnim.value) * maxFillScale;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Base background (near-white) with a soft cool tint.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.6, -0.6),
                    radius: 1.2,
                    colors: [Color(0xFFF7FBF8), Color(0xFFEFF6FF)],
                  ),
                ),
              ),

              // Mint fill expanding from center to cover the whole screen.
              Center(
                child: Transform.scale(
                  scale: fillScale,
                  child: Container(
                    width: fillBaseSize,
                    height: fillBaseSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFADEBB3),
                    ),
                  ),
                ),
              ),

              // Foreground content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Outer glow ring
                    Opacity(
                      opacity: _circleFadeAnim.value,
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.25),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.4),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Opacity(
                              opacity: _fadeAnim.value,
                              // Circular white card containing the logo
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/app_logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.spa_rounded,
                                              size: 100,
                                              color: Color(0xFF2D6A4F),
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // App name
                    Opacity(
                      opacity: _textFadeAnim.value,
                      child: Column(
                        children: [
                          const Text(
                            'Office Buddy',
                            style: TextStyle(
                              color: Color(0xFF1A3A20),
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your wellness companion',
                            style: TextStyle(
                              color: const Color(
                                0xFF2D5016,
                              ).withValues(alpha: 0.75),
                              fontSize: 15,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
