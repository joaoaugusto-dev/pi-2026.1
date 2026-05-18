import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

/// Testes de Unidade — Validação e Submit de Relatório
void main() {
  group("Submit de Relatório - Validação do Draft", () {
    test("TC17 — Draft válido permite salvar medição", () {
      //ACT
      final draft = _criarDraftValido();
      //ASSERT
      expect(draft.isValidMeasurement, isTrue);
      expect(draft.primaryValueMm, 120.5);
      expect(draft.hasDimensionData, isTrue);
    });

    test("TC18 — Draft sem calibração não permite salvar", () {
      //ACT
      final draft = MeasurementDraft(
        sourceImagePath: '/fake/image.jpg', processedImagePath: '',
        calibrationSuccess: false, objectFound: false,
        widthMm: 0, heightMm: 0, perimeterMm: 0, areaMm2: 0,
        scaleMicronsPerPx: null, markerSizeMm: 11.0, segments: const [],
      );
      //ASSERT
      expect(draft.isValidMeasurement, isFalse);
    });

    test("TC19 — MeasurementRecord criado com dados completos", () {
      //ARRANGE
      final draft = _criarDraftValido();
      //ACT
      final record = MeasurementRecord(
        id: 'record-1', pieceName: 'Peça A', createdAt: DateTime(2026, 5, 17),
        primaryValueMm: draft.primaryValueMm, aiReport: '',
        aiReportStatus: AiReportStatus.pending, draft: draft,
        ownerUserId: 'user-123', responsavel: 'João',
      );
      //ASSERT
      expect(record.pieceName, 'Peça A');
      expect(record.responsavel, 'João');
    });

    test("TC20 — Draft sem peça encontrada é inválido", () {
      //ACT
      final draft = MeasurementDraft(
        sourceImagePath: '/f.jpg', processedImagePath: '/p.jpg',
        calibrationSuccess: true, objectFound: false,
        widthMm: 0, heightMm: 0, perimeterMm: 0, areaMm2: 0,
        scaleMicronsPerPx: 52.3, markerSizeMm: 11.0, segments: const [],
      );
      //ASSERT
      expect(draft.isValidMeasurement, isFalse);
      expect(draft.objectFound, isFalse);
    });
  });

  group("Submit de Relatório - Conformidade", () {
    test("TC21 — Registro OK não tem motivo de reprovação", () {
      //ACT
      final record = MeasurementRecord(
        id: 'r1', pieceName: 'Peça OK', createdAt: DateTime.now(),
        primaryValueMm: 100.0, aiReport: '',
        aiReportStatus: AiReportStatus.pending, draft: _criarDraftValido(),
        conformityStatus: ConformityStatus.ok,
      );
      //ASSERT
      expect(record.conformityStatus, ConformityStatus.ok);
      expect(record.nonConformityReason, isNull);
    });

    test("TC22 — Registro NOK registra motivo", () {
      //ACT
      final record = MeasurementRecord(
        id: 'r2', pieceName: 'Reprovada', createdAt: DateTime.now(),
        primaryValueMm: 100.0, aiReport: '',
        aiReportStatus: AiReportStatus.pending, draft: _criarDraftValido(),
        conformityStatus: ConformityStatus.nok,
        nonConformityReason: 'Rebarba',
        nonConformityObservation: 'Visível na aresta esquerda',
      );
      //ASSERT
      expect(record.conformityStatus, ConformityStatus.nok);
      expect(record.nonConformityReason, 'Rebarba');
    });

    test("TC23 — copyWith altera conformidade mantendo dados", () {
      //ARRANGE
      final original = MeasurementRecord(
        id: 'r3', pieceName: 'Peça X', createdAt: DateTime.now(),
        primaryValueMm: 50.0, aiReport: '',
        aiReportStatus: AiReportStatus.pending, draft: _criarDraftValido(),
        conformityStatus: ConformityStatus.ok,
      );
      //ACT
      final alterado = original.copyWith(
        conformityStatus: ConformityStatus.nok,
        nonConformityReason: 'Furo deslocado',
      );
      //ASSERT
      expect(alterado.conformityStatus, ConformityStatus.nok);
      expect(alterado.pieceName, original.pieceName);
    });
  });

  group("Submit de Relatório - Serialização JSON", () {
    test("TC24 — Registro converte para JSON e volta sem perda", () {
      //ARRANGE
      final original = MeasurementRecord(
        id: 'rj', pieceName: 'Peça JSON',
        createdAt: DateTime(2026, 5, 17, 10, 0),
        primaryValueMm: 75.123, aiReport: '## Teste',
        aiReportStatus: AiReportStatus.completed, draft: _criarDraftValido(),
        conformityStatus: ConformityStatus.nok,
        nonConformityReason: 'Ângulo incorreto', responsavel: 'Maria',
      );
      //ACT
      final json = original.toJson();
      final restaurado = MeasurementRecord.fromJson(json);
      //ASSERT
      expect(restaurado.id, original.id);
      expect(restaurado.pieceName, original.pieceName);
      expect(restaurado.aiReportStatus, AiReportStatus.completed);
      expect(restaurado.nonConformityReason, 'Ângulo incorreto');
      expect(restaurado.responsavel, 'Maria');
    });
  });
}

MeasurementDraft _criarDraftValido() {
  return const MeasurementDraft(
    sourceImagePath: '/fake/image.jpg',
    processedImagePath: '/fake/processed.jpg',
    calibrationSuccess: true, objectFound: true,
    widthMm: 120.5, heightMm: 85.3,
    perimeterMm: 411.6, areaMm2: 10278.65,
    scaleMicronsPerPx: 52.3, markerSizeMm: 11.0,
    segments: [
      PieceSegmentMeasurement(
        type: PieceSegmentType.overallWidth,
        label: 'Largura geral', valueMm: 120.5,
      ),
    ],
    pieceNumberOfDay: 1,
  );
}
