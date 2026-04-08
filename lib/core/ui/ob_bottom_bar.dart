import 'package:flutter/material.dart';

import 'ob_tokens.dart';

class ObBottomBar extends StatelessWidget {
  const ObBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onBreathe,
  });

  final int currentIndex; // 0=Home, 1=Stats, 2=Exercise, 3=Sleep
  final void Function(int index) onSelect;
  final VoidCallback onBreathe;

  Color _activeColor(ThemeData theme) => const Color(0xFF00B78B);
  Color _inactiveColor(ThemeData theme) => const Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomPad = media.padding.bottom;

    return SizedBox(
      height: 92 + bottomPad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 14 + bottomPad),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Item(
                    label: 'Home',
                    icon: Icons.home_outlined,
                    active: currentIndex == 0,
                    activeColor: _activeColor(theme),
                    inactiveColor: _inactiveColor(theme),
                    onTap: () => onSelect(0),
                  ),
                  _Item(
                    label: 'Stats',
                    icon: Icons.bar_chart_rounded,
                    active: currentIndex == 1,
                    activeColor: _activeColor(theme),
                    inactiveColor: _inactiveColor(theme),
                    onTap: () => onSelect(1),
                  ),
                  const SizedBox(width: 86),
                  _Item(
                    label: 'Sleep',
                    icon: Icons.nights_stay_outlined,
                    active: currentIndex == 2,
                    activeColor: _activeColor(theme),
                    inactiveColor: _inactiveColor(theme),
                    onTap: () => onSelect(2),
                  ),
                  _Item(
                    label: 'Exercise',
                    icon: Icons.fitness_center_outlined,
                    active: currentIndex == 3,
                    activeColor: _activeColor(theme),
                    inactiveColor: _inactiveColor(theme),
                    onTap: () => onSelect(3),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 42 + bottomPad,
            child: Center(
              child: _BreatheButton(onTap: onBreathe),
            ),
          ),
        ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
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
    );
  }
}

class _BreatheButton extends StatelessWidget {
  const _BreatheButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ObTokens.mintDeep, ObTokens.mint],
          ),
          boxShadow: [
            BoxShadow(
              color: ObTokens.mintDeep.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.6),
              blurRadius: 18,
              spreadRadius: -6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
            SizedBox(height: 2),
            Text(
              'BREATHE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
