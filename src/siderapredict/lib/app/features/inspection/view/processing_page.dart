import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/processing_view_model.dart';

class ProcessingPage extends StatelessWidget {
  const ProcessingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProcessingViewModel>();
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: isHighContrast
            ? BoxDecoration(color: theme.scaffoldBackgroundColor)
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.brightness == Brightness.light
                      ? [primaryColor, paletteRed]
                      : [const Color(0xFF1E1E1E), const Color(0xFF121212)],
                ),
              ),
        child: Stack(
          children: [
            if (!isHighContrast)
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScannerAnimation(),
                    const SizedBox(height: 60),
                    Text(
                      'PROCESSANDO',
                      style: TextStyle(
                        color: isHighContrast
                            ? theme.colorScheme.primary
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        shadows: isHighContrast ? null : textShadows,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AnimatedText(message: viewModel.processingMessage),
                    const SizedBox(height: 40),
                    Container(
                      width: 40,
                      height: 2,
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? theme.colorScheme.primary
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 60),
                    Opacity(
                      opacity: 0.5,
                      child: AppLogo(
                        height: 24,
                        color: isHighContrast
                            ? theme.colorScheme.primary
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerAnimation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHighContrast ? Colors.transparent : Colors.white,
            border: isHighContrast
                ? Border.all(color: theme.colorScheme.primary, width: 3)
                : null,
            boxShadow: isHighContrast
                ? null
                : [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
          ),
          child: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: isHighContrast
                    ? theme.colorScheme.primary
                    : primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedText extends StatelessWidget {
  const _AnimatedText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    return Text(
      message,
      style: TextStyle(
        color: isHighContrast ? theme.colorScheme.onSurface : Colors.white,
        fontSize: 16,
        fontWeight: isHighContrast ? FontWeight.w900 : FontWeight.w300,
        letterSpacing: 2,
        shadows: isHighContrast ? null : textShadows,
      ),
      textAlign: TextAlign.center,
    );
  }
}
