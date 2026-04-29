import 'package:flutter/material.dart';

import 'package:siderapredict/app/core/theme/theme.dart';

class CameraOverlay extends StatefulWidget {
  const CameraOverlay({
    super.key,
    required this.rollDegrees,
    required this.pitchDegrees,
  });

  final double rollDegrees;
  final double pitchDegrees;

  @override
  State<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends State<CameraOverlay> {

  @override
  Widget build(BuildContext context) {
    
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
            isVertical: false,
            alignment: horizontalAlign,
            isFineAligned: widget.rollDegrees.abs() < 2.0,
          ),
        ),

        
        Positioned(
          right: 15,
          top: 300, 
          bottom: 300,
          child: _buildLevelBar(
            isVertical: true,
            alignment: verticalAlign,
            isFineAligned: widget.pitchDegrees.abs() < 2.0,
          ),
        ),

        
        Center(
          child: Opacity(
            opacity: 0.1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 1, height: 16, color: whiteColor),
                Container(width: 16, height: 1, color: whiteColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelBar({
    required bool isVertical,
    required double alignment,
    required bool isFineAligned,
  }) {
    return Container(
      width: isVertical ? 10 : null,
      height: isVertical ? null : 10,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: whiteColor.withValues(alpha: 0.1),
          width: 0.5,
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
                  width: 4,
                  height: 0.5,
                  color: whiteColor.withValues(alpha: 0.1),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                5,
                (i) => Container(
                  width: 0.5,
                  height: 4,
                  color: whiteColor.withValues(alpha: 0.1),
                ),
              ),
            ),

          
          Container(
            width: isVertical ? 10 : 20,
            height: isVertical ? 20 : 10,
            decoration: BoxDecoration(
              border: Border.all(
                color: isFineAligned
                    ? confirmGreen.withValues(alpha: 0.3)
                    : whiteColor.withValues(alpha: 0.05),
                width: 0.5,
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
              width: isVertical ? 14 : 18,
              height: isVertical ? 18 : 14,
              decoration: BoxDecoration(
                color: isFineAligned ? confirmGreen : primaryColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: (isFineAligned ? confirmGreen : primaryColor)
                        .withValues(alpha: 0.4),
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
