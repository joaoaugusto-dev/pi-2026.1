import 'package:flutter/material.dart';

import 'package:siderapredict/app/core/widgets/success_reveal_overlay.dart';

class AuthSuccessOverlay extends StatelessWidget {
  const AuthSuccessOverlay({
    super.key,
    required this.visible,
    required this.onComplete,
  });

  final bool visible;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return SuccessRevealOverlay(
      visible: visible,
      onComplete: onComplete,
      duration: const Duration(milliseconds: 3000),
    );
  }
}
