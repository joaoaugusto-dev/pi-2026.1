import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/widgets/zoomable_image_overlay.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/routes/app_router.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

class ValidationViewModel extends ChangeNotifier {
  ValidationViewModel({
    required InspectionViewModel inspectionViewModel,
    required MeasurementDraft draft,
  }) : _inspectionViewModel = inspectionViewModel,
       currentDraft = draft {
    pieceName = _inspectionViewModel.suggestedPieceNameForCurrentDraft();
    pieceNameController = TextEditingController(text: pieceName);
    pieceNameController.addListener(_syncPieceNameFromController);
    _inspectionViewModel.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _inspectionViewModel.removeListener(notifyListeners);
    pieceNameController.removeListener(_syncPieceNameFromController);
    pieceNameController.dispose();
    pieceNameFocus.dispose();
    super.dispose();
  }

  final InspectionViewModel _inspectionViewModel;
  final MeasurementDraft currentDraft;
  final FocusNode pieceNameFocus = FocusNode();

  late final TextEditingController pieceNameController;

  String pieceName = '';
  ConformityStatus conformityStatus = ConformityStatus.ok;
  String? nonConformityReason;
  String? nonConformityObservation;
  bool showSaveSuccess = false;

  bool get isSaving => _inspectionViewModel.isSaving;
  bool get isLoading => isSaving;
  String? get lastError => _inspectionViewModel.lastError;
  String get primaryDisplay => currentDraft.isValidMeasurement
      ? '${currentDraft.primaryValueMm.toStringAsFixed(3)} mm'
      : '--';
  String get primaryLabel => currentDraft.isValidMeasurement
      ? 'Medida principal'
      : 'Aguardando medida válida';
  ImageProvider<Object>? get processedImageProvider =>
      currentDraft.processedImagePath.isEmpty
      ? null
      : FileImage(File(currentDraft.processedImagePath));
  String get validationErrorMessage {
    if (!currentDraft.calibrationSuccess) {
      return currentDraft.extraInfo?.trim().isNotEmpty == true
          ? currentDraft.extraInfo!
          : 'Falha na calibração de Ar Markers. Mantenha as bordas visíveis ao redor da peça e recapture.';
    }
    if (!currentDraft.objectFound) {
      return currentDraft.extraInfo?.trim().isNotEmpty == true
          ? currentDraft.extraInfo!
          : 'Calibração Ar Markers concluída, mas a peça não foi isolada para medição. Ajuste o enquadramento e refaça.';
    }
    return currentDraft.extraInfo?.trim().isNotEmpty == true
        ? currentDraft.extraInfo!
        : 'A homografia Ar Markers foi calculada, mas nenhuma medida válida da peça foi extraída nesta captura.';
  }

  List<String> get nonConformityReasons => const [
    'Ângulo incorreto',
    'Aresta fora de medida',
    'Furo deslocado',
    'Raio incorreto',
    'Peça amassada/danificada',
    'Rebarba',
    'Outro',
  ];

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

  void onConformityPressed(ConformityStatus status) {
    updateConformityStatus(status);
  }

  void onNonConformityReasonSelected(String reason, bool selected) {
    updateNonConformityReason(selected ? reason : null);
  }

  void onNonConformityObservationChanged(String observation) {
    updateNonConformityObservation(observation);
  }

  VoidCallback closeAction(BuildContext context) {
    return () => onClosePressed(context);
  }

  VoidCallback saveAction(BuildContext context) {
    return () => onSavePressed(context);
  }

  VoidCallback retakeAction(BuildContext context) {
    return () => onRetakePressed(context);
  }

  VoidCallback showImageAction(BuildContext context) {
    return () => onShowImagePressed(context);
  }

  VoidCallback editPieceNameAction(BuildContext context) {
    return () => onEditPieceNamePressed(context);
  }

  VoidCallback conformityAction(ConformityStatus status) {
    return () => onConformityPressed(status);
  }

  ValueChanged<bool> nonConformityReasonAction(String reason) {
    return (selected) => onNonConformityReasonSelected(reason, selected);
  }

  void onEditPieceNamePressed(BuildContext context) {
    FocusScope.of(context).requestFocus(pieceNameFocus);
  }

  void onClosePressed(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.menuPrincipal, (route) => false);
  }

  Future<void> onSavePressed(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();
    final record = await save(responsavel: authViewModel.userName);

    if (!context.mounted) return;

    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lastError ?? 'Não foi possível salvar.')),
      );
      return;
    }

    showSaveSuccess = true;
    notifyListeners();
  }

  void onSaveSuccessAnimationComplete(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.menuPrincipal, (route) => false);
  }

  void onRetakePressed(BuildContext context) {
    retake();
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.camera,
      arguments: CameraArgs(cameras: _inspectionViewModel.availableCameras),
    );
  }

  void onShowImagePressed(BuildContext context) {
    if (currentDraft.processedImagePath.isEmpty) return;
    ZoomableImageOverlay.show(
      context,
      imageProvider: FileImage(File(currentDraft.processedImagePath)),
    );
  }

  Future<MeasurementRecord?> save({String? responsavel}) async {
    return await _inspectionViewModel.saveCurrentDraft(
      pieceName: pieceName,
      conformityStatus: conformityStatus,
      nonConformityReason: nonConformityReason,
      nonConformityObservation: nonConformityObservation,
      responsavel: responsavel,
    );
  }

  void retake() {
    _inspectionViewModel.clearDraft();
  }

  void _syncPieceNameFromController() {
    pieceName = pieceNameController.text;
  }
}
