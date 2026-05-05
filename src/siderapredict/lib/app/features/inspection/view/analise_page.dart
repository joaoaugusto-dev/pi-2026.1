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
    if (draft == null || !draft.isValidMeasurement) {
      String errorMessage = viewModel.lastError ?? 'Não foi possível processar a imagem.';
      if (draft != null && !draft.isValidMeasurement) {
        if (!draft.calibrationSuccess) {
          errorMessage = 'Falha na calibração. A prancheta ArUco não foi totalmente detectada. Tente melhorar o enquadramento ou iluminação.';
        } else if (!draft.objectFound) {
          errorMessage = 'Peça não encontrada no centro da prancheta. Tente novamente.';
        } else {
          errorMessage = 'Não foi possível extrair medidas válidas da peça. A foto pode estar borrada.';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
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
                        color: isHighContrast ? theme.colorScheme.primary : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        shadows: isHighContrast ? null : textShadows,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AnimatedText(isProcessing: isProcessing),
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
                        color: isHighContrast ? theme.colorScheme.primary : Colors.white,
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

class _ScannerAnimation extends StatefulWidget {
  @override
  State<_ScannerAnimation> createState() => _ScannerAnimationState();
}

class _ScannerAnimationState extends State<_ScannerAnimation> {
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
            boxShadow: isHighContrast ? null : [
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
                color: isHighContrast ? theme.colorScheme.primary : primaryColor,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light 
        ? theme.primaryColor == Colors.black 
        : theme.primaryColor == Colors.yellow;

    return Text(
      widget.isProcessing ? _messages[_index] : 'CONCLUINDO...',
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
