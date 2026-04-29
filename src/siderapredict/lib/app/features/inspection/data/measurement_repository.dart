import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';


import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/core/services/firestore_service.dart';
import 'package:siderapredict/app/core/services/local_history_store.dart';
import 'package:siderapredict/app/core/services/ollama_report_service.dart';
import 'package:siderapredict/app/core/services/report_export_service.dart';

class MeasurementRepository {
  MeasurementRepository({
    required LocalHistoryStore localStore,
    required FirestoreService firestoreService,
    required OllamaReportService ollamaService,
    required ReportExportService exportService,
  })  : _localStore = localStore,
        _firestoreService = firestoreService,
        _ollamaService = ollamaService,
        _exportService = exportService;

  final LocalHistoryStore _localStore;
  final FirestoreService _firestoreService;
  final OllamaReportService _ollamaService;
  final ReportExportService _exportService;

  final _recordUpdatesController = StreamController<MeasurementRecord>.broadcast();

  final Set<String> _activeReportJobs = <String>{};
  final Map<String, int> _reportRetryAttempts = <String, int>{};
  final Map<String, Timer> _reportRetryTimers = <String, Timer>{};

  Completer<void>? _aiProcessingLock;

  Stream<MeasurementRecord> get recordUpdates => _recordUpdatesController.stream;

  Stream<List<MeasurementRecord>> get allRecords => _firestoreService.streamRecords();

  Future<MeasurementRecord> saveMeasurement({
    required MeasurementDraft draft,
    required String pieceName,
  }) async {
    final now = DateTime.now();

    final pieceNumber = draft.pieceNumberOfDay ?? await _nextPieceNumberOfDay(now);
    final persistedDraft = draft.copyWith(pieceNumberOfDay: pieceNumber);

    final imagePath = draft.processedImagePath.isNotEmpty 
        ? draft.processedImagePath 
        : draft.sourceImagePath;

    final historyImage = await compute(_optimizeImageTask, _OptimizeImageParams(
      imagePath: imagePath,
      maxWidth: 1000,
      jpegQuality: 70,
      maxBase64Length: 600000,
    ));
    
    final thumbnailImage = await compute(_optimizeImageTask, _OptimizeImageParams(
      imagePath: imagePath,
      maxWidth: 300,
      jpegQuality: 60,
      maxBase64Length: 50000,
    ));

    final record = MeasurementRecord(
      id: const Uuid().v4(),
      createdAt: now,
      pieceName: pieceName,
      primaryValueMm: draft.widthMm,
      aiReport: '',
      aiReportStatus: AiReportStatus.pending,
      draft: persistedDraft,
      photoBase64: historyImage,
      thumbnailBase64: thumbnailImage ?? historyImage,
    );

    await _persistRecord(record);
    unawaited(
      Future<void>.microtask(() => _generateReportInBackground(record)),
    );

    return record;
  }

  Future<List<MeasurementRecord>> loadHistory() async {
    final jsonRecords = await _localStore.loadAll();
    
    try {
      final firestoreRecords = await _firestoreService.fetchRecords();
      
      final Map<String, MeasurementRecord> merged = {
        for (final r in jsonRecords) r.id: r,
        for (final r in firestoreRecords) r.id: r,
      };

      final recordsList = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final localOnly = jsonRecords.where((lr) => !firestoreRecords.any((fr) => fr.id == lr.id));
      for (final r in localOnly) {
        unawaited(_firestoreService.saveRecord(r).catchError((_) {}));
      }

      await _localStore.saveAll(recordsList);
      
      final normalized = await _normalizeQueuedStatuses(recordsList);
      _resumeQueuedAiReports(normalized);
      return normalized;
    } catch (e) {
      debugPrint('Erro ao sincronizar histórico com Firestore: $e');
      final normalized = await _normalizeQueuedStatuses(jsonRecords);
      _resumeQueuedAiReports(normalized);
      return normalized;
    }
  }

