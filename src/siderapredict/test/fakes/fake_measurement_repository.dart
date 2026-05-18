import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

/// Implementação fake de um repositório de medições para testes.
/// Armazena registros em memória sem nenhuma dependência externa.
///
/// Essa classe NÃO estende MeasurementRepository real porque
/// o construtor dele precisa de Supabase, SharedPreferences, etc.
/// Em vez disso, oferece a mesma interface pública que o
/// InspectionViewModel consome.
class FakeMeasurementRepository {
  final List<MeasurementRecord> _records = [];
  int _pieceCounter = 0;

  final _recordUpdatesController =
      StreamController<MeasurementRecord>.broadcast();
  final _allRecordsController =
      StreamController<List<MeasurementRecord>>.broadcast();

  Stream<MeasurementRecord> get recordUpdates =>
      _recordUpdatesController.stream;

  Stream<List<MeasurementRecord>> get allRecords =>
      _allRecordsController.stream;

  Future<MeasurementRecord> saveMeasurement({
    required MeasurementDraft draft,
    required String pieceName,
    ConformityStatus conformityStatus = ConformityStatus.ok,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) async {
    _pieceCounter++;

    final record = MeasurementRecord(
      id: 'fake-record-$_pieceCounter',
      createdAt: DateTime.now(),
      pieceName: pieceName,
      primaryValueMm: draft.primaryValueMm,
      aiReport: '',
      aiReportStatus: AiReportStatus.pending,
      draft: draft,
      ownerUserId: 'fake-uid-1',
      conformityStatus: conformityStatus,
      nonConformityReason: nonConformityReason,
      nonConformityObservation: nonConformityObservation,
      responsavel: responsavel,
    );

    _records.insert(0, record);
    _recordUpdatesController.add(record);
    return record;
  }

  Future<List<MeasurementRecord>> loadHistory() async {
    return List.unmodifiable(_records);
  }

  Future<List<MeasurementRecord>> getLocalHistory() async {
    return List.unmodifiable(_records);
  }

  Future<void> deleteMeasurement(String recordId) async {
    _records.removeWhere((r) => r.id == recordId);
  }

  Future<int> suggestNextPieceNumberOfDay([DateTime? createdAt]) async {
    return _pieceCounter + 1;
  }

  Future<Uint8List?> imageBytesFor(
    MeasurementRecord record, {
    bool preferDetailedImage = false,
  }) async {
    return null;
  }

  Future<File?> exportSingleRecordPdf(MeasurementRecord record) async =>
      null;

  Future<File?> exportSingleRecordExcel(MeasurementRecord record) async =>
      null;

  Future<File?> exportHistoryPdf(List<MeasurementRecord> records) async =>
      null;

  Future<File?> exportHistoryExcel(List<MeasurementRecord> records) async =>
      null;

  Future<List<MeasurementRecord>> reconcileAndPersistHistory({
    required List<MeasurementRecord> currentHistory,
    required List<MeasurementRecord> remoteRecords,
  }) async {
    return currentHistory;
  }

  void handleSessionChanged() {
    _records.clear();
  }

  void dispose() {
    _recordUpdatesController.close();
    _allRecordsController.close();
  }
}
