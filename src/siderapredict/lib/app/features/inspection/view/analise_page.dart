import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/routes/app_pages.dart';
import 'package:siderapredict/app/routes/app_routes.dart';
import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/analysis_viewmodel.dart';

class AnalisePage extends StatefulWidget {
  const AnalisePage({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<AnalisePage> createState() => _AnalisePageState();
}

class _AnalisePageState extends State<AnalisePage> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProcessing());
  }

  Future<void> _startProcessing() async {
    if (_started || !mounted) return;
    _started = true;

    final viewModel = context.read<AnalysisViewModel>();
    await viewModel.startProcessing();

    if (!mounted) return;

    final draft = viewModel.currentDraft;
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.lastError ?? 'Não foi possível processar a imagem.',
          ),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.validation,
      arguments: ValidationArgs(draft: draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AnalysisViewModel>();
    final isProcessing = viewModel.isProcessing;

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
              top: -50,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: whiteColor.withValues(alpha: 0.05),
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
                    const Text(
                      'PROCESSANDO',
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        shadows: textShadows,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AnimatedText(isProcessing: isProcessing),
                    const SizedBox(height: 40),
                    Container(
                      width: 40,
                      height: 2,
                      decoration: BoxDecoration(
                        color: whiteColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 60),
                    const Opacity(
                      opacity: 0.5,
                      child: AppLogo(height: 24),
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

class _ScannerAnimation extends StatefulWidget {
  @override
  State<_ScannerAnimation> createState() => _ScannerAnimationState();
}

class _ScannerAnimationState extends State<_ScannerAnimation> {

  @override
  void initState() {
    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        

        
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: whiteColor,
            boxShadow: [
              BoxShadow(
                color: whiteColor.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedText extends StatefulWidget {
  const _AnimatedText({required this.isProcessing});

  final bool isProcessing;

  @override
  State<_AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<_AnimatedText> {
  final List<String> _messages = const [
    'INICIALIZANDO MOTOR...',
    'ANALISANDO GEOMETRIA...',
    'EXTRAINDO MÉTRICAS...',
    'FINALIZANDO RELATÓRIO...',
  ];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _cycleMessages();
  }

  Future<void> _cycleMessages() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _messages.length;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.isProcessing ? _messages[_index] : 'CONCLUINDO...',
      style: const TextStyle(
        color: whiteColor,
        fontSize: 16,
        fontWeight: FontWeight.w300,
        letterSpacing: 2,
        shadows: textShadows,
      ),
      textAlign: TextAlign.center,
    );
  }
}
