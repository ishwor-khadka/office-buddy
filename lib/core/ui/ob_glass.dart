import 'dart:ui';

import 'package:flutter/material.dart';

class ObGlass extends StatelessWidget {
  const ObGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.tint,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = tint ?? theme.colorScheme.surface;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.55),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

