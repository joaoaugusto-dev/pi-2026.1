import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/core/native_vision_bridge.dart';
import 'package:siderapredict/app/core/services/auth_service.dart';
import 'package:siderapredict/app/core/services/measurement_service.dart';
import 'package:siderapredict/app/features/inspection/data/measurement_repository.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

MeasurementDraft testMeasurementDraft({
  bool calibrationSuccess = true,
  bool objectFound = true,
  double widthMm = 42.5,
  double heightMm = 18.25,
  double perimeterMm = 125.4,
  double areaMm2 = 420.8,
  int? pieceNumberOfDay,
  String sourceImagePath = '/tmp/source.png',
  String processedImagePath = '/tmp/processed.png',
  List<PieceSegmentMeasurement>? segments,
  String? extraInfo,
}) {
  return MeasurementDraft(
    sourceImagePath: sourceImagePath,
    processedImagePath: processedImagePath,
    calibrationSuccess: calibrationSuccess,
    objectFound: objectFound,
    widthMm: widthMm,
    heightMm: heightMm,
    perimeterMm: perimeterMm,
    areaMm2: areaMm2,
    scaleMicronsPerPx: 48.2,
    markerSizeMm: 11,
    pieceNumberOfDay: pieceNumberOfDay,
    extraInfo: extraInfo,
    quickStatus: '4 marcadores | 12 cantos ChArUco',
    segments:
        segments ??
        const [
          PieceSegmentMeasurement(
            type: PieceSegmentType.overallWidth,
            label: 'Largura geral',
            valueMm: 42.5,
          ),
          PieceSegmentMeasurement(
            type: PieceSegmentType.hole,
            label: 'Furo 1',
            valueMm: 3.2,
            isRadius: true,
          ),
        ],
  );
}

MeasurementRecord testMeasurementRecord({
  String id = 'record-1',
  String pieceName = 'Peça 1',
  DateTime? createdAt,
  MeasurementDraft? draft,
  AiReportStatus aiReportStatus = AiReportStatus.completed,
  String aiReport = 'Relatorio técnico gerado.',
  String? photoBase64,
  String? thumbnailBase64,
  ConformityStatus conformityStatus = ConformityStatus.ok,
  String? nonConformityReason,
  String? nonConformityObservation,
  String? responsavel,
}) {
  final resolvedDraft = draft ?? testMeasurementDraft(pieceNumberOfDay: 1);
  return MeasurementRecord(
    id: id,
    pieceName: pieceName,
    createdAt: createdAt ?? DateTime(2026, 5, 14, 10, 30),
    primaryValueMm: resolvedDraft.primaryValueMm,
    aiReport: aiReport,
    aiReportStatus: aiReportStatus,
    draft: resolvedDraft,
    photoBase64: photoBase64,
    thumbnailBase64: thumbnailBase64,
    conformityStatus: conformityStatus,
    nonConformityReason: nonConformityReason,
    nonConformityObservation: nonConformityObservation,
    responsavel: responsavel,
  );
}

