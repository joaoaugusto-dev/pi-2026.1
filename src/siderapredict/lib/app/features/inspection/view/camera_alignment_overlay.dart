import 'package:flutter/material.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';

class CameraAlignmentOverlay extends StatefulWidget {
  const CameraAlignmentOverlay({
    super.key,
    required this.rollDegrees,
    required this.pitchDegrees,
  });

  final double rollDegrees;
  final double pitchDegrees;

  @override
  State<CameraAlignmentOverlay> createState() => _CameraAlignmentOverlayState();
}

class _CameraAlignmentOverlayState extends State<CameraAlignmentOverlay> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    const double barSensitivity = 12.0;
    final double horizontalAlign = (widget.rollDegrees / barSensitivity).clamp(
      -1.0,
      1.0,
    );
    final double verticalAlign = (widget.pitchDegrees / barSensitivity).clamp(
      -1.0,
      1.0,
    );

    return Stack(
      children: [
        Positioned(
          top: 120,
          left: 60,
          right: 60,
          child: _buildLevelBar(
            context,
            isVertical: false,
            alignment: horizontalAlign,
            isFineAligned: widget.rollDegrees.abs() < 2.0,
            isHighContrast: isHighContrast,
          ),
        ),

        Positioned(
          right: 15,
          top: 300,
          bottom: 300,
          child: _buildLevelBar(
            context,
            isVertical: true,
            alignment: verticalAlign,
            isFineAligned: widget.pitchDegrees.abs() < 2.0,
            isHighContrast: isHighContrast,
          ),
        ),

        Center(
          child: Opacity(
            opacity: isHighContrast ? 0.8 : 0.1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: isHighContrast ? 2 : 1,
                  height: 16,
                  color: isHighContrast
                      ? theme.colorScheme.primary
                      : Colors.white,
                ),
                Container(
                  width: 16,
                  height: isHighContrast ? 2 : 1,
                  color: isHighContrast
                      ? theme.colorScheme.primary
                      : Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelBar(
    BuildContext context, {
    required bool isVertical,
    required double alignment,
    required bool isFineAligned,
    required bool isHighContrast,
  }) {
    final theme = Theme.of(context);
    final accentColor = isFineAligned
        ? (isHighContrast ? theme.colorScheme.primary : confirmGreen)
        : (isHighContrast ? theme.colorScheme.onSurface : primaryColor);

    return Container(
      width: isVertical ? 14 : null,
      height: isVertical ? null : 14,
      decoration: BoxDecoration(
        color: isHighContrast
            ? Colors.black
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isHighContrast
              ? theme.colorScheme.primary
              : Colors.white.withValues(alpha: 0.2),
          width: isHighContrast ? 2 : 0.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isVertical)
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                5,
                (i) => Container(
                  width: 6,
                  height: 1,
                  color: isHighContrast
                      ? theme.colorScheme.primary
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                5,
                (i) => Container(
                  width: 1,
                  height: 6,
                  color: isHighContrast
                      ? theme.colorScheme.primary
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),

          Container(
            width: isVertical ? 14 : 24,
            height: isVertical ? 24 : 14,
            decoration: BoxDecoration(
              border: Border.all(
                color: isFineAligned
                    ? accentColor.withValues(alpha: 0.5)
                    : (isHighContrast
                          ? theme.colorScheme.primary
                          : Colors.white.withValues(alpha: 0.1)),
                width: isHighContrast ? 2 : 0.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          AnimatedAlign(
            duration: const Duration(milliseconds: 100),
            alignment: isVertical
                ? Alignment(0, alignment)
                : Alignment(alignment, 0),
            child: Container(
              width: isVertical ? 18 : 22,
              height: isVertical ? 22 : 18,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
                border: isHighContrast
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                boxShadow: isHighContrast
                    ? null
                    : [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