  Future<File?> exportSingleRecordPdf(MeasurementRecord record) {
    return _exportService.exportSingleRecordPdf(record);
  }

  Future<File?> exportSingleRecordExcel(MeasurementRecord record) {
    return _exportService.exportSingleRecordExcel(record);
  }

  Future<File?> exportHistoryPdf(List<MeasurementRecord> records) {
    return _exportService.exportHistoryPdf(records);
  }

  Future<File?> exportHistoryExcel(List<MeasurementRecord> records) {
    return _exportService.exportHistoryExcel(records);
  }

  Future<int> suggestNextPieceNumberOfDay([DateTime? createdAt]) {
    return _nextPieceNumberOfDay(createdAt ?? DateTime.now());
  }

  Future<void> deleteMeasurement(String recordId) async {
    _activeReportJobs.remove(recordId);
    _reportRetryAttempts.remove(recordId);
    _reportRetryTimers.remove(recordId)?.cancel();

    await _localStore.deleteById(recordId);

    try {
      await _firestoreService.deleteRecord(recordId);
    } catch (e) {
      debugPrint('Erro ao excluir registro no Firestore: $e');
    }
  }

  Future<void> _generateReportInBackground(MeasurementRecord record) async {
    debugPrint('Job IA solicitado para ${record.id}');
    while (_aiProcessingLock != null) {
      debugPrint('Aguardando lock IA para ${record.id}...');
      await _aiProcessingLock!.future;
    }

    if (_activeReportJobs.contains(record.id)) {
      debugPrint('Job IA para ${record.id} ja esta em execucao.');
      return;
    }

    _aiProcessingLock = Completer<void>();
    debugPrint('Iniciando Job IA para ${record.id}');
    
    try {
      _reportRetryTimers.remove(record.id)?.cancel();
      _activeReportJobs.add(record.id);
      var lastPersisted = record.copyWith(
        aiReportStatus: AiReportStatus.generating,
      );

      await _persistAndBroadcast(lastPersisted);

      var receivedFinalChunk = false;

      await for (final chunk in _ollamaService.streamReport(
        pieceName: record.pieceName,
        draft: record.draft,
        createdAt: record.createdAt,
      )) {
        lastPersisted = lastPersisted.copyWith(
          aiReport: chunk.fullText,
          aiReportStatus: chunk.isDone
              ? AiReportStatus.completed
              : AiReportStatus.generating,
        );
        unawaited(_persistAndBroadcast(lastPersisted));
        if (chunk.isDone) {
          receivedFinalChunk = true;
          debugPrint('Job IA para ${record.id} concluido com sucesso.');
        }
      }

      if (!receivedFinalChunk || lastPersisted.aiReport.trim().isEmpty) {
        throw StateError('Resposta vazia ou incompleta do Ollama');
      }

      _reportRetryAttempts.remove(record.id);
    } catch (e) {
      debugPrint('Erro no Job IA ${record.id}: $e');
      final queuedRecord = record.copyWith(
        aiReportStatus: AiReportStatus.pending,
      );
      await _persistAndBroadcast(queuedRecord);
      _scheduleReportRetry(queuedRecord.id);
    } finally {
      _activeReportJobs.remove(record.id);
      final lock = _aiProcessingLock;
      _aiProcessingLock = null;
      lock?.complete();
      debugPrint('Lock IA liberado apos Job ${record.id}');
    }
  }

  Future<List<MeasurementRecord>> _normalizeQueuedStatuses(
    List<MeasurementRecord> records,
  ) async {
    var changed = false;

    final normalized = records
        .map((record) {
          if (record.aiReportStatus == AiReportStatus.generating) {
            changed = true;
            return record.copyWith(aiReportStatus: AiReportStatus.pending);
          }
          return record;
        })
        .toList(growable: false);

    if (changed) {
      await _localStore.saveAll(normalized);
    }

    return normalized;
  }

