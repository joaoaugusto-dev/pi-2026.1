import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';

import '../helpers/sidera_test_fakes.dart';

void main() {
  group('InspectionViewModel - Testes de Unidade', () {
    test(
      'TC17 - Processamento válido cria draft de câmera e limpa estado',
      () async {
        final service = FakeMeasurementService()
          ..nextDraft = testMeasurementDraft(
            sourceImagePath: '/tmp/captura.png',
          );
        final repository = FakeMeasurementRepository();
        final viewModel = InspectionViewModel(
          measurementService: service,
          repository: repository,
          cameras: testCameras(),
        );

        await viewModel.processCapturedImage('/tmp/captura.png');

        expect(service.processedPaths, ['/tmp/captura.png']);
        expect(viewModel.isProcessing, isFalse);
        expect(viewModel.lastError, isNull);
        expect(viewModel.currentDraft, isNotNull);
        expect(viewModel.currentDraft!.source, MeasurementSource.camera);

        viewModel.dispose();
        await repository.close();
      },
    );

    test(
      'TC18 - Falha no processamento registra erro e descarta draft',
      () async {
        final service = FakeMeasurementService()
          ..nextError = StateError('falha cv');
        final repository = FakeMeasurementRepository();
        final viewModel = InspectionViewModel(
          measurementService: service,
          repository: repository,
          cameras: testCameras(),
        );

        await viewModel.processCapturedImage('/tmp/erro.png');

        expect(viewModel.isProcessing, isFalse);
        expect(viewModel.currentDraft, isNull);
        expect(viewModel.lastError, contains('falha cv'));

        viewModel.dispose();
        await repository.close();
      },
    );

    test('TC19 - Salvamento sem medição válida é bloqueado', () async {
      final repository = FakeMeasurementRepository();
      final viewModel = InspectionViewModel(
        measurementService: FakeMeasurementService(),
        repository: repository,
        cameras: testCameras(),
      );

      final saved = await viewModel.saveCurrentDraft(
        pieceName: 'Peça inválida',
      );

      expect(saved, isNull);
      expect(viewModel.lastError, 'Nao existe medicao valida para salvar.');
      expect(viewModel.isSaving, isFalse);

      viewModel.dispose();
      await repository.close();
    });

    test(
      'TC20 - Salvamento válido preserva conformidade e histórico',
      () async {
        final repository = FakeMeasurementRepository();
        final viewModel = InspectionViewModel(
          measurementService: FakeMeasurementService(),
          repository: repository,
          cameras: testCameras(),
        )..currentDraft = testMeasurementDraft(pieceNumberOfDay: 2);

        final saved = await viewModel.saveCurrentDraft(
          pieceName: 'Peça NOK',
          conformityStatus: ConformityStatus.nok,
          nonConformityReason: 'Furo deslocado',
          nonConformityObservation: 'Necessita revisão',
          responsavel: 'João',
        );

        expect(saved, isNotNull);
        expect(saved!.pieceName, 'Peça NOK');
        expect(saved.conformityStatus, ConformityStatus.nok);
        expect(saved.nonConformityReason, 'Furo deslocado');
        expect(saved.responsavel, 'João');
        expect(viewModel.history.single.id, saved.id);
        expect(viewModel.isSaving, isFalse);

        viewModel.dispose();
        await repository.close();
      },
    );

    test(
      'TC21 - Histórico carrega, mescla stream e sugere nome automático',
      () async {
        final oldRecord = testMeasurementRecord(
          id: 'old',
          createdAt: DateTime(2026, 5, 13),
        );
        final newRecord = testMeasurementRecord(
          id: 'new',
          createdAt: DateTime(2026, 5, 14),
        );
        final repository = FakeMeasurementRepository()
          ..storedHistory = [oldRecord]
          ..nextPieceNumber = 7;
        final viewModel = InspectionViewModel(
          measurementService: FakeMeasurementService(),
          repository: repository,
          cameras: testCameras(),
        );

        await viewModel.loadHistory();
        repository.emitRecordUpdate(newRecord);
        await Future<void>.delayed(Duration.zero);
        viewModel.currentDraft = testMeasurementDraft();
        await viewModel.ensureCurrentDraftPieceNumberOfDay();

        expect(viewModel.history.map((record) => record.id), ['new', 'old']);
        expect(viewModel.currentDraft!.pieceNumberOfDay, 7);
        expect(
          viewModel.suggestedPieceNameForCurrentDraft(DateTime(2026, 5, 14)),
          'Peça 7 - 14/05/2026',
        );

        viewModel.dispose();
        await repository.close();
      },
    );

    test('TC22 - Exclusão falha restaura histórico anterior', () async {
      final record = testMeasurementRecord(id: 'delete-me');
      final repository = FakeMeasurementRepository()
        ..storedHistory = [record]
        ..deleteError = StateError('sem conexão');
      final viewModel = InspectionViewModel(
        measurementService: FakeMeasurementService(),
        repository: repository,
        cameras: testCameras(),
      );

      await viewModel.loadHistory();
      final deleted = await viewModel.deleteRecordById('delete-me');

      expect(deleted, isFalse);
      expect(viewModel.history.single.id, 'delete-me');
      expect(viewModel.lastError, contains('sem conexão'));

      viewModel.dispose();
      await repository.close();
    });
  });
}
