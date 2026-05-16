import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/ui/ob_background.dart';
import '../../breaks/presentation/break_screen.dart';
import '../../eyes/presentation/eye_dryness_screen.dart';
import '../../posture/presentation/posture_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ValueNotifier<int> _refreshTick = ValueNotifier<int>(0);
  bool _showMotivation = true;

  @override
  void dispose() {
    _refreshTick.dispose();
    super.dispose();
  }

  void _refresh(VoidCallback update) {
    if (!mounted) return;
    update();
    _refreshTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshTick,
      builder: (context, _, child) {
        return Scaffold(
          body: ObBackground(
            child: Stack(
              children: [
                const _AmbientGlow(alignment: Alignment(-1.15, -0.9)),
                const _AmbientGlow(
                  alignment: Alignment(1.1, 0.4),
                  color: Color(0x225B8CFF),
                ),
                SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HomeHeader()
                            .animate()
                            .fade(duration: 320.ms)
                            .slideY(begin: -0.08, end: 0),
                        const SizedBox(height: 12),

                        // Daily Motivation Card
                        if (_showMotivation)
                          _MotivationCard(
                                onDismiss: () =>
                                    _refresh(() => _showMotivation = false),
                              )
                              .animate()
                              .fade(delay: 80.ms, duration: 320.ms)
                              .slideY(begin: 0.08, end: 0),

                        const SizedBox(height: 12),

                        // Moment Card
                        _MomentCard(
                              onTap: () => context.push(AppRoutes.stressScreen),
                            )
                            .animate()
                            .fade(delay: 200.ms, duration: 320.ms)
                            .slideY(begin: 0.08, end: 0),

                        const SizedBox(height: 12),

                        // Feature Cards Grid
                        StaggeredGrid.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              children: [
                                StaggeredGridTile.fit(
                                  crossAxisCellCount: 1,
                                  child: _FeatureCard(
                                    title: 'Check\nPosture',
                                    subtitle: 'Verify sitting\nposition',
                                    icon: LucideIcons.scanFace,
                                    gradient: const [
                                      Color(0xFF5B8CFF),
                                      Color(0xFF3A6FF7),
                                    ],
                                    shadowColor: const Color(0xFF3A6FF7),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const PostureScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                StaggeredGridTile.fit(
                                  crossAxisCellCount: 1,
                                  child: _FeatureCard(
                                    title: 'Eye Check',
                                    subtitle: 'Blink and rest',
                                    icon: LucideIcons.eye,
                                    gradient: const [
                                      Color(0xFFA78BFA),
                                      Color(0xFF8B5CF6),
                                    ],
                                    shadowColor: const Color(0xFF8B5CF6),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const EyeDrynessScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                StaggeredGridTile.fit(
                                  crossAxisCellCount: 1,
                                  child: _FeatureCard(
                                    title: 'Movement',
                                    subtitle: 'Stretch & walk',
                                    icon: LucideIcons.footprints,
                                    gradient: const [
                                      Color(0xFF34D399),
                                      Color(0xFF10B981),
                                    ],
                                    shadowColor: const Color(0xFF10B981),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const BreakScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                StaggeredGridTile.fit(
                                  crossAxisCellCount: 1,
                                  child: _FeatureCard(
                                    title: 'Finance\nTracker',
                                    subtitle: 'Review expenses',
                                    icon: LucideIcons.wallet,
                                    gradient: const [
                                      Color(0xFFFF6B8A),
                                      Color(0xFFFF3D6E),
                                    ],
                                    shadowColor: const Color(0xFFFF3D6E),
                                    onTap: () =>
                                        context.push(AppRoutes.financeScreen),
                                  ),
                                ),
                              ],
                            )
                            .animate()
                            .fade(delay: 260.ms, duration: 360.ms)
                            .slideY(begin: 0.1, end: 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  String _userName() {
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(RegExp(r'\s+')).first;
    }

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'there';
  }

  String? _photoUrl() {
    final photoUrl = FirebaseBootstrap.authOrNull?.currentUser?.photoURL
        ?.trim();
    return photoUrl == null || photoUrl.isEmpty ? null : photoUrl;
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.person_rounded,
        size: 30,
        color: Color(0xFF9CA3AF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = _photoUrl();
    return Row(
      children: [
        // Avatar with progress ring
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring
              // SizedBox(
              //   width: 60,
              //   height: 60,
              //   child: CustomPaint(
              //     painter: _ProgressRingPainter(
              //       progress: 0.75,
              //       strokeWidth: 3,
              //       backgroundColor: Colors.grey.shade200,
              //       progressColor: const Color(0xFF5B8CFF),
              //     ),
              //   ),
              // ),
              // Avatar
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: photoUrl == null
                      ? _fallbackAvatar()
                      : Image.network(
                          photoUrl,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _fallbackAvatar(),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${_userName()}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF101828),
                  letterSpacing: -0.5,
                  fontSize: 22,
                ),
              ),

              // const SizedBox(height: 2),
              // Row(
              //   children: [
              //     // Glowing green dot
              //     Stack(
              //       alignment: Alignment.center,
              //       children: [
              //         Container(
              //           width: 14,
              //           height: 14,
              //           decoration: BoxDecoration(
              //             color: const Color(0xFF10B981).withValues(alpha: 0.2),
              //             shape: BoxShape.circle,
              //           ),
              //         ),
              //         Container(
              //           width: 8,
              //           height: 8,
              //           decoration: const BoxDecoration(
              //             color: Color(0xFF10B981),
              //             shape: BoxShape.circle,
              //           ),
              //         ),
              //       ],
              //     ),
              //     const SizedBox(width: 8),
              //     Text(
              //       'YOUR ENERGY IS HIGH TODAY',
              //       style: theme.textTheme.labelSmall?.copyWith(
              //         color: const Color(0xFF6A7282),
              //         fontWeight: FontWeight.w600,
              //         letterSpacing: 0.3,
              //         fontSize: 11,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MotivationCard extends StatelessWidget {
  const _MotivationCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFFFF7ED).withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Quote mark decoration
          Positioned(
            left: -12,
            top: -16,
            child: Text(
              '"',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 52,
                color: const Color(0xFFFF6900).withValues(alpha: 0.1),
                height: 1,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY MOTIVATION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFFF6900),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Take care of your body. It's the only place you have to live.",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1E2939),
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        fontSize: 16,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '— Jim Rohn',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF99A1AF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(LucideIcons.x, size: 18),
                color: const Color(0xFFEF4444),
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated icon
          SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B8CFF).withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(
                      Icons.air_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 1500.ms,
              ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A moment for you',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1E2939),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1 min to reduce stress',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A7282),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF101828),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Start',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.shadowColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color shadowColor;
  final VoidCallback? onTap;
  static const _cardRadius = 16.0;
  static const _cardPadding = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleSize = title.contains('\n') ? 18.0 : 17.0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Ink(
          padding: const EdgeInsets.all(_cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: -0.5,
                  fontSize: titleSize,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.alignment,
    this.color = const Color(0x16ADF0D7),
  });

  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color, blurRadius: 120, spreadRadius: 48),
            ],
          ),
        ),
      ),
    );
  }
}
