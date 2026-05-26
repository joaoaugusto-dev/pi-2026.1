import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siderapredict/app/core/services/local_history_store.dart';
import 'package:siderapredict/app/core/services/ollama_report_service.dart';
import 'package:siderapredict/app/core/services/report_export_service.dart';
import 'package:siderapredict/app/core/services/supabase_image_storage_service.dart';
import 'package:siderapredict/app/core/services/supabase_measurement_service.dart';
import 'package:siderapredict/app/features/inspection/data/measurement_repository.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

void main() {
  group('MeasurementRepository', () {
    test(
      'TC30 — salva localmente sem esperar sincronizacao remota lenta',
      () async {
        SharedPreferences.setMockInitialValues({});
        final remoteService = _SlowRemoteMeasurementService(
          delay: const Duration(milliseconds: 800),
        );
        final localStore = _InMemoryLocalHistoryStore();
        final repository = MeasurementRepository(
          localStore: localStore,
          remoteService: remoteService,
          imageStorageService: _FakeImageStorageService(),
          ollamaService: _FakeOllamaReportService(),
          exportService: ReportExportService(),
          currentUserIdProvider: () => 'user-1',
          sharedPreferences: await SharedPreferences.getInstance(),
        );

        final stopwatch = Stopwatch()..start();
        final record = await repository.saveMeasurement(
          draft: _validDraft(),
          pieceName: 'Peca responsiva',
        );
        stopwatch.stop();

        expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 300)));
        expect(record.pieceName, 'Peca responsiva');
        expect(localStore.records, hasLength(1));
        expect(remoteService.saveAttempts, 0);

        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(remoteService.saveAttempts, greaterThanOrEqualTo(1));
      },
    );

    test('TC31 — otimiza imagem em JPEG Full HD sem distorcer proporcao', () {
      final original = img.Image(width: 4000, height: 2000)
        ..clear(img.ColorRgb8(220, 20, 20));
      final bytes = Uint8List.fromList(img.encodePng(original));

      final optimized = optimizeImageBytesForUpload(bytes);

      expect(optimized, isNotNull);
      expect(optimized![0], 0xFF);
      expect(optimized[1], 0xD8);

      final decoded = img.decodeImage(optimized);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(1920));
      expect(decoded.height, lessThanOrEqualTo(1080));
      expect(decoded.width, 1920);
      expect(decoded.height, 960);
      expect(
        decoded.width / decoded.height,
        closeTo(original.width / original.height, 0.01),
      );
    });

    test(
      'preserva bytes originais da imagem detalhada enviada ao Storage',
      () async {
        SharedPreferences.setMockInitialValues({});
        final directory = await Directory.systemTemp.createTemp(
          'sidera_original_image_test_',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        final originalImage = img.Image(width: 960, height: 540)
          ..clear(img.ColorRgb8(24, 24, 24));
        final originalBytes = Uint8List.fromList(img.encodePng(originalImage));
        final imageFile = File('${directory.path}/processed.png');
        await imageFile.writeAsBytes(originalBytes, flush: true);

        final imageStorageService = _CapturingImageStorageService();
        final repository = MeasurementRepository(
          localStore: _InMemoryLocalHistoryStore(),
          remoteService: _SlowRemoteMeasurementService(delay: Duration.zero),
          imageStorageService: imageStorageService,
          ollamaService: _FakeOllamaReportService(),
          exportService: ReportExportService(),
          currentUserIdProvider: () => 'user-1',
          sharedPreferences: await SharedPreferences.getInstance(),
        );

        await repository.saveMeasurement(
          draft: _validDraft().copyWith(processedImagePath: imageFile.path),
          pieceName: 'Peca com texto',
        );

        final uploadedPhotoBytes = await imageStorageService.uploadedPhotoBytes
            .timeout(const Duration(seconds: 2));

        expect(uploadedPhotoBytes, originalBytes);
      },
    );
  });
}

