import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_viewmodel.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class AnalysisViewModel extends ChangeNotifier {
  AnalysisViewModel({
    required InspectionViewModel inspectionViewModel,
    required this.imagePath,
  }) : _inspectionViewModel = inspectionViewModel;

  final InspectionViewModel _inspectionViewModel;
  final String imagePath;

  bool get isProcessing => _inspectionViewModel.isProcessing;
  String? get lastError => _inspectionViewModel.lastError;
  MeasurementDraft? get currentDraft => _inspectionViewModel.currentDraft;

  Future<void> startProcessing() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _inspectionViewModel.processCapturedImage(imagePath);
    try {
      await _inspectionViewModel.ensureCurrentDraftPieceNumberOfDay().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      
    }
  }
}
