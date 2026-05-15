import 'package:flutter/material.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, paletteRed],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle top right
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: whiteColor.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Decorative circle bottom left
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: whiteColor.withValues(alpha: 0.03),
              ),
            ),
          ),
          // Main content
          SafeArea(child: child),
        ],
      ),
    );
  }
}
