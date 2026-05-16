import 'package:flutter/material.dart';

import 'ob_tokens.dart';

class ObBottomBar extends StatelessWidget {
  const ObBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex; // 0=Home, 1=Exercise
  final void Function(int index) onSelect;

  Color _activeColor(ThemeData theme) => const Color(0xFF00B78B);
  Color _inactiveColor(ThemeData theme) => const Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomPad = media.padding.bottom;

    return SizedBox(
      height: 88 + bottomPad,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 12 + bottomPad),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _Item(
                label: 'Home',
                icon: Icons.home_rounded,
                active: currentIndex == 0,
                activeColor: _activeColor(theme),
                inactiveColor: _inactiveColor(theme),
                onTap: () => onSelect(0),
              ),
            ),
            Expanded(
              child: _Item(
                label: 'Exercise',
                icon: Icons.fitness_center_rounded,
                active: currentIndex == 1,
                activeColor: _activeColor(theme),
                inactiveColor: _inactiveColor(theme),
                onTap: () => onSelect(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active
            ? ObTokens.mint.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
