import 'package:flutter/material.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';

class PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final IconData? icon;
  final bool isLoading;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = primaryButtonStyle(backgroundColor: backgroundColor);

    if (isLoading) {
      return SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          style: style,
          onPressed: null,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: whiteColor,
            ),
          ),
        ),
      );
    }

    if (icon != null) {
      return SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton.icon(
          style: style,
          onPressed: onPressed,
          icon: Icon(icon, color: whiteColor),
          label: Text(
            label,
            style: const TextStyle(
              color: whiteColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: textShadows,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        style: style,
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: whiteColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: textShadows,
          ),
        ),
      ),
    );
  }
}
