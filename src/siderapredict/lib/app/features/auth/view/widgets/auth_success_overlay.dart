import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';

class AuthSuccessOverlay extends StatefulWidget {
  final bool visible;
  final VoidCallback onComplete;

  const AuthSuccessOverlay({
    super.key,
    required this.visible,
    required this.onComplete,
  });

  @override
  State<AuthSuccessOverlay> createState() => _AuthSuccessOverlayState();
}

class _AuthSuccessOverlayState extends State<AuthSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // White Reveal
  late Animation<double> _whiteRadiusAnimation;
  late Animation<double> _whiteOpacityAnimation;

  // Checkmark
  late Animation<double> _checkScaleAnimation;

  // Primary Reveal (The "Red" expansion)
  late Animation<double> _primaryRadiusAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // 1. White background fills the screen (0.0 -> 1.0s)
    _whiteRadiusAnimation = Tween<double>(begin: 0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOutCubic),
      ),
    );

    _whiteOpacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.1, curve: Curves.easeIn),
      ),
    );

    // 2. Checkmark pops (0.9s -> 1.5s)
    _checkScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.5, curve: Curves.elasticOut),
      ),
    );

    // 3. Primary color (Red) expands from the checkmark center to fill the screen (1.5s -> 2.7s)
    _primaryRadiusAnimation = Tween<double>(begin: 0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.easeInOutQuart),
      ),
    );

    _controller.addListener(() {
      // Change status bar when primary color hits the top (around 0.8)
      if (_controller.value >= 0.8) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        );
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void didUpdateWidget(AuthSuccessOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && _controller.status == AnimationStatus.dismissed) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Stage 1: White Background
            Opacity(
              opacity: _whiteOpacityAnimation.value,
              child: CustomPaint(
                size: size,
                painter: _CircularRevealPainter(
                  fraction: _whiteRadiusAnimation.value,
                  center: Offset(size.width / 2, size.height / 2),
                  maxRadius: maxRadius,
                  color: whiteColor,
                ),
              ),
            ),

            // Stage 3: Primary (Red) expansion
            if (_controller.value > 0.5)
              CustomPaint(
                size: size,
                painter: _CircularRevealPainter(
                  fraction: _primaryRadiusAnimation.value,
                  center: Offset(size.width / 2, size.height / 2),
                  maxRadius: maxRadius,
                  color: primaryColor,
                ),
              ),

            // Stage 2: Checkmark Icon
            if (_controller.value > 0.3 && _controller.value < 0.9)
              Center(
                child: ScaleTransition(
                  scale: _checkScaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: whiteColor, size: 60),
                  ),
                ),
              ),

            // Final checkmark inside the fully colored screen
            if (_controller.value >= 0.9)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: const Icon(Icons.check, color: whiteColor, size: 80),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CircularRevealPainter extends CustomPainter {
  final double fraction;
  final Offset center;
  final double maxRadius;
  final Color color;

  _CircularRevealPainter({
    required this.fraction,
    required this.center,
    required this.maxRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(center, maxRadius * fraction, paint);
  }

  @override
  bool shouldRepaint(covariant _CircularRevealPainter oldDelegate) {
    return oldDelegate.fraction != fraction;
  }
}
