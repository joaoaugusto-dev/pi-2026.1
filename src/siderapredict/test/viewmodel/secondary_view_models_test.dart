import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siderapredict/app/core/services/settings_service.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/processing_view_model.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/validation_view_model.dart';
import 'package:siderapredict/app/features/reports/viewmodel/history_view_model.dart';
import 'package:siderapredict/app/features/settings/viewmodel/settings_view_model.dart';

import '../helpers/sidera_test_fakes.dart';

void main() {
  group('ProcessingViewModel - Testes de Unidade', () {
    test('TC23 - Mensagens de falha explicam cada estado inválido', () {
      final repository = FakeMeasurementRepository();
      final inspectionViewModel = InspectionViewModel(
        measurementService: FakeMeasurementService(),
        repository: repository,
        cameras: testCameras(),
      )..lastError = 'Erro externo';
      final viewModel = ProcessingViewModel(
        inspectionViewModel: inspectionViewModel,
        imagePath: '/tmp/input.png',
      );

      expect(viewModel.failureMessageFor(null), 'Erro externo');
      expect(
        viewModel.failureMessageFor(
          testMeasurementDraft(
            calibrationSuccess: false,
            extraInfo: 'sem board',
          ),
        ),
        contains('Falha na calibração'),
      );
      expect(
        viewModel.failureMessageFor(testMeasurementDraft(objectFound: false)),
        contains('Peça não encontrada'),
      );

      inspectionViewModel.lastError = null;
      expect(
        viewModel.failureMessageFor(
          testMeasurementDraft(
            widthMm: 0,
            heightMm: 0,
            perimeterMm: 0,
            areaMm2: 0,
            segments: const [],
          ),
        ),
        contains('foto pode estar borrada'),
      );

      viewModel.dispose();
      inspectionViewModel.dispose();
      repository.close();
    });
  });

  group('ValidationViewModel - Testes de Unidade', () {
    test(
      'TC24 - Conformidade NOK e salvamento enviam dados ao Inspection',
      () async {
        final draft = testMeasurementDraft(pieceNumberOfDay: 3);
        final repository = FakeMeasurementRepository();
        final inspectionViewModel = InspectionViewModel(
          measurementService: FakeMeasurementService(),
          repository: repository,
          cameras: testCameras(),
        )..currentDraft = draft;
        final viewModel = ValidationViewModel(
          inspectionViewModel: inspectionViewModel,
          draft: draft,
        );

        expect(viewModel.primaryDisplay, '42.500 mm');
        viewModel.updatePieceName('Peça validada');
        viewModel.updateConformityStatus(ConformityStatus.nok);
        viewModel.updateNonConformityReason('Rebarba');
        viewModel.updateNonConformityObservation('Borda superior');

        final saved = await viewModel.save(responsavel: 'Maria');

        expect(saved, isNotNull);
        expect(saved!.pieceName, 'Peça validada');
        expect(saved.conformityStatus, ConformityStatus.nok);
        expect(saved.nonConformityReason, 'Rebarba');
        expect(saved.nonConformityObservation, 'Borda superior');
        expect(saved.responsavel, 'Maria');

        viewModel.updateConformityStatus(ConformityStatus.ok);
        expect(viewModel.nonConformityReason, isNull);
        expect(viewModel.nonConformityObservation, isNull);

        viewModel.dispose();
        inspectionViewModel.dispose();
        await repository.close();
      },
    );

    test('TC25 - Mensagem de validação prioriza erro técnico do draft', () {
      final draft = testMeasurementDraft(
        calibrationSuccess: false,
        extraInfo: 'Homografia indisponível',
      );
      final repository = FakeMeasurementRepository();
      final inspectionViewModel = InspectionViewModel(
        measurementService: FakeMeasurementService(),
        repository: repository,
        cameras: testCameras(),
      );
      final viewModel = ValidationViewModel(
        inspectionViewModel: inspectionViewModel,
        draft: draft,
      );

      expect(viewModel.primaryDisplay, '--');
      expect(viewModel.primaryLabel, 'Aguardando medida válida');
      expect(viewModel.validationErrorMessage, 'Homografia indisponível');

      viewModel.dispose();
      inspectionViewModel.dispose();
      repository.close();
    });
  });

  group('HistoryViewModel - Testes de Unidade', () {
    test(
      'TC26 - Histórico formata data, peça do dia e imagem base64',
      () async {
        final thumbnail = base64Encode([1, 2, 3]);
        final record = testMeasurementRecord(
          id: 'history-1',
          createdAt: DateTime(2026, 5, 14, 13, 45),
          thumbnailBase64: thumbnail,
        );
        final repository = FakeMeasurementRepository()
          ..storedHistory = [record];
        final inspectionViewModel = InspectionViewModel(
          measurementService: FakeMeasurementService(),
          repository: repository,
          cameras: testCameras(),
        );
        final viewModel = HistoryViewModel(
          inspectionViewModel: inspectionViewModel,
        );

        await viewModel.loadHistory();

        expect(viewModel.history.single.id, 'history-1');
        expect(viewModel.dateLabel(record), '14/05/2026 13:45');
        expect(viewModel.pieceOfDayLabel(record), 'Peça 1 do dia 14/05/2026');
        expect(viewModel.imageBytesFor(record), [1, 2, 3]);
        expect(viewModel.recordImageProvider(record), isNotNull);
        expect(
          viewModel.imageBytesFor(record.copyWith(thumbnailBase64: 'inválido')),
          isNull,
        );

        viewModel.dispose();
        inspectionViewModel.dispose();
        await repository.close();
      },
    );
  });

  group('SettingsViewModel - Testes de Unidade', () {
    test(
      'TC27 - Tema escuro e alto contraste são mutuamente exclusivos',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final viewModel = SettingsViewModel(
          settingsService: SettingsService(prefs),
        );

        await viewModel.toggleHighContrast(true);
        expect(viewModel.isHighContrast, isTrue);
        expect(viewModel.isDarkMode, isFalse);

        await viewModel.toggleDarkMode(true);
        expect(viewModel.isDarkMode, isTrue);
        expect(viewModel.isHighContrast, isFalse);

        await viewModel.toggleHighContrast(true);
        expect(viewModel.isHighContrast, isTrue);
        expect(viewModel.isDarkMode, isFalse);
        expect(viewModel.currentTheme, isNotNull);

        viewModel.dispose();
      },
    );
  });
}