MeasurementDraft _validDraft() {
  return const MeasurementDraft(
    sourceImagePath: '',
    processedImagePath: '',
    calibrationSuccess: true,
    objectFound: true,
    widthMm: 120.5,
    heightMm: 85.3,
    perimeterMm: 411.6,
    areaMm2: 10278.65,
    scaleMicronsPerPx: 52.3,
    markerSizeMm: 11.0,
    segments: [
      PieceSegmentMeasurement(
        type: PieceSegmentType.overallWidth,
        label: 'Largura geral',
        valueMm: 120.5,
      ),
    ],
  );
}

class _InMemoryLocalHistoryStore extends LocalHistoryStore {
  _InMemoryLocalHistoryStore() : super(sessionKeyProvider: () => 'test-user');

  final List<MeasurementRecord> records = <MeasurementRecord>[];

  @override
  Future<List<MeasurementRecord>> loadAll() async {
    return List<MeasurementRecord>.from(records);
  }

  @override
  Future<void> saveAll(List<MeasurementRecord> records) async {
    this.records
      ..clear()
      ..addAll(records);
  }

  @override
  Future<void> upsert(MeasurementRecord record) async {
    records.removeWhere((item) => item.id == record.id);
    records.insert(0, record);
  }

  @override
  Future<void> deleteById(String recordId) async {
    records.removeWhere((record) => record.id == recordId);
  }
}

class _SlowRemoteMeasurementService extends SupabaseMeasurementService {
  _SlowRemoteMeasurementService({required this.delay})
    : super(tableName: 'fake_measurements');

  final Duration delay;
  int saveAttempts = 0;

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    await Future<void>.delayed(delay);
    saveAttempts++;
  }

  @override
  Future<List<MeasurementRecord>> fetchRecords() async {
    return const <MeasurementRecord>[];
  }

  @override
  Future<void> deleteRecord(String recordId) async {}

  @override
  Stream<List<MeasurementRecord>> streamRecords() {
    return const Stream<List<MeasurementRecord>>.empty();
  }
}

class _FakeImageStorageService extends SupabaseImageStorageService {
  _FakeImageStorageService() : super(bucketName: 'fake-images');

  @override
  Future<StoredMeasurementImages> uploadMeasurementImages({
    required String recordId,
    required Uint8List? photoBytes,
    required Uint8List? thumbnailBytes,
    String? ownerUserId,
  }) async {
    return const StoredMeasurementImages(
      photoStoragePath: null,
      thumbnailStoragePath: null,
    );
  }
}

class _CapturingImageStorageService extends SupabaseImageStorageService {
  _CapturingImageStorageService() : super(bucketName: 'fake-images');

  final Completer<Uint8List?> _uploadedPhotoBytes = Completer<Uint8List?>();

  Future<Uint8List?> get uploadedPhotoBytes => _uploadedPhotoBytes.future;

  @override
  Future<StoredMeasurementImages> uploadMeasurementImages({
    required String recordId,
    required Uint8List? photoBytes,
    required Uint8List? thumbnailBytes,
    String? ownerUserId,
  }) async {
    if (!_uploadedPhotoBytes.isCompleted) {
      _uploadedPhotoBytes.complete(photoBytes);
    }
    return const StoredMeasurementImages(
      photoStoragePath: 'user-1/record/photo.png',
      thumbnailStoragePath: 'user-1/record/thumb.jpg',
    );
  }
}

class _FakeOllamaReportService extends OllamaReportService {
  _FakeOllamaReportService()
    : super(baseUrl: 'https://fake.local', model: 'fake');

  @override
  Stream<AiReportChunk> streamReport({
    required String pieceName,
    required MeasurementDraft draft,
    required DateTime createdAt,
    required ConformityStatus conformityStatus,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) async* {
    yield const AiReportChunk(fullText: 'Relatorio IA fake.', isDone: true);
  }
}
