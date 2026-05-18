import 'package:flutter/material.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Widget _buildStyledLoader() {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: whiteColor.withValues(alpha: 0.15),
          border: Border.all(color: whiteColor.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3.0,
              valueColor: AlwaysStoppedAnimation<Color>(whiteColor),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: Container(
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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 5),
                  FadeTransition(
                    opacity: _fade,
                    child: Column(
                      children: [
                        const Text(
                          'SIDERA PREDICT',
                          style: TextStyle(
                            color: whiteColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 6,
                            shadows: textShadows,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          width: 60,
                          height: 2,
                          color: whiteColor.withValues(alpha: 0.5),
                        ),
                        const AppLogo(height: 80),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                  _buildStyledLoader(),
                  const Spacer(flex: 5),
                  FadeTransition(
                    opacity: _fade,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'VERSÃO 1.0',
                        style: TextStyle(
                          color: whiteColor.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
