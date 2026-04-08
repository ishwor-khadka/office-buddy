import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../posture/presentation/posture_screen.dart';
import '../../eyes/presentation/eye_dryness_screen.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';
import '../../../features/breaks/presentation/break_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Office Buddy',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: ObBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ObGlass(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            ObTokens.mintDeep.withValues(alpha: 0.9),
                            ObTokens.iris.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                      child: const Icon(LucideIcons.heartPulse,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Small resets. Big wins.',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.04),
              const SizedBox(height: 14),
              _ActionCard(
                title: 'Check my posture',
                subtitle: 'Accurate scan. Instant correction.',
                icon: LucideIcons.scan,
                colors: [colorScheme.primary, colorScheme.secondary],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PostureScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ActionCard(
                title: 'Take a movement break',
                subtitle: 'Walk a few steps to reset.',
                icon: LucideIcons.activity,
                colors: [ObTokens.mintDeep, ObTokens.sky],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BreakScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ActionCard(
                title: 'Check eye dryness',
                subtitle: 'Quick blink scan (optional).',
                icon: LucideIcons.eye,
                colors: [const Color(0xFFFFB86B), const Color(0xFFFF6AA2)],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EyeDrynessScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ObGlass(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                colors.first.withValues(alpha: 0.22),
                colors.last.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight),
            ],
          ),
        ),
      ),
    );
  }
}
