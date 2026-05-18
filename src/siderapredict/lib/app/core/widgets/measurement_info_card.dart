import 'package:flutter/material.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';

class MeasurementInfoCard extends StatefulWidget {
  final String title;
  final String value;
  final Duration delay;

  const MeasurementInfoCard({
    super.key,
    required this.title,
    required this.value,
    this.delay = Duration.zero,
  });

  @override
  State<MeasurementInfoCard> createState() => _MeasurementInfoCardState();
}

class _MeasurementInfoCardState extends State<MeasurementInfoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: isHighContrast
                ? BorderRadius.zero
                : BorderRadius.circular(12),
            boxShadow: isHighContrast ? null : subtleShadows,
            border: isHighContrast
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    children: [
                      TextSpan(
                        text: '${widget.title}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: widget.value),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
