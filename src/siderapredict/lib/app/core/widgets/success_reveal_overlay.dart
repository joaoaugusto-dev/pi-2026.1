import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';

class SuccessRevealOverlay extends StatefulWidget {
  const SuccessRevealOverlay({
    super.key,
    required this.visible,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 2200),
    this.backgroundColor = whiteColor,
    this.revealColor = primaryColor,
    this.icon = Icons.check,
    this.iconColor = whiteColor,
    this.finalLabel,
  });

  final bool visible;
  final VoidCallback onComplete;
  final Duration duration;
  final Color backgroundColor;
  final Color revealColor;
  final IconData icon;
  final Color iconColor;
  final String? finalLabel;

  @override
  State<SuccessRevealOverlay> createState() => _SuccessRevealOverlayState();
}

class _SuccessRevealOverlayState extends State<SuccessRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _backgroundRadiusAnimation;
  late final Animation<double> _backgroundOpacityAnimation;
  late final Animation<double> _iconScaleAnimation;
  late final Animation<double> _revealRadiusAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _backgroundRadiusAnimation = Tween<double>(begin: 0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOutCubic),
      ),
    );

    _backgroundOpacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.1, curve: Curves.easeIn),
      ),
    );

    _iconScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.5, curve: Curves.elasticOut),
      ),
    );

    _revealRadiusAnimation = Tween<double>(begin: 0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.easeInOutQuart),
      ),
    );

    _controller.addListener(() {
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

    if (widget.visible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SuccessRevealOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _controller.forward(from: 0);
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

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                Opacity(
                  opacity: _backgroundOpacityAnimation.value,
                  child: CustomPaint(
                    size: size,
                    painter: _CircularRevealPainter(
                      fraction: _backgroundRadiusAnimation.value,
                      center: Offset(size.width / 2, size.height / 2),
                      maxRadius: maxRadius,
                      color: widget.backgroundColor,
                    ),
                  ),
                ),
                if (_controller.value > 0.5)
                  CustomPaint(
                    size: size,
                    painter: _CircularRevealPainter(
                      fraction: _revealRadiusAnimation.value,
                      center: Offset(size.width / 2, size.height / 2),
                      maxRadius: maxRadius,
                      color: widget.revealColor,
                    ),
                  ),
                if (_controller.value > 0.3 && _controller.value < 0.9)
                  Center(
                    child: ScaleTransition(
                      scale: _iconScaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.revealColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.iconColor,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                if (_controller.value >= 0.9)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: widget.iconColor, size: 80),
                        if (widget.finalLabel != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            widget.finalLabel!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.iconColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CircularRevealPainter extends CustomPainter {
  _CircularRevealPainter({
    required this.fraction,
    required this.center,
    required this.maxRadius,
    required this.color,
  });

  final double fraction;
  final Offset center;
  final double maxRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(center, maxRadius * fraction, paint);
  }

  @override
  bool shouldRepaint(covariant _CircularRevealPainter oldDelegate) {
    return oldDelegate.fraction != fraction || oldDelegate.color != color;
  }
}
