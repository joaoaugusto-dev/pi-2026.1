import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/core/services/local_history_store.dart';
import 'package:siderapredict/app/core/services/ollama_report_service.dart';
import 'package:siderapredict/app/core/services/report_export_service.dart';
import 'package:siderapredict/app/core/services/supabase_image_storage_service.dart';
import 'package:siderapredict/app/core/services/supabase_measurement_service.dart';

class MeasurementRepository {
  MeasurementRepository({
    required LocalHistoryStore localStore,
    required SupabaseMeasurementService remoteService,
    required SupabaseImageStorageService imageStorageService,
    required OllamaReportService ollamaService,
    required ReportExportService exportService,
    required String? Function() currentUserIdProvider,
    required SharedPreferences sharedPreferences,
  }) : _localStore = localStore,
       _remoteService = remoteService,
       _imageStorageService = imageStorageService,
       _ollamaService = ollamaService,
       _exportService = exportService,
       _currentUserIdProvider = currentUserIdProvider,
       _prefs = sharedPreferences {
    _loadPendingDeletions();
  }

  final LocalHistoryStore _localStore;
  final SupabaseMeasurementService _remoteService;
  final SupabaseImageStorageService _imageStorageService;
  final OllamaReportService _ollamaService;
  final ReportExportService _exportService;
  final String? Function() _currentUserIdProvider;
  final SharedPreferences _prefs;

  final _recordUpdatesController =
      StreamController<MeasurementRecord>.broadcast();

  final Set<String> _activeReportJobs = <String>{};
  final Set<String> _remoteShellSaved = <String>{};
  final Map<String, int> _reportRetryAttempts = <String, int>{};
  final Map<String, Timer> _reportRetryTimers = <String, Timer>{};
  final Set<String> _pendingDeletions = <String>{};

  Completer<void>? _aiProcessingLock;
  int _sessionEpoch = 0;

  Stream<MeasurementRecord> get recordUpdates =>
      _recordUpdatesController.stream;

  Stream<List<MeasurementRecord>> get allRecords =>
      _remoteService.streamRecords();

  String? get _currentUserId => _currentUserIdProvider();

  void handleSessionChanged() {
    _sessionEpoch++;
    _activeReportJobs.clear();
    _remoteShellSaved.clear();
    _reportRetryAttempts.clear();
    for (final timer in _reportRetryTimers.values) {
      timer.cancel();
    }
    _reportRetryTimers.clear();
    _stopSyncTimer();
  }