List<CameraDescription> testCameras() {
  return const [
    CameraDescription(
      name: 'back-camera',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];
}

class FakeNativeVisionBridge extends Fake implements NativeVisionBridge {
  FakeNativeVisionBridge(this.payload);

  Map<String, dynamic> payload;
  final analyzedPaths = <String>[];

  @override
  Future<Map<String, dynamic>> analyze(String inputPath) async {
    analyzedPaths.add(inputPath);
    return payload;
  }
}

class FakeMeasurementService extends Fake implements MeasurementService {
  MeasurementDraft? nextDraft;
  Object? nextError;
  final processedPaths = <String>[];

  @override
  Future<MeasurementDraft> processImage(String imagePath) async {
    processedPaths.add(imagePath);
    final error = nextError;
    if (error != null) {
      throw error;
    }
    return nextDraft ?? testMeasurementDraft(sourceImagePath: imagePath);
  }
}

class FakeMeasurementRepository extends Fake implements MeasurementRepository {
  final _recordUpdates = StreamController<MeasurementRecord>.broadcast();
  final _allRecords = StreamController<List<MeasurementRecord>>.broadcast();

  List<MeasurementRecord> storedHistory = <MeasurementRecord>[];
  MeasurementRecord? savedRecord;
  Object? saveError;
  Object? loadError;
  Object? deleteError;
  int nextPieceNumber = 1;
  File? exportedFile;
  String? deletedId;

  @override
  Stream<MeasurementRecord> get recordUpdates => _recordUpdates.stream;

  @override
  Stream<List<MeasurementRecord>> get allRecords => _allRecords.stream;

  void emitRecordUpdate(MeasurementRecord record) {
    _recordUpdates.add(record);
  }

  void emitAllRecords(List<MeasurementRecord> records) {
    _allRecords.add(records);
  }

  @override
  Future<MeasurementRecord> saveMeasurement({
    required MeasurementDraft draft,
    required String pieceName,
    ConformityStatus conformityStatus = ConformityStatus.ok,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }

    final record =
        savedRecord ??
        testMeasurementRecord(
          id: 'saved-record',
          pieceName: pieceName,
          draft: draft.copyWith(
            pieceNumberOfDay: draft.pieceNumberOfDay ?? nextPieceNumber,
          ),
          aiReportStatus: AiReportStatus.pending,
          aiReport: '',
          conformityStatus: conformityStatus,
          nonConformityReason: nonConformityReason,
          nonConformityObservation: nonConformityObservation,
          responsavel: responsavel,
        );
    storedHistory = <MeasurementRecord>[record, ...storedHistory];
    return record;
  }

  @override
  Future<List<MeasurementRecord>> loadHistory() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return storedHistory;
  }

  @override
  Future<File?> exportSingleRecordPdf(MeasurementRecord record) async {
    return exportedFile;
  }

  @override
  Future<File?> exportSingleRecordExcel(MeasurementRecord record) async {
    return exportedFile;
  }

  @override
  Future<File?> exportHistoryPdf(List<MeasurementRecord> records) async {
    return exportedFile;
  }

  @override
  Future<File?> exportHistoryExcel(List<MeasurementRecord> records) async {
    return exportedFile;
  }

  @override
  Future<int> suggestNextPieceNumberOfDay([DateTime? createdAt]) async {
    return nextPieceNumber;
  }

  @override
  Future<void> deleteMeasurement(String recordId) async {
    deletedId = recordId;
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    storedHistory = storedHistory
        .where((record) => record.id != recordId)
        .toList(growable: false);
  }

  Future<void> close() async {
    await _recordUpdates.close();
    await _allRecords.close();
  }
}

class FakeAuthService extends Fake implements AuthService {
  FirebaseAuthException? signInException;
  FirebaseAuthException? signUpException;
  Object? availabilityException;
  bool matriculaAvailable = true;
  bool emailAvailable = true;
  bool signOutCalled = false;
  String returnedUserName = 'João Operador';
  final signInRequests = <({String emailOrMatricula, String password})>[];
  final signUpRequests =
      <({String email, String password, String matricula, String nome})>[];

  @override
  Future<UserCredential?> signIn({
    required String emailOrMatricula,
    required String password,
  }) async {
    signInRequests.add((
      emailOrMatricula: emailOrMatricula,
      password: password,
    ));
    final exception = signInException;
    if (exception != null) {
      throw exception;
    }
    return FakeUserCredential(FakeUser('uid-login'));
  }

  @override
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String matricula,
    required String nome,
  }) async {
    signUpRequests.add((
      email: email,
      password: password,
      matricula: matricula,
      nome: nome,
    ));
    final exception = signUpException;
    if (exception != null) {
      throw exception;
    }
    return FakeUserCredential(FakeUser('uid-signup'));
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<bool> isMatriculaAvailable(String matricula) async {
    final error = availabilityException;
    if (error != null) {
      throw error;
    }
    return matriculaAvailable;
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    final error = availabilityException;
    if (error != null) {
      throw error;
    }
    return emailAvailable;
  }

  @override
  Future<String?> getUserName(String uid) async {
    return returnedUserName;
  }
}

class FakeUserCredential extends Fake implements UserCredential {
  FakeUserCredential(this._user);

  final User _user;

  @override
  User? get user => _user;
}

class FakeUser extends Fake implements User {
  FakeUser(this._uid);

  final String _uid;

  @override
  String get uid => _uid;
}
