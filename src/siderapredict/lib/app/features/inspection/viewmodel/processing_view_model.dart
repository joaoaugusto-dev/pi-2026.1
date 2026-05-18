import 'dart:async';
import 'package:flutter/material.dart';

import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/routes/app_router.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

class ProcessingViewModel extends ChangeNotifier {
  ProcessingViewModel({
    required InspectionViewModel inspectionViewModel,
    required this.imagePath,
  }) : _inspectionViewModel = inspectionViewModel {
    _inspectionViewModel.addListener(notifyListeners);
  }

  final InspectionViewModel _inspectionViewModel;
  final String imagePath;
  final List<String> _messages = const [
    'INICIALIZANDO MOTOR...',
    'ANALISANDO GEOMETRIA...',
    'EXTRAINDO MÉTRICAS...',
    'FINALIZANDO RELATÓRIO...',
  ];

  Timer? _messageTimer;
  int _messageIndex = 0;
  bool _started = false;

  bool get isProcessing => _inspectionViewModel.isProcessing;
  String? get lastError => _inspectionViewModel.lastError;
  MeasurementDraft? get currentDraft => _inspectionViewModel.currentDraft;
  String get processingMessage =>
      isProcessing ? _messages[_messageIndex] : 'CONCLUINDO...';

  void scheduleProcessing(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onReady(context);
    });
  }

  Future<void> onReady(BuildContext context) async {
    if (_started) return;
    _started = true;
    _startMessageCycle();

    await startProcessing();

    if (!context.mounted) return;

    final draft = currentDraft;
    if (draft == null || !draft.isValidMeasurement) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failureMessageFor(draft)),
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

  Future<void> startProcessing() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _inspectionViewModel.processCapturedImage(imagePath);
    try {
      await _inspectionViewModel.ensureCurrentDraftPieceNumberOfDay().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      // Piece numbering is a convenience and should not block validation.
    }
  }

  String failureMessageFor(MeasurementDraft? draft) {
    if (draft == null) {
      return lastError ?? 'Não foi possível processar a imagem.';
    }
    if (draft.isValidMeasurement) {
      return lastError ?? 'Processamento concluído.';
    }
    if (!draft.calibrationSuccess) {
      return 'Falha na calibração. A prancheta ArUco não foi totalmente detectada. Tente melhorar o enquadramento ou iluminação.';
    }
    if (!draft.objectFound) {
      return 'Peça não encontrada no centro da prancheta. Tente novamente.';
    }
    return 'Não foi possível extrair medidas válidas da peça. A foto pode estar borrada.';
  }

  void _startMessageCycle() {
    _messageTimer?.cancel();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      _messageIndex = (_messageIndex + 1) % _messages.length;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _inspectionViewModel.removeListener(notifyListeners);
    super.dispose();
  }
}
