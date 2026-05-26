import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'package:siderapredict/app/core/services/auth_service.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/inspection/data/measurement_repository.dart';
import 'package:siderapredict/app/core/services/measurement_service.dart';
import 'package:siderapredict/app/core/utils/automatic_piece_name_formatter.dart';

class InspectionViewModel extends ChangeNotifier {
  InspectionViewModel({
    required MeasurementService measurementService,
    required MeasurementRepository repository,
    required List<CameraDescription> cameras,
    AuthService? authService,
  }) : _measurementService = measurementService,
       _authService = authService ?? AuthService(),
       _repository = repository,
       availableCameras = cameras {
    _recordUpdatesSubscription = _repository.recordUpdates.listen(
      _mergeRecordUpdate,
    );
    _allRecordsSubscription = _repository.allRecords.listen(
      _updateHistoryFromRemote,
    );
    _activeAuthUserId = _authService.currentUser?.uid;
    _authStateSubscription = _authService.authStateChanges.listen(
      _handleAuthStateChanged,
    );
  }

  final MeasurementService _measurementService;
  final AuthService _authService;
  final MeasurementRepository _repository;
  late final StreamSubscription<MeasurementRecord> _recordUpdatesSubscription;
  late final StreamSubscription<List<MeasurementRecord>>
  _allRecordsSubscription;
  late final StreamSubscription<AuthenticatedUser?> _authStateSubscription;

  final List<CameraDescription> availableCameras;
  String? _activeAuthUserId;

  MeasurementDraft? currentDraft;
  List<MeasurementRecord> history = const <MeasurementRecord>[];
  bool isProcessing = false;
  bool isSaving = false;
  bool isLoadingHistory = false;
  String? lastError;

  String? get currentUserId => _activeAuthUserId;

