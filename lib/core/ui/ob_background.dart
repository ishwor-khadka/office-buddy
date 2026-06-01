import 'package:flutter/material.dart';


class ObBackground extends StatelessWidget {
  const ObBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFCEEDDA), // saturated mint
            Color(0xFFE2DEFF), // saturated iris/lavender
          ],
        ),
      ),
      child: child,
    );
  }
}