  void _resumeQueuedAiReports(List<MeasurementRecord> records) {
    for (final record in records) {
      final needsRetry =
          record.aiReportStatus == AiReportStatus.pending ||
          record.aiReportStatus == AiReportStatus.generating;
      if (needsRetry) {
        _scheduleReportRetry(record.id, immediate: true);
      }
    }
  }

  void _scheduleReportRetry(String recordId, {bool immediate = false}) {
    if (_activeReportJobs.contains(recordId)) {
      return;
    }

    _reportRetryTimers.remove(recordId)?.cancel();

    final attempt = (_reportRetryAttempts[recordId] ?? 0) + 1;
    _reportRetryAttempts[recordId] = attempt;

    final delay = immediate
        ? const Duration(seconds: 1)
        : _retryDelayForAttempt(attempt);

    _reportRetryTimers[recordId] = Timer(delay, () {
      _reportRetryTimers.remove(recordId);
      unawaited(_retryQueuedReport(recordId));
    });
  }

  Duration _retryDelayForAttempt(int attempt) {
    const retryScheduleSeconds = <int>[2, 10, 30, 60, 120, 300];
    final index = attempt - 1;
    final boundedIndex = index < retryScheduleSeconds.length
        ? index
        : retryScheduleSeconds.length - 1;
    return Duration(seconds: retryScheduleSeconds[boundedIndex]);
  }

  Future<void> _retryQueuedReport(String recordId) async {
    if (_activeReportJobs.contains(recordId)) {
      return;
    }

    final latest = await _loadRecordById(recordId);
    if (latest == null) {
      _reportRetryAttempts.remove(recordId);
      return;
    }

    final needsRetry =
        latest.aiReportStatus == AiReportStatus.pending ||
        latest.aiReportStatus == AiReportStatus.generating;

    if (!needsRetry) {
      _reportRetryAttempts.remove(recordId);
      return;
    }

    await _generateReportInBackground(latest);
  }

  Future<MeasurementRecord?> _loadRecordById(String recordId) async {
    final records = await _localStore.loadAll();
    for (final record in records) {
      if (record.id == recordId) {
        return record;
      }
    }
    return null;
  }

  Future<void> _persistAndBroadcast(MeasurementRecord record) async {
    _recordUpdatesController.add(record);
    await _persistRecord(record);
  }

  Future<void> _persistRecord(MeasurementRecord record) async {
    await _localStore.upsert(record);

    try {
      await _firestoreService.saveRecord(record);
    } catch (e) {
      debugPrint('Erro ao salvar registro no Firestore: $e');
    }
  }

  Future<int> _nextPieceNumberOfDay(DateTime createdAt) async {
    final currentRecords = await _localStore.loadAll();
    final localCreatedAt = createdAt.toLocal();

    final countForDay = currentRecords.where((record) {
      final recordDate = record.createdAt.toLocal();
      return recordDate.year == localCreatedAt.year &&
          recordDate.month == localCreatedAt.month &&
          recordDate.day == localCreatedAt.day;
    }).length;

    return countForDay + 1;
  }

}

class _OptimizeImageParams {
  final String imagePath;
  final int maxWidth;
  final int jpegQuality;
  final int maxBase64Length;

  _OptimizeImageParams({
    required this.imagePath,
    required this.maxWidth,
    required this.jpegQuality,
    required this.maxBase64Length,
  });
}

Future<String?> _optimizeImageTask(_OptimizeImageParams params) async {
  if (params.imagePath.isEmpty) return null;

  final file = File(params.imagePath);
  if (!await file.exists()) return null;

  try {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      final rawBase64 = base64Encode(bytes);
      return rawBase64.length <= params.maxBase64Length ? rawBase64 : null;
    }

    final resized = decoded.width > params.maxWidth
        ? img.copyResize(decoded, width: params.maxWidth)
        : decoded;
    
    final encoded = img.encodeJpg(resized, quality: params.jpegQuality);
    final base64 = base64Encode(encoded);

    if (base64.length > params.maxBase64Length) return null;
    return base64;
  } catch (_) {
    return null;
  }
}