  Future<void> processCapturedImage(String path) async {
    isProcessing = true;
    lastError = null;
    notifyListeners();

    try {
      currentDraft = await _measurementService.processImage(path);
    } catch (error) {
      lastError = error.toString();
      currentDraft = null;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<MeasurementRecord?> saveCurrentDraft({
    required String pieceName,
    ConformityStatus conformityStatus = ConformityStatus.ok,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) async {
    final draft = currentDraft;
    if (draft == null || !draft.isValidMeasurement) {
      lastError = 'Nao existe medicao valida para salvar.';
      notifyListeners();
      return null;
    }

    isSaving = true;
    lastError = null;
    notifyListeners();

    try {
      final saved = await _repository.saveMeasurement(
        pieceName: pieceName,
        draft: draft,
        conformityStatus: conformityStatus,
        nonConformityReason: nonConformityReason,
        nonConformityObservation: nonConformityObservation,
        responsavel: responsavel,
      );

      history = _upsertHistory(history, saved);

      return saved;
    } catch (error) {
      lastError = error.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    isLoadingHistory =
        history.isEmpty; // Only show spinner if we have NO data yet
    lastError = null;
    notifyListeners();

    try {
      // 1. First, load local data for immediate feedback
      final local = await _repository.getLocalHistory();
      if (local.isNotEmpty) {
        history = local;
        isLoadingHistory = false;
        notifyListeners();
      }

      // 2. Then, sync with remote
      history = await _repository.loadHistory();
    } catch (error) {
      lastError = error.toString();
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<File?> exportSingleRecordPdf(MeasurementRecord record) async {
    try {
      return await _repository.exportSingleRecordPdf(record);
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<File?> exportSingleRecordExcel(MeasurementRecord record) async {
    try {
      return await _repository.exportSingleRecordExcel(record);
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<File?> exportHistoryPdf() async {
    if (history.isEmpty) return null;
    try {
      return await _repository.exportHistoryPdf(history);
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<File?> exportHistoryExcel() async {
    if (history.isEmpty) return null;
    try {
      return await _repository.exportHistoryExcel(history);
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Uint8List?> imageBytesFor(
    MeasurementRecord record, {
    bool preferDetailedImage = false,
  }) {
    return _repository.imageBytesFor(
      record,
      preferDetailedImage: preferDetailedImage,
    );
  }

  Future<bool> deleteRecordById(String id) async {
    final snapshot = history;
    MeasurementRecord? targetRecord;
    for (final record in snapshot) {
      if (record.id == id) {
        targetRecord = record;
        break;
      }
    }

    if (targetRecord == null || !canDeleteRecord(targetRecord)) {
      return false;
    }

    history = snapshot
        .where((record) => record.id != id)
        .toList(growable: false);
    notifyListeners();

    try {
      await _repository.deleteMeasurement(id);
      return true;
    } catch (error) {
      history = snapshot;
      lastError = error.toString();
      notifyListeners();
      return false;
    }
  }

  MeasurementRecord? recordById(String id) {
    for (final record in history) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  bool canDeleteRecord(MeasurementRecord record) {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      return false;
    }

    final ownerUserId = record.ownerUserId?.trim();
    return ownerUserId == null ||
        ownerUserId.isEmpty ||
        ownerUserId == currentUserId;
  }

  bool isOwnedByCurrentUser(MeasurementRecord record) {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      return false;
    }

    final ownerUserId = record.ownerUserId?.trim();
    return ownerUserId == null ||
        ownerUserId.isEmpty ||
        ownerUserId == currentUserId;
  }

  void _mergeRecordUpdate(MeasurementRecord updatedRecord) {
    history = _upsertHistory(history, updatedRecord);
    notifyListeners();
  }

  void _updateHistoryFromRemote(List<MeasurementRecord> remoteRecords) {
    unawaited(
      _repository
          .reconcileAndPersistHistory(
            currentHistory: history,
            remoteRecords: remoteRecords,
          )
          .then((merged) {
            history = merged;
            notifyListeners();
          })
          .catchError((_) {}),
    );
  }

  List<MeasurementRecord> _upsertHistory(
    List<MeasurementRecord> source,
    MeasurementRecord record,
  ) {
    final existingIndex = source.indexWhere((item) => item.id == record.id);
    if (existingIndex == -1) {
      return <MeasurementRecord>[record, ...source]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final updatedHistory = List<MeasurementRecord>.from(source);
    updatedHistory[existingIndex] = record;
    updatedHistory.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return updatedHistory;
  }

  Future<void> ensureCurrentDraftPieceNumberOfDay() async {
    final draft = currentDraft;
    if (draft == null || draft.pieceNumberOfDay != null) {
      return;
    }

    final pieceNumber = await _repository.suggestNextPieceNumberOfDay();
    currentDraft = draft.copyWith(pieceNumberOfDay: pieceNumber);
    notifyListeners();
  }

  String suggestedPieceNameForCurrentDraft([DateTime? date]) {
    final draft = currentDraft;
    final pieceNumber = draft?.pieceNumberOfDay ?? 1;
    return buildAutomaticPieceName(
      pieceNumberOfDay: pieceNumber,
      date: date ?? DateTime.now(),
      employeeName: _authService.currentUser?.name,
    );
  }

  void clearDraft() {
    currentDraft = null;
    lastError = null;
    notifyListeners();
  }

  void _handleAuthStateChanged(AuthenticatedUser? user) {
    final nextUserId = user?.uid;
    if (nextUserId == _activeAuthUserId) {
      return;
    }

    _activeAuthUserId = nextUserId;
    _repository.handleSessionChanged();
    currentDraft = null;
    history = const <MeasurementRecord>[];
    lastError = null;
    isProcessing = false;
    isSaving = false;
    isLoadingHistory = false;
    notifyListeners();

    if (nextUserId != null) {
      unawaited(loadHistory());
    }
  }

  @override
  void dispose() {
    _recordUpdatesSubscription.cancel();
    _allRecordsSubscription.cancel();
    _authStateSubscription.cancel();
    super.dispose();
  }
}
