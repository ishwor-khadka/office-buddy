import 'package:flutter/material.dart';

import 'ob_tokens.dart';

class ObBackground extends StatelessWidget {
  const ObBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -0.55),
          radius: 1.25,
          colors: [
            ObTokens.canvas,
            ObTokens.canvasAlt,
          ],
        ),
      ),
      child: child,
    );
  }
}