  Timer? _syncTimer;

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(loadHistory());
    });
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  List<MeasurementRecord> reconcileRemoteSnapshot({
    required List<MeasurementRecord> currentHistory,
    required List<MeasurementRecord> remoteRecords,
  }) {
    final Map<String, MeasurementRecord> merged = <String, MeasurementRecord>{};
    final remoteById = {
      for (final record in remoteRecords)
        if (!_pendingDeletions.contains(record.id)) record.id: record,
    };

    for (final remote in remoteRecords) {
      if (_pendingDeletions.contains(remote.id)) {
        continue;
      }
      MeasurementRecord? local;
      for (final item in currentHistory) {
        if (item.id == remote.id) {
          local = item;
          break;
        }
      }
      merged[remote.id] = local == null
          ? remote
          : mergeRemoteRecordWithLocalFallback(local: local, remote: remote);
    }

    for (final local in currentHistory) {
      if (remoteById.containsKey(local.id)) {
        continue;
      }
      if (_shouldPreserveLocalOnlyRecord(local)) {
        merged[local.id] = local;
      }
    }

    final records = merged.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<List<MeasurementRecord>> reconcileAndPersistHistory({
    required List<MeasurementRecord> currentHistory,
    required List<MeasurementRecord> remoteRecords,
  }) async {
    final merged = reconcileRemoteSnapshot(
      currentHistory: currentHistory,
      remoteRecords: remoteRecords,
    );
    await _localStore.saveAll(merged);
    return merged;
  }

  Future<MeasurementRecord> saveMeasurement({
    required MeasurementDraft draft,
    required String pieceName,
    ConformityStatus conformityStatus = ConformityStatus.ok,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) async {
    final sessionEpoch = _sessionEpoch;
    final now = DateTime.now();

    final pieceNumber =
        draft.pieceNumberOfDay ?? await _nextPieceNumberOfDay(now);
    final persistedDraft = draft.copyWith(pieceNumberOfDay: pieceNumber);

    final record = MeasurementRecord(
      id: const Uuid().v4(),
      createdAt: now,
      pieceName: pieceName,
      primaryValueMm: draft.widthMm,
      aiReport: '',
      aiReportStatus: AiReportStatus.pending,
      draft: persistedDraft,
      ownerUserId: _currentUserId,
      conformityStatus: conformityStatus,
      nonConformityReason: nonConformityReason,
      nonConformityObservation: nonConformityObservation,
      responsavel: responsavel,
    );

    await _persistLocalRecord(record, sessionEpoch: sessionEpoch);
    _startSyncTimer(); // Start periodic sync if we just saved something locally

    final stagedRecord = await _prepareRemoteShellRecord(
      record,
      sessionEpoch: sessionEpoch,
    );
    if (!_isSessionCurrent(sessionEpoch)) {
      return stagedRecord;
    }
    _recordUpdatesController.add(
      stagedRecord.copyWith(aiReportStatus: AiReportStatus.generating),
    );
    unawaited(
      Future<void>.microtask(
        () => _generateReportInBackground(
          stagedRecord,
          sessionEpoch: sessionEpoch,
        ),
      ),
    );

    return stagedRecord;
  }

  Future<List<MeasurementRecord>> getLocalHistory() async {
    return _localStore.loadAll();
  }

  Future<List<MeasurementRecord>> loadHistory() async {
    final sessionEpoch = _sessionEpoch;
    final jsonRecords = await _localStore.loadAll();

    try {
      // 0. Push pending deletions first
      final toDelete = List<String>.from(_pendingDeletions);
      for (final id in toDelete) {
        try {
          await _remoteService.deleteRecord(id);
          _pendingDeletions.remove(id);
          await _savePendingDeletions();
        } catch (_) {
          // Still offline or failed, keep it in pending
        }
      }

      final remoteRecords = await _remoteService.fetchRecords().timeout(
        const Duration(seconds: 3),
      );
      if (!_isSessionCurrent(sessionEpoch)) {
        return const <MeasurementRecord>[];
      }
      _remoteShellSaved.addAll(remoteRecords.map((record) => record.id));
      final remoteById = {
        for (final record in remoteRecords) record.id: record,
      };

      final recordsList = reconcileRemoteSnapshot(
        currentHistory: jsonRecords,
        remoteRecords: remoteRecords,
      );

      final localOnly = jsonRecords.where(
        (lr) => !remoteRecords.any((rr) => rr.id == lr.id),
      );
      for (final r in localOnly) {
        if (!_canWriteRemoteRecord(r)) {
          continue;
        }
        final syncFuture = _canSyncRemote(r)
            ? _saveRemoteFinal(r, sessionEpoch: sessionEpoch)
            : _saveRemoteShell(r, sessionEpoch: sessionEpoch);
        unawaited(syncFuture.catchError((_) {}));
      }

      final outdatedRemote = jsonRecords.where((local) {
        final remote = remoteById[local.id];
        return remote != null &&
            _canWriteRemoteRecord(local) &&
            _needsRemoteFinalSync(local: local, remote: remote);
      });
      for (final record in outdatedRemote) {
        unawaited(
          _saveRemoteFinal(
            record,
            sessionEpoch: sessionEpoch,
          ).catchError((_) {}),
        );
      }

      await _localStore.saveAll(recordsList);
      if (!_isSessionCurrent(sessionEpoch)) {
        return const <MeasurementRecord>[];
      }

      final normalized = await _normalizeQueuedStatuses(recordsList);
      _resumeQueuedAiReports(normalized);
      return normalized;
    } catch (e) {
      debugPrint('Erro ao sincronizar histórico com Supabase: $e');
      _startSyncTimer(); // Ensure we keep trying if it failed
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

  Future<Uint8List?> imageBytesFor(
    MeasurementRecord record, {
    bool preferDetailedImage = false,
  }) {
    return _imageStorageService.imageBytesFor(
      record,
      preferDetailedImage: preferDetailedImage,
    );
  }

  Future<int> suggestNextPieceNumberOfDay([DateTime? createdAt]) {
    return _nextPieceNumberOfDay(createdAt ?? DateTime.now());
  }

  Future<void> deleteMeasurement(String recordId) async {
    _activeReportJobs.remove(recordId);
    _remoteShellSaved.remove(recordId);
    _reportRetryAttempts.remove(recordId);
    _reportRetryTimers.remove(recordId)?.cancel();

    final record = await _loadRecordById(recordId);
    if (record != null && !_canDeleteRecord(record)) {
      throw StateError('Sem permissão para excluir esta medição.');
    }
    await _localStore.deleteById(recordId);

    if (record != null) {
      await _imageStorageService.deleteImagesFor(record);
    }

    try {
      await _remoteService.deleteRecord(recordId);
      _pendingDeletions.remove(recordId);
      await _savePendingDeletions();
    } catch (e) {
      debugPrint('Erro ao excluir registro no Supabase (marcando para sync offline): $e');
      _pendingDeletions.add(recordId);
      await _savePendingDeletions();
      _startSyncTimer();
    }
  }

  static const String _pendingDeletionsKey = 'measurement_pending_deletions';

  void _loadPendingDeletions() {
    final list = _prefs.getStringList(_pendingDeletionsKey);
    if (list != null) {
      _pendingDeletions.addAll(list);
    }
  }

  Future<void> _savePendingDeletions() async {
    await _prefs.setStringList(_pendingDeletionsKey, _pendingDeletions.toList());
  }

  Future<void> _generateReportInBackground(
    MeasurementRecord record, {
    required int sessionEpoch,
  }) async {
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
      final shellRecord = await _prepareRemoteShellRecord(
        record,
        sessionEpoch: sessionEpoch,
      );
      if (!_isSessionCurrent(sessionEpoch)) {
        return;
      }
      _reportRetryTimers.remove(record.id)?.cancel();
      _activeReportJobs.add(record.id);
      var lastPersisted = shellRecord.copyWith(
        aiReportStatus: AiReportStatus.generating,
      );

      _recordUpdatesController.add(lastPersisted);

      var receivedFinalChunk = false;

      await for (final chunk in _ollamaService.streamReport(
        pieceName: record.pieceName,
        draft: record.draft,
        createdAt: record.createdAt,
        conformityStatus: record.conformityStatus,
        nonConformityReason: record.nonConformityReason,
        nonConformityObservation: record.nonConformityObservation,
        responsavel: record.responsavel,
      )) {
        lastPersisted = lastPersisted.copyWith(
          aiReport: chunk.fullText,
          aiReportStatus: chunk.isDone
              ? AiReportStatus.completed
              : AiReportStatus.generating,
        );
        if (!_isSessionCurrent(sessionEpoch)) {
          return;
        }
        _recordUpdatesController.add(lastPersisted);
        if (chunk.isDone) {
          receivedFinalChunk = true;
          debugPrint('Job IA para ${record.id} concluido com sucesso.');
        }
      }

      if (!receivedFinalChunk || lastPersisted.aiReport.trim().isEmpty) {
        throw StateError('Resposta vazia ou incompleta do Ollama');
      }

      await _persistFinalRecord(lastPersisted, sessionEpoch: sessionEpoch);
      _reportRetryAttempts.remove(record.id);
    } catch (e) {
      debugPrint('Erro no Job IA ${record.id}: $e');
      if (!_isSessionCurrent(sessionEpoch)) {
        return;
      }
      final queuedRecord = record.copyWith(
        aiReportStatus: AiReportStatus.pending,
      );
      await _persistLocalRecord(queuedRecord, sessionEpoch: sessionEpoch);
      _recordUpdatesController.add(queuedRecord);
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
      if (needsRetry && _canWriteRemoteRecord(record)) {
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

    await _generateReportInBackground(latest, sessionEpoch: _sessionEpoch);
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

  Future<MeasurementRecord> _attachStoredImages(
    MeasurementRecord record,
  ) async {
    if (record.photoStoragePath != null &&
        record.thumbnailStoragePath != null) {
      return record;
    }

    final imagePath = record.draft.processedImagePath.isNotEmpty
        ? record.draft.processedImagePath
        : record.draft.sourceImagePath;

    if (imagePath.isEmpty) {
      return record;
    }

    try {
      final detailedImage = await compute(_readImageBytesTask, imagePath);

      final thumbnailImage = await compute(
        _optimizeImageTask,
        _OptimizeImageParams(
          imagePath: imagePath,
          maxWidth: 300,
          jpegQuality: 60,
          maxBytes: 50000,
        ),
      );

      final stored = await _imageStorageService.uploadMeasurementImages(
        recordId: record.id,
        photoBytes: detailedImage,
        thumbnailBytes: thumbnailImage ?? detailedImage,
        ownerUserId: record.ownerUserId,
      );

      return record.copyWith(
        photoStoragePath: stored.photoStoragePath,
        thumbnailStoragePath: stored.thumbnailStoragePath,
      );
    } catch (e) {
      debugPrint('Erro ao enviar imagem ao Supabase Storage: $e');
      return record;
    }
  }

  Future<MeasurementRecord> _prepareRemoteShellRecord(
    MeasurementRecord record, {
    required int sessionEpoch,
  }) async {
    final recordWithImages = await _attachStoredImages(record);
    if (!_isSessionCurrent(sessionEpoch)) {
      return recordWithImages;
    }
    if (recordWithImages != record) {
      await _persistLocalRecord(recordWithImages, sessionEpoch: sessionEpoch);
    }
    await _saveRemoteShell(recordWithImages, sessionEpoch: sessionEpoch);
    return recordWithImages;
  }

  Future<void> _persistFinalRecord(
    MeasurementRecord record, {
    required int sessionEpoch,
  }) async {
    if (!_isSessionCurrent(sessionEpoch)) {
      return;
    }
    _recordUpdatesController.add(record);
    await _persistLocalRecord(record, sessionEpoch: sessionEpoch);
    await _saveRemoteFinal(record, sessionEpoch: sessionEpoch);
  }

  Future<void> _persistLocalRecord(
    MeasurementRecord record, {
    required int sessionEpoch,
  }) async {
    if (!_isSessionCurrent(sessionEpoch)) {
      return;
    }
    await _localStore.upsert(record);
  }

  Future<void> _saveRemoteFinal(
    MeasurementRecord record, {
    required int sessionEpoch,
  }) async {
    if (!_isSessionCurrent(sessionEpoch) ||
        !_canWriteRemoteRecord(record) ||
        !_canSyncRemote(record)) {
      return;
    }

    try {
      final recordWithImages = await _attachStoredImages(record);
      if (!_isSessionCurrent(sessionEpoch)) {
        return;
      }
      if (_hasLocalImageCandidate(recordWithImages) &&
          recordWithImages.photoStoragePath == null &&
          recordWithImages.thumbnailStoragePath == null) {
        debugPrint(
          'Registro ${record.id} mantido localmente: imagem ainda não foi enviada ao Storage.',
        );
        return;
      }

      await _remoteService.saveRecord(recordWithImages);
      if (recordWithImages != record) {
        await _persistLocalRecord(recordWithImages, sessionEpoch: sessionEpoch);
        _recordUpdatesController.add(recordWithImages);
      }
      _remoteShellSaved.add(record.id);
    } catch (e) {
      debugPrint('Erro ao salvar registro final no Supabase: $e');
    }
  }

  Future<void> _saveRemoteShell(
    MeasurementRecord record, {
    required int sessionEpoch,
  }) async {
    if (!_isSessionCurrent(sessionEpoch) ||
        !_canWriteRemoteRecord(record) ||
        _remoteShellSaved.contains(record.id)) {
      return;
    }

    try {
      await _remoteService.saveRecord(
        record.copyWith(aiReport: '', aiReportStatus: AiReportStatus.pending),
      );
      _remoteShellSaved.add(record.id);
    } catch (e) {
      debugPrint('Erro ao salvar registro inicial no Supabase: $e');
    }
  }

  bool _canSyncRemote(MeasurementRecord record) =>
      !record.isAiReportStreaming && record.aiReport.trim().isNotEmpty;

  bool _shouldPreserveLocalOnlyRecord(MeasurementRecord record) {
    return _canWriteRemoteRecord(record) &&
        (!_remoteShellSaved.contains(record.id) || record.isAiReportStreaming);
  }

  bool _canWriteRemoteRecord(MeasurementRecord record) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return false;
    }

    final ownerUserId = record.ownerUserId?.trim();
    return ownerUserId == null ||
        ownerUserId.isEmpty ||
        ownerUserId == currentUserId;
  }

  bool _canDeleteRecord(MeasurementRecord record) =>
      _canWriteRemoteRecord(record);

  bool _needsRemoteFinalSync({
    required MeasurementRecord local,
    required MeasurementRecord remote,
  }) {
    if (!_canSyncRemote(local)) {
      return false;
    }

    final aiMismatch = remote.aiReport != local.aiReport;
    final statusMismatch = remote.aiReportStatus != local.aiReportStatus;
    final photoMismatch = remote.photoStoragePath != local.photoStoragePath;
    final thumbnailMismatch =
        remote.thumbnailStoragePath != local.thumbnailStoragePath;

    return aiMismatch || statusMismatch || photoMismatch || thumbnailMismatch;
  }

  bool _hasLocalImageCandidate(MeasurementRecord record) =>
      record.draft.processedImagePath.trim().isNotEmpty ||
      record.draft.sourceImagePath.trim().isNotEmpty;

  bool _isSessionCurrent(int sessionEpoch) => sessionEpoch == _sessionEpoch;

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

Future<Uint8List?> _readImageBytesTask(String imagePath) async {
  if (imagePath.isEmpty) return null;

  final file = File(imagePath);
  if (!await file.exists()) return null;

  try {
    return file.readAsBytes();
  } catch (_) {
    return null;
  }
}

class _OptimizeImageParams {
  final String imagePath;
  final int maxWidth;
  final int jpegQuality;
  final int maxBytes;

  _OptimizeImageParams({
    required this.imagePath,
    required this.maxWidth,
    required this.jpegQuality,
    required this.maxBytes,
  });
}

Future<Uint8List?> _optimizeImageTask(_OptimizeImageParams params) async {
  if (params.imagePath.isEmpty) return null;

  final file = File(params.imagePath);
  if (!await file.exists()) return null;

  try {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return bytes.length <= params.maxBytes ? bytes : null;
    }

    final resized = decoded.width > params.maxWidth
        ? img.copyResize(decoded, width: params.maxWidth)
        : decoded;

    final encoded = Uint8List.fromList(
      img.encodeJpg(resized, quality: params.jpegQuality),
    );

    if (encoded.length > params.maxBytes) return null;
    return encoded;
  } catch (_) {
    return null;
  }
}
