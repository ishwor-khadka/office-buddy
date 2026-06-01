import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'ob_tokens.dart';

class ObBottomBar extends StatelessWidget {
  const ObBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex; // 0=Home, 1=Exercise
  final void Function(int index) onSelect;

  static const _items = [
    (icon: LucideIcons.home, label: 'Home'),
    (icon: LucideIcons.dumbbell, label: 'Exercise'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 72 + bottomPad,
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xF0EEF9F3), // light mint tint
                Color(0xF0EDE9FF), // light iris tint
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.75),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: ObTokens.iris.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
              BoxShadow(
                color: ObTokens.mintDeep.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              return Expanded(
                child: _NavItem(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  active: currentIndex == i,
                  onTap: () => onSelect(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [ObTokens.iris, ObTokens.sky],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: ObTokens.iris.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? Colors.white : ObTokens.textMuted,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: active
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
