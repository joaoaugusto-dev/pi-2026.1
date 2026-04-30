import 'package:flutter/foundation.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_viewmodel.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class ValidationViewModel extends ChangeNotifier {
  ValidationViewModel({
    required InspectionViewModel inspectionViewModel,
    required MeasurementDraft draft,
  })  : _inspectionViewModel = inspectionViewModel,
        currentDraft = draft {
    pieceName = _inspectionViewModel.suggestedPieceNameForCurrentDraft();
    _inspectionViewModel.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _inspectionViewModel.removeListener(notifyListeners);
    super.dispose();
  }

  final InspectionViewModel _inspectionViewModel;
  final MeasurementDraft currentDraft;

  String pieceName = '';
  ConformityStatus conformityStatus = ConformityStatus.ok;
  String? nonConformityReason;
  String? nonConformityObservation;

  bool get isSaving => _inspectionViewModel.isSaving;
  bool get isLoading => isSaving;
  String? get lastError => _inspectionViewModel.lastError;

  void updatePieceName(String name) {
    pieceName = name;
    notifyListeners();
  }

  void updateConformityStatus(ConformityStatus status) {
    conformityStatus = status;
    if (status == ConformityStatus.ok) {
      nonConformityReason = null;
      nonConformityObservation = null;
    }
    notifyListeners();
  }

  void updateNonConformityReason(String? reason) {
    nonConformityReason = reason;
    notifyListeners();
  }

  void updateNonConformityObservation(String? observation) {
    nonConformityObservation = observation;
    notifyListeners();
  }

  Future<MeasurementRecord?> save() async {
    return await _inspectionViewModel.saveCurrentDraft(
      pieceName: pieceName,
      conformityStatus: conformityStatus,
      nonConformityReason: nonConformityReason,
      nonConformityObservation: nonConformityObservation,
    );
  }

  void retake() {
    _inspectionViewModel.clearDraft();
  }
}
