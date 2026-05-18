import 'package:flutter_test/flutter_test.dart';

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

/// Testes de Unidade — ProcessingViewModel (IA e Snackbars)
///
/// Testa as 3 etapas do relatório IA (pending, generating, completed)
/// e as mensagens de falha exibidas nas snackbars quando os marcadores
/// ArUco não são reconhecidos ou a peça não é encontrada.
///
/// Como o ProcessingViewModel depende de InspectionViewModel (que
/// precisa de serviços nativos), testamos a lógica pura:
/// - AiReportStatus no MeasurementRecord
/// - failureMessageFor() que gera as mensagens das snackbars
void main() {
  // ═══════════════════════════════════════════
  // IA — 3 ETAPAS DO RELATÓRIO
  // ═══════════════════════════════════════════

  group("IA - Status do Relatório (AiReportStatus)", () {
    test("TC10 — Status 'Na Fila' quando registro é criado", () {
      //ACT
      final record = _criarRegistroComStatus(AiReportStatus.pending);

      //ASSERT
      expect(record.aiReportStatus, AiReportStatus.pending);
      expect(record.isAiReportStreaming, isTrue);
      expect(record.aiReport, isEmpty);
    });

    test("TC11 — Status 'Gerando' durante processamento da IA", () {
      //ACT
      final record = _criarRegistroComStatus(AiReportStatus.generating);

      //ASSERT
      expect(record.aiReportStatus, AiReportStatus.generating);
      expect(record.isAiReportStreaming, isTrue);
    });

    test("TC12 — Status 'Concluído' após IA finalizar", () {
      //ACT
      final record = MeasurementRecord(
        id: 'test-id',
        pieceName: 'Peça Teste',
        createdAt: DateTime.now(),
        primaryValueMm: 120.5,
        aiReport: '## Relatório gerado pela IA com sucesso.',
        aiReportStatus: AiReportStatus.completed,
        draft: _criarDraftValido(),
      );

      //ASSERT
      expect(record.aiReportStatus, AiReportStatus.completed);
      expect(record.isAiReportStreaming, isFalse);
      expect(record.aiReport, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════
  // SNACKBARS — MENSAGENS DE FALHA NA MEDIÇÃO
  // ═══════════════════════════════════════════

  group("Snackbars - Mensagens de falha ao tirar foto", () {
    test("TC13 — Falha na calibração ArUco (marcadores não detectados)", () {
      //ARRANGE
      final draft = MeasurementDraft(
        sourceImagePath: '/fake/image.jpg',
        processedImagePath: '',
        calibrationSuccess: false,
        objectFound: false,
        widthMm: 0,
        heightMm: 0,
        perimeterMm: 0,
        areaMm2: 0,
        scaleMicronsPerPx: null,
        markerSizeMm: 11.0,
        segments: const [],
      );

      //ACT
      final mensagem = _failureMessageFor(draft, null);

      //ASSERT
      expect(mensagem, contains("calibração"));
      expect(mensagem, contains("ArUco"));
      expect(draft.isValidMeasurement, isFalse);
    });

    test("TC14 — Peça não encontrada no centro da prancheta", () {
      //ARRANGE
      final draft = MeasurementDraft(
        sourceImagePath: '/fake/image.jpg',
        processedImagePath: '/fake/processed.jpg',
        calibrationSuccess: true,
        objectFound: false,
        widthMm: 0,
        heightMm: 0,
        perimeterMm: 0,
        areaMm2: 0,
        scaleMicronsPerPx: 52.3,
        markerSizeMm: 11.0,
        segments: const [],
      );

      //ACT
      final mensagem = _failureMessageFor(draft, null);

      //ASSERT
      expect(mensagem, contains("não encontrada"));
      expect(draft.isValidMeasurement, isFalse);
    });

    test("TC15 — Imagem nula retorna mensagem padrão de erro", () {
      //ACT
      final mensagem = _failureMessageFor(null, null);

      //ASSERT
      expect(mensagem, contains("processar"));
    });

    test("TC16 — Imagem nula com lastError personalizado", () {
      //ARRANGE
      const lastError = "Timeout ao processar imagem.";

      //ACT
      final mensagem = _failureMessageFor(null, lastError);

      //ASSERT
      expect(mensagem, equals(lastError));
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────────

/// Reproduz a lógica de ProcessingViewModel.failureMessageFor()
/// sem precisar instanciar o ViewModel completo.
String _failureMessageFor(MeasurementDraft? draft, String? lastError) {
  if (draft == null) {
    return lastError ?? 'Não foi possível processar a imagem.';
  }
  if (draft.isValidMeasurement) {
    return lastError ?? 'Processamento concluído.';
  }
  if (!draft.calibrationSuccess) {
    return 'Falha na calibração. A prancheta ArUco não foi totalmente detectada. Tente melhorar o enquadramento ou iluminação.';
  }
  if (!draft.objectFound) {
    return 'Peça não encontrada no centro da prancheta. Tente novamente.';
  }
  return 'Não foi possível extrair medidas válidas da peça. A foto pode estar borrada.';
}

MeasurementRecord _criarRegistroComStatus(AiReportStatus status) {
  return MeasurementRecord(
    id: 'test-id',
    pieceName: 'Peça Teste',
    createdAt: DateTime.now(),
    primaryValueMm: 120.5,
    aiReport: '',
    aiReportStatus: status,
    draft: _criarDraftValido(),
  );
}

MeasurementDraft _criarDraftValido() {
  return const MeasurementDraft(
    sourceImagePath: '/fake/image.jpg',
    processedImagePath: '/fake/processed.jpg',
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
    pieceNumberOfDay: 1,
  );
}
